extends RefCounted
## Every number that shapes a fight lives here, so balancing never means
## digging through game code. Health is counted in hearts: damage 1 = one heart.

enum Role { BASE, KNIGHT, RANGER, MAGE, HEALER }

const MAX_HEARTS := 4
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 11.0   # per second (slow: stamina is the limit on attacks)
const MANA_MAX := 100.0
const MANA_REGEN := 7.0       # per second
const RESPAWN_TIME := 7.0
const CARRY_SPEED_MULT := 0.75

const DODGE_TIME := 0.25      # seconds the dash lasts; nothing can hit you during it
const DODGE_SPEED_MULT := 3.2 # dash speed as a multiple of run speed
const DODGE_COOLDOWN := 2.0   # seconds until the next dodge is ready
const DODGE_COST := 10.0      # stamina (or mana) a dodge spends

const BLOCK_COST := 18.0      # stamina a blocked hit costs the blocker
const BLOCK_DRAIN := 4.0      # stamina per second while the shield is up
const BLOCK_SPEED_MULT := 0.45

const HEAL_ORB_HEARTS := 2    # hearts a healing orb on the ground restores
const HEAL_ORB_RESPAWN := 25.0 # seconds before a taken orb comes back

const DOOR_HALF := 3.5        # half-width of each castle door
const GATE_HITS := 50         # door damage a castle door soaks before it breaks
const GATE_REBUILD_TIME := 30.0
const MATCH_TIME := 600.0     # seconds
const CAPTURES_TO_WIN := 2

# Experience, earned per life and lost on death. Each level gives one rank
# point to spend in the rank menu (Tab) on Attack, Q, E or Vigor.
const XP_LEVELS := [40, 100, 180, 280, 400]   # xp needed for level 2, 3, 4, 5, 6
const XP_HIT := 10            # per heart of damage dealt
const XP_KILL := 30
const XP_HEAL := 8            # per heart healed on a teammate
const XP_GATE := 1            # per door hit
const XP_GRAB := 25           # picking up the enemy monarch
const XP_CAPTURE := 100
const MAX_RANK := 3
# Per rank: abilities cool down and cost less; Vigor makes you quicker and
# gives you a bigger stamina or mana pool. Rank 2 widens the effect
# (radius, distance, duration, arrows) and rank 3 adds a heart of damage/heal.
const RANK_COOLDOWN_CUT := 0.15
const RANK_COST_CUT := 0.12
const RANK_EFFECT_BOOST := 0.3
const VIGOR_SPEED := 0.07
const VIGOR_ENERGY := 15.0
const VIGOR_REGEN := 0.2
const RANK_TRACKS := ["Attack", "Q", "E", "Vigor"]

# Hit feedback: how hard hits shove people (metres per second).
const KNOCK_MELEE := 6.0
const KNOCK_SHOT := 4.0
const KNOCK_SPLASH := 8.0

# attack: the base ability on left click. "melee" swings, "arrow" and "spell"
#   fire a shot, "heal" mends nearby hurt teammates (or fires a holy bolt when
#   nobody needs healing). attack_name/attack_desc show in the menus.
# damage: hearts removed per hit.  gate_damage: door hits removed per hit.
# energy: which bar the class spends ("stamina" or "mana"), cost: per attack.
# shot_speed: metres per second for arrows and bolts.
# block: the class carries a shield and can hold right click to block.
# abilities: the moveset on Q and E. kind picks the effect (unit.gd,
#   use_ability), cooldown is in seconds, cost comes out of the class's energy.
const ROLES := {
	Role.BASE: {"attack": "melee", "attack_name": "Punch", "attack_desc": "A quick jab. Find a class station!",
		"damage": 1, "gate_damage": 1, "range": 1.6, "cooldown": 0.7,
		"energy": "stamina", "cost": 14.0, "speed": 1.0,
		"color": Color(0.85, 0.8, 0.7), "abilities": []},
	Role.KNIGHT: {"attack": "melee", "attack_name": "Sword Strike", "attack_desc": "A wide swing that also chips at doors.",
		"damage": 1, "gate_damage": 2, "range": 2.2, "cooldown": 0.5,
		"energy": "stamina", "cost": 12.0, "speed": 1.0, "block": true,
		"color": Color(0.8, 0.8, 0.85), "abilities": [
			{"name": "Shield Bash", "key": "Q", "kind": "bash", "cooldown": 4.0, "cost": 35.0,
				"damage": 1, "distance": 4.0, "desc": "Charge forward, hitting and shoving everyone in the way."},
			{"name": "Shield Wall", "key": "E", "kind": "guard", "cooldown": 8.0, "cost": 30.0,
				"duration": 2.0, "desc": "Nothing gets through your shield for a moment, from any side."}]},
	Role.RANGER: {"attack": "arrow", "attack_name": "Quick Shot", "attack_desc": "A fast arrow. Shoot down from the walls.",
		"damage": 1, "gate_damage": 1, "range": 15.0, "cooldown": 0.55,
		"energy": "stamina", "cost": 13.0, "speed": 1.05, "shot_speed": 40.0,
		"color": Color(0.35, 0.55, 0.25), "abilities": [
			{"name": "Volley", "key": "Q", "kind": "volley", "cooldown": 4.0, "cost": 45.0,
				"damage": 1, "arrows": 5, "spread": 24.0, "range": 15.0, "shot_speed": 40.0, "desc": "A fan of five arrows."},
			{"name": "Snare Trap", "key": "E", "kind": "trap", "cooldown": 7.0, "cost": 35.0,
				"damage": 1, "root": 2.0, "lifetime": 30.0, "desc": "Plant a trap that roots and hurts the first enemy on it."}]},
	Role.MAGE: {"attack": "spell", "attack_name": "Arcane Bolt", "attack_desc": "A bolt that bursts on impact.",
		"damage": 1, "gate_damage": 2, "range": 13.0, "cooldown": 0.6,
		"energy": "mana", "cost": 15.0, "splash": 1.6, "speed": 0.95, "shot_speed": 32.0,
		"color": Color(0.45, 0.3, 0.85), "abilities": [
			{"name": "Fireball", "key": "Q", "kind": "fireball", "cooldown": 5.0, "cost": 50.0,
				"damage": 2, "splash": 3.5, "range": 13.0, "shot_speed": 24.0, "desc": "A big slow ball of fire: two hearts to everyone near the blast, four hits to a door."},
			{"name": "Blink", "key": "E", "kind": "blink", "cooldown": 5.0, "cost": 30.0,
				"distance": 6.0, "desc": "Teleport a short way in the aim direction."}]},
	Role.HEALER: {"attack": "heal", "attack_name": "Mend", "attack_desc": "Heal hurt teammates around you; with nobody to heal, fire a holy bolt instead.",
		"damage": 1, "gate_damage": 1, "range": 10.0, "cooldown": 0.8,
		"energy": "mana", "cost": 22.0, "heal": 1, "heal_radius": 5.0, "speed": 1.0, "shot_speed": 30.0,
		"color": Color(0.95, 0.93, 0.8), "abilities": [
			{"name": "Blessing", "key": "Q", "kind": "blessing", "cooldown": 9.0, "cost": 60.0,
				"heal": 2, "radius": 8.0, "haste": 4.0, "desc": "Heal every teammate nearby two hearts and speed them up."},
			{"name": "Smite", "key": "E", "kind": "smite", "cooldown": 3.0, "cost": 30.0,
				"damage": 1, "range": 12.0, "shot_speed": 36.0, "desc": "A fast bolt of light."}]},
}

# Elves are quicker on their feet; humans recover stamina and mana faster.
const FACTIONS := [
	{"name": "Elves", "realm": "Forest", "color": Color(0.25, 0.7, 0.35), "speed": 6.6, "regen_mult": 1.0,
		"roles": ["Elf", "Knight", "Ranger", "Mage", "Healer"]},
	{"name": "Humans", "realm": "Kingdom", "color": Color(0.25, 0.45, 0.9), "speed": 6.0, "regen_mult": 1.3,
		"roles": ["Human", "Knight", "Ranger", "Mage", "Healer"]},
]


static func level_for_xp(xp: int) -> int:
	var level := 1
	for need in XP_LEVELS:
		if xp >= need:
			level += 1
	return level


static func xp_span(level: int) -> Array:
	## [xp where this level starts, xp where the next begins] (or [start, -1] at max).
	var start: int = 0 if level <= 1 else XP_LEVELS[mini(level - 2, XP_LEVELS.size() - 1)]
	var next: int = XP_LEVELS[level - 1] if level - 1 < XP_LEVELS.size() else -1
	return [start, next]
