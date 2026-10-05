extends RefCounted
## Every number that shapes a fight lives here, so balancing never means
## digging through game code. Health is counted in hearts: damage 1 = one heart.

enum Role { BASE, KNIGHT, RANGER, MAGE, HEALER }

const MAX_HEARTS := 4
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 30.0   # per second
const MANA_MAX := 100.0
const MANA_REGEN := 12.0      # per second
const RESPAWN_TIME := 7.0
const CARRY_SPEED_MULT := 0.75

const DODGE_TIME := 0.25      # seconds the dash lasts; nothing can hit you during it
const DODGE_SPEED_MULT := 3.2 # dash speed as a multiple of run speed
const DODGE_COOLDOWN := 3.0   # seconds until the next dodge is ready

const HEAL_ORB_HEARTS := 2    # hearts a healing orb on the ground restores
const HEAL_ORB_RESPAWN := 25.0 # seconds before a taken orb comes back

const DOOR_HALF := 3.5        # half-width of each castle door
const GATE_HITS := 50         # door damage a castle door soaks before it breaks
const GATE_REBUILD_TIME := 30.0
const MATCH_TIME := 600.0     # seconds
const CAPTURES_TO_WIN := 2

# attack: "melee" swings, "arrow" and "spell" fire a shot, "heal" restores
#   hearts to nearby teammates (and falls back to a staff bonk).
# damage: hearts removed per hit.  gate_damage: door hits removed per hit.
# energy: which bar the attack spends ("stamina" or "mana"), cost: how much.
# abilities: the class moveset on Q and E. kind picks the effect (unit.gd,
#   use_ability), cooldown is in seconds, cost comes out of the class's energy.
const ROLES := {
	Role.BASE: {"attack": "melee", "damage": 1, "gate_damage": 1, "range": 1.6, "cooldown": 0.8,
		"energy": "stamina", "cost": 25.0, "speed": 1.0,
		"color": Color(0.85, 0.8, 0.7), "build": Vector3(0.9, 0.9, 0.9), "abilities": []},
	Role.KNIGHT: {"attack": "melee", "damage": 1, "gate_damage": 2, "range": 2.2, "cooldown": 0.5,
		"energy": "stamina", "cost": 20.0, "speed": 1.0,
		"color": Color(0.8, 0.8, 0.85), "build": Vector3(1.3, 1.12, 1.3), "abilities": [
			{"name": "Shield Bash", "key": "Q", "kind": "bash", "cooldown": 6.0, "cost": 20.0,
				"damage": 1, "distance": 4.0},
			{"name": "Shield Wall", "key": "E", "kind": "guard", "cooldown": 10.0, "cost": 0.0,
				"duration": 2.0}]},
	Role.RANGER: {"attack": "arrow", "damage": 1, "gate_damage": 1, "range": 14.0, "cooldown": 0.9,
		"energy": "stamina", "cost": 25.0, "speed": 1.05,
		"color": Color(0.35, 0.55, 0.25), "build": Vector3(0.9, 1.05, 0.9), "abilities": [
			{"name": "Volley", "key": "Q", "kind": "volley", "cooldown": 6.0, "cost": 30.0,
				"damage": 1, "arrows": 5, "spread": 24.0, "range": 14.0},
			{"name": "Snare Trap", "key": "E", "kind": "trap", "cooldown": 10.0, "cost": 20.0,
				"damage": 1, "root": 2.0, "lifetime": 30.0}]},
	Role.MAGE: {"attack": "spell", "damage": 1, "gate_damage": 2, "range": 12.0, "cooldown": 1.0,
		"energy": "mana", "cost": 30.0, "splash": 2.0, "speed": 0.95,
		"color": Color(0.45, 0.3, 0.85), "build": Vector3(0.95, 1.1, 0.95), "abilities": [
			{"name": "Fireball", "key": "Q", "kind": "fireball", "cooldown": 8.0, "cost": 40.0,
				"damage": 2, "splash": 3.5, "range": 12.0, "speed": 14.0},
			{"name": "Blink", "key": "E", "kind": "blink", "cooldown": 7.0, "cost": 20.0,
				"distance": 6.0}]},
	Role.HEALER: {"attack": "heal", "damage": 1, "gate_damage": 1, "range": 1.8, "cooldown": 1.0,
		"energy": "mana", "cost": 30.0, "heal": 1, "heal_radius": 5.0, "speed": 1.0,
		"color": Color(0.95, 0.93, 0.8), "build": Vector3(0.95, 1.0, 0.95), "abilities": [
			{"name": "Blessing", "key": "Q", "kind": "blessing", "cooldown": 12.0, "cost": 50.0,
				"heal": 2, "radius": 8.0, "haste": 4.0},
			{"name": "Smite", "key": "E", "kind": "smite", "cooldown": 4.0, "cost": 15.0,
				"damage": 1, "range": 12.0, "speed": 26.0}]},
}

# Elves are quicker on their feet; humans recover stamina and mana faster.
const FACTIONS := [
	{"name": "Elves", "color": Color(0.25, 0.7, 0.35), "speed": 6.6, "regen_mult": 1.0,
		"roles": ["Elf", "Knight", "Ranger", "Mage", "Healer"]},
	{"name": "Humans", "color": Color(0.25, 0.45, 0.9), "speed": 6.0, "regen_mult": 1.5,
		"roles": ["Human", "Knight", "Ranger", "Mage", "Healer"]},
]
