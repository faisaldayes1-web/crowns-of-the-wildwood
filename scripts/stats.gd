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
const DODGE_COST := 12.0      # stamina (or mana) a dodge spends

const BLOCK_COST := 18.0      # stamina a blocked hit costs the blocker
const BLOCK_DRAIN := 4.0      # stamina per second while the shield is up
const BLOCK_SPEED_MULT := 0.45

const HEAL_ORB_HEARTS := 2    # hearts a health potion on the ground restores
const HEAL_ORB_RESPAWN := 25.0 # seconds before a taken potion comes back

# Blessings of Light: a buff that appears somewhere in the field now and then.
const BLESSING_INTERVAL := [35.0, 60.0]   # seconds between blessings (random in range)
const BLESSING_LIFE := 25.0               # seconds a blessing waits before fading
const BLESSING_DURATION := 10.0           # seconds the buff lasts
const BLESSING_REGEN_TICK := 2.5          # Regeneration: a heart every this many seconds
const BLESSING_SWIFT_MULT := 1.3          # Swiftness: speed multiplier
const BLESSING_KINDS := {
	"Regeneration": {"icon": "regen", "desc": "a heart back every few seconds", "color": Color(0.5, 1.0, 0.6)},
	"Swiftness": {"icon": "dodge", "desc": "30% faster", "color": Color(0.6, 0.9, 1.0)},
	"Might": {"icon": "might", "desc": "every attack takes an extra heart", "color": Color(1.0, 0.7, 0.4)},
}

const DOOR_HALF := 3.5        # half-width of each castle door
const GATE_HITS := 50         # door damage a castle door soaks before it breaks
const GATE_REBUILD_TIME := 30.0
const MATCH_TIME := 600.0     # seconds
const CAPTURES_TO_WIN := 2

# Experience, earned per life and lost on death. Each level gives one rank
# point to spend in the rank menu (Tab) on Attack, Q, E or Vigor.
const XP_LEVELS := [40, 100, 180, 280, 400]   # xp needed for level 2, 3, 4, 5, 6
const XP_HIT := 10            # per heart of damage dealt
const XP_KILL := 40
const XP_HEAL := 8            # per heart healed on a teammate
const XP_GATE := 1            # per door hit
const XP_GRAB := 25           # picking up the enemy monarch
const XP_CAPTURE := 100
const MAX_RANK := 3
# Per rank: abilities cool down and cost less; Vigor makes you quicker and
# gives you a bigger stamina or mana pool. Rank 2 widens the effect
# (radius, distance, duration, arrows) and rank 3 adds a heart of damage/heal.
const RANK_COOLDOWN_CUT := 0.12
const RANK_COST_CUT := 0.12
const RANK_EFFECT_BOOST := 0.3
const VIGOR_SPEED := 0.07
const VIGOR_ENERGY := 15.0
const VIGOR_REGEN := 0.2
const RANK_TRACKS := ["Attack", "Q", "E", "Vigor"]

# Scoreboard: what a player's match score is made of.
const SCORE_KILL := 10
const SCORE_CAPTURE := 100
const SCORE_HEAL := 5      # per heart healed on a teammate
const SCORE_DAMAGE := 2    # per heart of damage dealt
const SCORE_UPGRADE := 3   # per rank point spent

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
		"damage": 1, "gate_damage": 2, "range": 2.2, "cooldown": 0.55,
		"energy": "stamina", "cost": 12.0, "speed": 1.0, "block": true,
		"color": Color(0.8, 0.8, 0.85), "abilities": [
			{"name": "Shield Bash", "key": "Q", "kind": "bash", "cooldown": 5.0, "cost": 30.0,
				"damage": 1, "distance": 4.0, "desc": "Charge forward, hitting and shoving everyone in the way."},
			{"name": "Shield Wall", "key": "E", "kind": "guard", "cooldown": 10.0, "cost": 35.0,
				"duration": 1.8, "desc": "Nothing gets through your shield for a moment, from any side."}]},
	Role.RANGER: {"attack": "arrow", "attack_name": "Quick Shot", "attack_desc": "A fast arrow. Shoot down from the walls.",
		"damage": 1, "gate_damage": 1, "range": 15.0, "cooldown": 0.55,
		"energy": "stamina", "cost": 12.0, "speed": 1.05, "shot_speed": 40.0,
		"color": Color(0.35, 0.55, 0.25), "abilities": [
			{"name": "Volley", "key": "Q", "kind": "volley", "cooldown": 6.0, "cost": 40.0,
				"damage": 1, "arrows": 5, "spread": 24.0, "range": 15.0, "shot_speed": 40.0, "desc": "A fan of five arrows."},
			{"name": "Snare Trap", "key": "E", "kind": "trap", "cooldown": 8.0, "cost": 30.0,
				"damage": 1, "root": 2.0, "lifetime": 30.0, "desc": "Plant a trap that roots and hurts the first enemy on it."}]},
	Role.MAGE: {"attack": "spell", "attack_name": "Arcane Bolt", "attack_desc": "A bolt that bursts on impact.",
		"damage": 1, "gate_damage": 2, "range": 13.0, "cooldown": 0.65,
		"energy": "mana", "cost": 15.0, "splash": 1.4, "speed": 0.95, "shot_speed": 32.0,
		"color": Color(0.45, 0.3, 0.85), "abilities": [
			{"name": "Fireball", "key": "Q", "kind": "fireball", "cooldown": 7.0, "cost": 55.0,
				"damage": 2, "splash": 3.2, "range": 13.0, "shot_speed": 24.0, "desc": "A big slow ball of fire: two hearts to everyone near the blast, four hits to a door."},
			{"name": "Blink", "key": "E", "kind": "blink", "cooldown": 6.0, "cost": 25.0,
				"distance": 6.0, "desc": "Teleport a short way in the aim direction."}]},
	Role.HEALER: {"attack": "heal", "attack_name": "Mend", "attack_desc": "Heal hurt teammates around you; with nobody to heal, fire a holy bolt instead.",
		"damage": 1, "gate_damage": 1, "range": 10.0, "cooldown": 0.8,
		"energy": "mana", "cost": 20.0, "heal": 1, "heal_radius": 5.0, "speed": 1.0, "shot_speed": 30.0,
		"color": Color(0.95, 0.93, 0.8), "abilities": [
			{"name": "Blessing", "key": "Q", "kind": "blessing", "cooldown": 12.0, "cost": 60.0,
				"heal": 2, "radius": 8.0, "haste": 3.0, "desc": "Heal every teammate nearby two hearts and speed them up."},
			{"name": "Smite", "key": "E", "kind": "smite", "cooldown": 3.5, "cost": 25.0,
				"damage": 1, "range": 12.0, "shot_speed": 36.0, "desc": "A fast bolt of light."}]},
}

# Class variants (promotions, after Fat Princess's upgraded hat machines):
# every class branches into two. A variant unlocks once you have spent
# VARIANT_UNLOCK rank points in that class over the match (your total
# upgrades, kept across lives), and the pick stays for the rest of the
# match; switch any time in the perk menu. "attack" overrides the class's
# base attack fields, "abilities" replace Q and E, and show / attacks /
# idle / tint dress the model. Extra effect keys: slow and root (seconds)
# on hits, pierce (arrows fly through everyone), fire / frost / drain looks,
# cone (a cleave only in front), share / shield (guard allies for seconds),
# count (traps in a row).
const VARIANT_UNLOCK := 3
const VARIANTS := {
	Role.KNIGHT: [
		{"name": "Vanguard", "icon": "vanguard", "tint": Color(0.9, 0.62, 0.55), "show": ["2H_Sword"],
			"attacks": ["2H_Melee_Attack_Slice", "2H_Melee_Attack_Chop"], "idle": "2H_Melee_Idle",
			"desc": "Greatsword offence: long reach, a spinning cleave and a long charge. The shield is gone, so no blocking.",
			"attack": {"attack_name": "Greatsword", "attack_desc": "A heavy two-handed swing with long reach.",
				"range": 2.8, "cooldown": 0.65, "cost": 15.0, "gate_damage": 3, "block": false},
			"abilities": [
				{"name": "Cleave", "key": "Q", "kind": "cleave", "icon": "cleave", "cooldown": 6.0, "cost": 40.0,
					"damage": 1, "radius": 3.2, "desc": "Spin with the greatsword, hitting and shoving everyone around you."},
				{"name": "Charge", "key": "E", "kind": "bash", "icon": "bash", "cooldown": 6.0, "cost": 35.0,
					"damage": 1, "distance": 6.5, "desc": "A long charge that bowls over everyone in the way."}]},
		{"name": "Warden", "icon": "warden", "tint": Color(0.78, 0.84, 1.0), "show": ["1H_Sword", "Rectangle_Shield"],
			"desc": "Tower shield defence: a slam that pins enemies down and a bulwark that shields nearby teammates too.",
			"attack": {"attack_name": "Mace", "attack_desc": "A short, heavy blow that batters doors.",
				"range": 2.0, "cooldown": 0.55, "gate_damage": 3},
			"abilities": [
				{"name": "Shield Slam", "key": "Q", "kind": "bash", "icon": "bash", "cooldown": 5.0, "cost": 35.0,
					"damage": 1, "distance": 3.5, "root": 1.2, "desc": "A short charge that pins everyone it hits in place."},
				{"name": "Bulwark", "key": "E", "kind": "guard", "icon": "guard", "cooldown": 9.0, "cost": 35.0,
					"duration": 2.5, "share": 4.0, "desc": "A longer Shield Wall that also shields teammates close to you."}]}],
	Role.RANGER: [
		{"name": "Sharpshooter", "icon": "sharpshooter", "tint": Color(0.6, 0.8, 0.55), "show": ["2H_Crossbow"],
			"desc": "Longbow marksman: longer, faster arrows, a piercing shot and a two-heart snipe.",
			"attack": {"attack_name": "Longbow", "attack_desc": "A long, fast arrow.", "range": 20.0, "cooldown": 0.65, "shot_speed": 55.0},
			"abilities": [
				{"name": "Piercing Shot", "key": "Q", "kind": "shot", "icon": "pierce", "cooldown": 5.0, "cost": 40.0,
					"damage": 1, "range": 20.0, "shot_speed": 55.0, "pierce": true, "desc": "An arrow that flies through everyone in its line."},
				{"name": "Snipe", "key": "E", "kind": "shot", "icon": "snipe", "cooldown": 10.0, "cost": 50.0,
					"damage": 2, "range": 24.0, "shot_speed": 70.0, "desc": "A slow-to-ready shot that takes two hearts."}]},
		{"name": "Trapper", "icon": "trapper", "tint": Color(0.75, 0.6, 0.4), "show": ["1H_Crossbow", "Knife_Offhand"],
			"desc": "Hunter's tricks: slowing arrows, a line of three traps and a smoke bomb that hides you.",
			"attack": {"attack_name": "Poison Arrow", "attack_desc": "An arrow that slows whoever it hits.", "slow": 1.5},
			"abilities": [
				{"name": "Trap Line", "key": "Q", "kind": "trap", "icon": "trap", "cooldown": 10.0, "cost": 40.0,
					"damage": 1, "root": 2.0, "lifetime": 30.0, "count": 3, "desc": "Plant three snare traps in a row."},
				{"name": "Smoke Bomb", "key": "E", "kind": "smoke", "icon": "smoke", "cooldown": 12.0, "cost": 35.0,
					"duration": 3.0, "haste": 3.0, "desc": "Vanish in smoke: enemies lose you and you run faster for a moment."}]}],
	Role.MAGE: [
		{"name": "Pyromancer", "icon": "pyromancer", "tint": Color(1.0, 0.6, 0.4), "show": ["2H_Staff"],
			"desc": "Fire: burning bolts, a huge fireball and a wave of flame in front of you.",
			"attack": {"attack_name": "Ember Bolt", "attack_desc": "A burning bolt that splashes.", "fire": true, "splash": 1.8},
			"abilities": [
				{"name": "Inferno", "key": "Q", "kind": "fireball", "icon": "fireball", "cooldown": 8.0, "cost": 60.0,
					"damage": 2, "splash": 4.5, "range": 13.0, "shot_speed": 24.0, "desc": "A huge fireball: two hearts to everyone near the blast."},
				{"name": "Flame Wave", "key": "E", "kind": "cleave", "icon": "wave", "cooldown": 6.0, "cost": 40.0,
					"damage": 1, "radius": 4.5, "cone": true, "fire": true, "desc": "A fan of fire that burns everyone in front of you."}]},
		{"name": "Frostweaver", "icon": "frostweaver", "tint": Color(0.65, 0.88, 1.0), "show": ["2H_Staff"],
			"desc": "Ice: slowing bolts, a freezing burst and a longer blink.",
			"attack": {"attack_name": "Frost Bolt", "attack_desc": "A bolt of ice that slows whoever it hits.", "frost": true, "slow": 2.0},
			"abilities": [
				{"name": "Ice Burst", "key": "Q", "kind": "fireball", "icon": "frost", "cooldown": 6.0, "cost": 45.0,
					"damage": 1, "splash": 3.5, "range": 13.0, "shot_speed": 28.0, "frost": true, "root": 1.0, "desc": "A ball of ice that freezes everyone near the blast in place."},
				{"name": "Blink", "key": "E", "kind": "blink", "icon": "blink", "cooldown": 4.0, "cost": 25.0,
					"distance": 8.0, "desc": "Teleport further in the aim direction."}]}],
	Role.HEALER: [
		{"name": "Cleric", "icon": "cleric", "tint": Color(1.0, 0.95, 0.78), "show": ["1H_Wand", "Spellbook_open"],
			"desc": "Guardian of the group: wider mending, a sanctuary that heals and shields, and a smite that bursts.",
			"attack": {"heal_radius": 6.5},
			"abilities": [
				{"name": "Sanctuary", "key": "Q", "kind": "blessing", "icon": "blessing", "cooldown": 12.0, "cost": 65.0,
					"heal": 2, "radius": 9.0, "haste": 3.0, "shield": 1.5, "desc": "Heal and speed up every teammate nearby, and shield them for a moment."},
				{"name": "Radiance", "key": "E", "kind": "smite", "icon": "smite", "cooldown": 4.0, "cost": 35.0,
					"damage": 1, "range": 12.0, "shot_speed": 36.0, "splash": 1.6, "desc": "A bolt of light that bursts on impact."}]},
		{"name": "Dark Priest", "icon": "darkpriest", "tint": Color(0.72, 0.55, 0.9), "show": ["1H_Wand", "Spellbook"],
			"desc": "Forbidden rites: bolts that drain life back to you, a curse that saps enemies, and a heavier smite.",
			"attack": {"attack_name": "Drain Bolt", "attack_desc": "Mend nearby teammates; with nobody to heal, a shadow bolt that heals you a heart per hit.",
				"drain": true, "cost": 20.0},
			"abilities": [
				{"name": "Curse", "key": "Q", "kind": "curse", "icon": "curse", "cooldown": 10.0, "cost": 50.0,
					"damage": 1, "radius": 5.0, "slow": 2.5, "desc": "Every enemy around you loses a heart and crawls for a moment."},
				{"name": "Smite", "key": "E", "kind": "smite", "icon": "smite", "cooldown": 7.0, "cost": 45.0,
					"damage": 2, "range": 12.0, "shot_speed": 36.0, "desc": "A heavy bolt of shadow: two hearts."}]}],
}

# Names for the bots, by faction.
const BOT_NAMES := [["Aelith", "Faelar", "Sylvara", "Thalion", "Nimue", "Lorien"],
	["Garrick", "Brom", "Ysolde", "Cedric", "Maud", "Aldric"]]

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
