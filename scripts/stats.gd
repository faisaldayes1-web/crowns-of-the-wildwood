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

const DOOR_HALF := 3.5        # half-width of each castle door
const GATE_HITS := 50         # door damage a castle door soaks before it breaks
const GATE_REBUILD_TIME := 30.0
const MATCH_TIME := 600.0     # seconds
const CAPTURES_TO_WIN := 2

# attack: "melee" swings, "arrow" and "spell" fire a shot, "heal" restores
#   hearts to nearby teammates (and falls back to a staff bonk).
# damage: hearts removed per hit.  gate_damage: door hits removed per hit.
# energy: which bar the attack spends ("stamina" or "mana"), cost: how much.
const ROLES := {
	Role.BASE: {"attack": "melee", "damage": 1, "gate_damage": 1, "range": 1.6, "cooldown": 0.8,
		"energy": "stamina", "cost": 25.0, "speed": 1.0,
		"color": Color(0.85, 0.8, 0.7), "build": Vector3(0.9, 0.9, 0.9)},
	Role.KNIGHT: {"attack": "melee", "damage": 1, "gate_damage": 2, "range": 2.2, "cooldown": 0.5,
		"energy": "stamina", "cost": 20.0, "speed": 1.0,
		"color": Color(0.8, 0.8, 0.85), "build": Vector3(1.3, 1.12, 1.3)},
	Role.RANGER: {"attack": "arrow", "damage": 1, "gate_damage": 1, "range": 14.0, "cooldown": 0.9,
		"energy": "stamina", "cost": 25.0, "speed": 1.05,
		"color": Color(0.35, 0.55, 0.25), "build": Vector3(0.9, 1.05, 0.9)},
	Role.MAGE: {"attack": "spell", "damage": 1, "gate_damage": 2, "range": 12.0, "cooldown": 1.0,
		"energy": "mana", "cost": 30.0, "splash": 2.0, "speed": 0.95,
		"color": Color(0.45, 0.3, 0.85), "build": Vector3(0.95, 1.1, 0.95)},
	Role.HEALER: {"attack": "heal", "damage": 1, "gate_damage": 1, "range": 1.8, "cooldown": 1.0,
		"energy": "mana", "cost": 30.0, "heal": 1, "heal_radius": 5.0, "speed": 1.0,
		"color": Color(0.95, 0.93, 0.8), "build": Vector3(0.95, 1.0, 0.95)},
}

# Elves are quicker on their feet; humans recover stamina and mana faster.
const FACTIONS := [
	{"name": "Elves", "color": Color(0.25, 0.7, 0.35), "speed": 6.6, "regen_mult": 1.0,
		"roles": ["Elf", "Knight", "Ranger", "Mage", "Healer"]},
	{"name": "Humans", "color": Color(0.25, 0.45, 0.9), "speed": 6.0, "regen_mult": 1.5,
		"roles": ["Human", "Knight", "Ranger", "Mage", "Healer"]},
]
