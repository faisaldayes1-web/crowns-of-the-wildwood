extends RefCounted
## Every number that shapes a fight lives here, so balancing never means
## digging through game code. Health is counted in hearts: damage 1 = one heart.

enum Role { BASE, KNIGHT, RANGER, MAGE, HEALER, ENGINEER, ROGUE }

const MAX_HEARTS := 4
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 16.0   # per second (base attacks are sustainable; the big abilities drain it)
const MANA_MAX := 100.0
const MANA_REGEN := 9.0       # per second
const KILL_ENERGY := 20.0     # energy back on a kill, and
const KILL_COOLDOWN_CUT := 2.0  # seconds off every ability cooldown: kills chain into abilities
const RESPAWN_TIME := 7.0
const RESPAWN_PER_LEVEL := 1.0  # dying hurts more the higher you were: extra seconds per level
const RESPAWN_MAX := 13.0

# Veterans: kill streaks without dying. A Veteran is announced and marked;
# an Elite Veteran carries a bounty: revealed to the enemy, slightly tougher,
# and worth a team-wide reward to whoever brings them down.
const VETERAN_STREAK := 5
const ELITE_STREAK := 10
const ELITE_HEARTS_BONUS := 1
const ELITE_REGEN_MULT := 1.25
const BOUNTY_XP := 80
const BOUNTY_BUFF := "Might"

# Bot difficulty. aim_error is radians of random aim wobble, ability scales
# how often bots fire abilities, react scales dodging and blocking, sight
# scales how far they notice enemies, chase is how far they go after a bounty.
# Hero customizer: hair and trim (cape / sash) colours the player can pick.
const HERO_HAIR := [["Blond", Color(0.93, 0.8, 0.4)], ["Brown", Color(0.4, 0.25, 0.12)], ["Black", Color(0.12, 0.1, 0.12)],
	["Red", Color(0.75, 0.2, 0.1)], ["Silver", Color(0.85, 0.85, 0.9)], ["Moss", Color(0.35, 0.6, 0.3)]]
const HERO_TRIM := [["Team", Color.TRANSPARENT], ["Crimson", Color(0.7, 0.12, 0.15)], ["Violet", Color(0.5, 0.25, 0.7)],
	["Teal", Color(0.15, 0.6, 0.6)], ["Gold", Color(0.9, 0.72, 0.2)], ["Night", Color(0.12, 0.12, 0.18)]]
const HERO_NAME_MAX := 12
# Hero looks: Classic, and the Shadowborn look unlocked at account level 10
# (a dusk tint, violet rim light and a cape on every class).
const HERO_LOOKS := [["Classic", Color.TRANSPARENT], ["Shadowborn", Color(0.5, 0.42, 0.62)]]
# Skin tones and the unclassed body's build (Create Your Character). The
# build is the base model you spawn as; a class's own body replaces it.
const HERO_SKINS := [["Fair", Color(0.98, 0.85, 0.74)], ["Light", Color(0.96, 0.75, 0.61)], ["Tan", Color(0.84, 0.62, 0.45)],
	["Brown", Color(0.62, 0.42, 0.28)], ["Deep", Color(0.4, 0.26, 0.18)]]
const HERO_BODIES := [["Slim", "rogue"], ["Sturdy", "knight"], ["Broad", "barbarian"]]
# Face styles (scripts/face.gd, tools/make_faces.py): [name, blurb].
const HERO_FACES := [["Bold", "Steady eyes, set brows"], ["Bright", "Wide eyes and a big grin"], ["Fierce", "Narrowed eyes, a smirk"], ["Gentle", "Soft eyes, a small smile"],
	["Noble", "Calm eyes, a faint smile"], ["Sly", "Heavy lids, a crooked grin"]]
# Eye colours: [name, swatch, texture suffix]. Humans default to brown, Elves to green.
const HERO_EYES := [["Brown", Color(0.4, 0.22, 0.1), "brown"], ["Blue", Color(0.2, 0.4, 0.85), "blue"], ["Green", Color(0.2, 0.55, 0.25), "green"],
	["Grey", Color(0.5, 0.52, 0.56), "grey"], ["Amber", Color(0.9, 0.62, 0.15), "amber"], ["Red", Color(0.75, 0.15, 0.15), "red"]]
# Facial markings: [name, texture suffix ("" = none)].
const HERO_MARKS := [["None", ""], ["Scar", "scar"], ["Claws", "claws"], ["Freckles", "freckles"], ["War Paint", "paint"]]
# Maps: the Wildwood by day, and the moonlit night variant unlocked at level 10.
# Ember Pass is the volcano map (castles on basalt plateaus over lava, joined
# by bridges, and the Fire Objective in the middle); open to everyone.
const MAPS := [["Wildwood", "day"], ["Moonlit Wildwood", "night"], ["Ember Pass", "volcano"]]

# Ember Pass's Fire Objective: stand in the ring to capture it (alone it
# takes capture_time seconds, each extra teammate adds extra_rate, counted up
# to max_count); both sides inside freezes it; taking it from the other team
# first burns it back to neutral. Left alone it settles back toward its
# holder (or neutral) at `settle` times the capture rate. Bots send bots_take
# to win it and keep bots_hold on it once it is theirs, one more while enemies
# stand on it. (2 / 1 starved the raids: three draws in four test matches.)
const FIRE_POINT := {"radius": 7.0, "capture_time": 8.0, "extra_rate": 0.5, "max_count": 3, "settle": 0.25,
	"bots_take": 1, "bots_hold": 0}
# FIRE form: while a team holds the Fire Objective every one of its classes
# (and promotions) fights as its FIRE variant: the base attack sets enemies
# alight (one more heart lost burn_delay seconds later, unless a healer mends
# them first; a target only catches fire once every burn_cooldown seconds),
# and abilities cost and cool down by the multipliers. It fades the moment
# the point is lost. flame: the aura colour, Elves then Humans.
const FIRE_FORM := {"burn_delay": 2.0, "burn_cooldown": 6.0, "burn_damage": 1, "cost_mult": 0.85, "cooldown_mult": 0.85,
	"prefix": "Fire", "flame": [Color(1.0, 0.78, 0.28), Color(1.0, 0.42, 0.12)]}

# Player banners (the calling card the enemy sees when you kill them, and
# that you edit on the HERO tab): a background, an emblem, a frame and a title.
const BANNER_BACKGROUNDS := [["Forest", Color(0.12, 0.4, 0.22), Color(0.3, 0.7, 0.35), "plain"], ["Kingdom", Color(0.12, 0.2, 0.5), Color(0.3, 0.45, 0.9), "plain"],
	["Ember", Color(0.45, 0.12, 0.08), Color(0.95, 0.5, 0.15), "rays"], ["Dusk", Color(0.2, 0.1, 0.35), Color(0.6, 0.3, 0.8), "diamonds"],
	["Stripes", Color(0.15, 0.15, 0.2), Color(0.85, 0.7, 0.25), "stripes"], ["Vines", Color(0.08, 0.25, 0.15), Color(0.45, 0.8, 0.4), "leaves"],
	["Frost", Color(0.15, 0.3, 0.45), Color(0.7, 0.9, 1.0), "diamonds"], ["Royal", Color(0.35, 0.05, 0.12), Color(0.95, 0.78, 0.3), "rays"]]
const BANNER_EMBLEMS := ["crown", "class_knight", "class_ranger", "class_mage", "class_healer", "class_engineer", "crest_forest", "crest_kingdom",
	"fireball", "guard", "vigor", "trap", "blessing", "class_rogue"]   # the last needs the level-10 unlock
const BANNER_FRAMES := [["Plain", Color(0.15, 0.12, 0.18)], ["Gold", Color(0.95, 0.78, 0.3)], ["Iron", Color(0.6, 0.62, 0.68)],
	["Vine", Color(0.4, 0.75, 0.35)], ["Royal", Color(0.9, 0.4, 0.7)]]   # Royal needs the level-10 unlock
# Banner titles: [needed account level, title].
const BANNER_TITLES := [[1, "Recruit"], [1, "Door Breaker"], [2, "Crown Thief"], [3, "Militia"], [4, "Trapper"], [5, "Soldier"], [6, "Duelist"],
	[8, "Veteran"], [10, "Champion"], [10, "Shadowborn"], [15, "Warlord"], [20, "Crownbreaker"], [30, "Legend"]]

# Account progression: every point of XP you earn in a match (plus a match
# bonus) goes on your account. Level n to n+1 costs ACCOUNT_XP_BASE +
# ACCOUNT_XP_STEP * (n - 1); level 10 (the unlocks) is 9000 XP, roughly a
# dozen matches. Rank titles follow the level.
const ACCOUNT_XP_BASE := 400
const ACCOUNT_XP_STEP := 150
const ACCOUNT_MAX_LEVEL := 50
const UNLOCK_LEVEL := 10
const MATCH_BONUS := {"win": 300, "draw": 150, "loss": 100}
# Match rewards shown on the summary screen and banked on the account (the
# shop that spends them is a later milestone).
const MATCH_GOLD := {"win": 300, "draw": 250, "loss": 200}
const MATCH_SHARDS := {"win": 25, "draw": 20, "loss": 15}
# Accolades on the end-of-match screen, each worth account XP. need is the
# threshold (hearts healed, siege XP, kills in one life, assists, kills).
const ACCOLADES := [
	{"key": "crown", "name": "Crown Thief", "desc": "Carried the enemy crown home.", "xp": 100, "icon": "crown"},
	{"key": "slayer", "name": "Giant Slayer", "desc": "Felled an enemy two levels above you.", "xp": 40, "icon": "vanguard"},
	{"key": "streak", "name": "Unstoppable", "desc": "Five kills in a single life.", "need": 5, "xp": 50, "icon": "takedown"},
	{"key": "untouchable", "name": "Untouchable", "desc": "Three or more kills and never fell.", "need": 3, "xp": 50, "icon": "block"},
	{"key": "top", "name": "Top Blade", "desc": "The most kills in the match.", "need": 3, "xp": 40, "icon": "vanguard"},
	{"key": "medic", "name": "Field Medic", "desc": "Healed twelve hearts on teammates.", "need": 12, "xp": 40, "icon": "mend"},
	{"key": "breaker", "name": "Siege Breaker", "desc": "Battered enemy doors, turrets and the vault.", "need": 40, "xp": 40, "icon": "hammer"},
	{"key": "wingman", "name": "Wingman", "desc": "Six or more assists.", "need": 6, "xp": 30, "icon": "guard"},
	{"key": "promoted", "name": "Promoted", "desc": "Earned a class promotion.", "xp": 30, "icon": "upgrade"}]
const RANK_TITLES := [[1, "Recruit"], [3, "Militia"], [5, "Soldier"], [8, "Veteran"], [10, "Champion"],
	[15, "Warlord"], [20, "Crownbreaker"], [30, "Legend"], [40, "Mythic"], [50, "Immortal"]]
const UNLOCKS := [["class", "Rogue", "A sixth class: daggers, shadow dashes and smoke bombs."],
	["look", "Shadowborn", "A hero look: dusk-tinted armour, violet rim light and a cape on every class."],
	["map", "Moonlit Wildwood", "A night map: moonlight, mist, lanterns and fireflies everywhere."]]


static func account_level_cost(level: int) -> int:
	return ACCOUNT_XP_BASE + ACCOUNT_XP_STEP * (level - 1)


static func account_level(xp: int) -> int:
	var level := 1
	var left := xp
	while level < ACCOUNT_MAX_LEVEL and left >= account_level_cost(level):
		left -= account_level_cost(level)
		level += 1
	return level


static func account_span(xp: int) -> Array:
	## [xp into the current level, xp the level needs] (needs -1 at max).
	var level := 1
	var left := xp
	while level < ACCOUNT_MAX_LEVEL and left >= account_level_cost(level):
		left -= account_level_cost(level)
		level += 1
	return [left, account_level_cost(level) if level < ACCOUNT_MAX_LEVEL else -1]


static func rank_title(level: int) -> String:
	var title := "Recruit"
	for entry in RANK_TITLES:
		if level >= entry[0]:
			title = entry[1]
	return title
const BOT_DIFFICULTIES := ["Easy", "Normal", "Hard"]
const BOT_TUNING := {
	"Easy": {"aim_error": 0.4, "ability": 0.45, "react": 0.4, "sight": 0.8, "chase": 0.0, "desc": "Bots miss a lot, rarely use abilities and seldom dodge."},
	"Normal": {"aim_error": 0.12, "ability": 1.0, "react": 1.0, "sight": 1.0, "chase": 18.0, "desc": "A fair fight: bots aim well and use their kit."},
	"Hard": {"aim_error": 0.03, "ability": 1.9, "react": 1.6, "sight": 1.3, "chase": 30.0, "desc": "Bots aim true, chain abilities, dodge often and hunt veterans."},
}
const CARRY_SPEED_MULT := 0.8

const DODGE_TIME := 0.25      # seconds the dash lasts; nothing can hit you during it
const DODGE_SPEED_MULT := 3.2 # dash speed as a multiple of run speed
const DODGE_COOLDOWN := 4.0   # seconds until the next dodge is ready (2.0 → 4.0, Faisal 2026-10-09)
const DODGE_COST := 10.0      # stamina (or mana) a dodge spends
# Basic attacks (every class's left-click: Punch, Sword Strike, arrows, bolts,
# Mend) cost nothing (Faisal 2026-10-09: "the basic attack shouldn't drain
# your stamina or magika"). The per-class "cost" values in ROLES, FACTION_KITS
# and VARIANTS (7-16) are kept for reference but overridden by this.
const BASE_ATTACK_COST := 0.0

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
const GATE_HITS := 200        # door damage a castle door soaks before it breaks (a squad of three opens it in ~25 s)
const BARRICADE_HITS := 8
const BARRICADE_TEAM := 4      # barricade kits a team can raise during the fortify phase
const BARRICADE_LENGTH := 3.2
const PREP_TIME := 20.0        # the fortify phase: a barrier splits the field while both sides dig in
const BARRICADE_REBUILD := 45.0
const VAULT_HITS := 10        # hits to break the Crown Vault's lock (about 5 s for one Knight)
const VAULT_RELOCK_TIME := 30.0
const SPAWN_PROTECT_TIME := 3.0  # seconds of invulnerability after spawning (ends on leaving the cellar)
# Defending home: the bonus a team gets inside its own castle (and cellar).
# resist and heal are fractions: every 1/resist-th hit is absorbed, every
# 1/heal-th heart healed is doubled; regen is a multiplier bonus; interact
# speeds up the door's rebuild while a defender stands by it.
const DEFENDER := {"resist": 0.1, "heal": 0.1, "regen": 0.1, "interact": 0.15}
const GATE_REBUILD_TIME := 40.0
const RALLY := {"dist": 20.0, "group": 2, "radius": 9.0, "wait": 14.0}  # raiders gather this far outside the enemy door until `group` are together (or `wait` seconds pass)
const COMMAND_TIME := 15.0    # how long a quick command (Attack! / Defend! / To me!) steers the bots
const GATE_SIEGE_RADIUS := 9.0   # a broken door does not rebuild while an enemy is this close to it (or inside)
# Engineer turrets, per level 1-3: hits they soak, reach and seconds between
# bolts. They go on your castle walls or grounds (up to GROUNDS metres
# outside the front wall), never in the door lane.
const TURRET := {"hits": [8, 12, 16], "range": [7.0, 8.0, 9.0], "interval": [1.5, 1.2, 0.95],
	"damage": 1, "shot_speed": 34.0, "max_level": 3, "team_max": 6, "place_dist": 1.8, "grounds": 14.0,
	"door_repair": 12.0}
const MATCH_TIME := 600.0     # seconds
const SEAL_REACH := 2.2     # how close you stand to a class seal to grab it with F
const OVERTIME := 120.0       # a tie at full time: both doors fall, nobody respawns, next capture or last team standing wins
const CAPTURES_TO_WIN := 2

# Experience, earned in battle. Each level gives one rank point to spend in
# the rank menu on Attack, Q, E or Vigor. Falling costs DEATH_LEVEL_LOSS levels
# and the ranks bought with them (the most recent first), not the whole climb.
const XP_LEVELS := [40, 100, 180, 280, 400]   # xp needed for level 2, 3, 4, 5, 6
const XP_HIT := 10            # per heart of damage dealt
const XP_KILL := 40
const XP_HEAL := 8            # per heart healed on a teammate
const XP_GATE := 1            # per door hit
const XP_TURRET := 30         # for wrecking an enemy turret
const XP_GRAB := 25           # picking up the enemy monarch
const XP_CAPTURE := 100
const XP_UPSET := 15          # extra kill XP per level the victim had above you (fresh soldiers hunt veterans)
const DEATH_LEVEL_LOSS := 2   # levels you drop when you fall (was: back to level 1, every rank gone)
const MAX_RANK := 3
# Per rank: abilities cool down and cost less; Vigor makes you quicker and
# gives you a bigger stamina or mana pool. Rank 2 widens the effect
# (radius, distance, duration, arrows) and rank 3 adds a heart of damage/heal.
# (Toned down 2026-10-05: a maxed character used to get a whole extra heart of
# damage on every ability plus a third off cooldowns and costs; a fresh base
# soldier should still be able to hold their own, since death resets ranks.)
const RANK_COOLDOWN_CUT := 0.08
const RANK_COST_CUT := 0.08
const RANK_EFFECT_BOOST := 0.2   # Q/E only: the base attack's reach never grows with rank (2026-10-07: ranked bows out-ranged everyone)
# Bows and staves fire this much slower than their listed cooldown (2026-10-07:
# ranged classes out-killed melee 1.6 to 0.5 K/D over 18 bot matches).
const RANGED_ATTACK_SLOW := 1.15
const VIGOR_SPEED := 0.05
const VIGOR_ENERGY := 12.0
const VIGOR_REGEN := 0.2
const RANK_TRACKS := ["Attack", "Q", "E", "Vigor"]

# Scoreboard: what a player's match score is made of.
const SCORE_KILL := 10
const SCORE_ASSIST := 4
const XP_ASSIST := 15
const ASSIST_WINDOW := 8.0   # seconds after your hit that a kill still counts as an assist
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
		"damage": 1, "gate_damage": 1, "range": 1.7, "cooldown": 0.72,   # 0.6 → 0.72 (Faisal 2026-10-09)
		"energy": "stamina", "cost": 8, "speed": 1.0,
		"color": Color(0.85, 0.8, 0.7), "abilities": []},
	Role.KNIGHT: {"attack": "melee", "attack_name": "Sword Strike", "attack_desc": "A wide swing that also chips at doors.",
		"damage": 1, "gate_damage": 2, "range": 2.2, "cooldown": 0.55,
		"energy": "stamina", "cost": 8, "speed": 1.14, "block": true, "armour": 0.34,   # speed 1.06 → 1.10 (patch 1) → 1.14 (patch 3)
		"color": Color(0.8, 0.8, 0.85), "abilities": [
			{"name": "Shield Bash", "key": "Q", "kind": "bash", "cooldown": 4, "cost": 35.0,
				"damage": 2, "distance": 4.0, "desc": "Charge forward: two hearts to everyone in the way, and a shove."},
			{"name": "Shield Wall", "key": "E", "kind": "guard", "cooldown": 7, "cost": 40.0,
				"duration": 1.8, "desc": "Nothing gets through your shield for a moment, from any side."}]},
	Role.RANGER: {"attack": "arrow", "attack_name": "Quick Shot", "attack_desc": "A fast arrow. Shoot down from the walls.",
		"damage": 1, "gate_damage": 1, "range": 15.0, "cooldown": 0.55,
		"energy": "stamina", "cost": 8, "speed": 1.05, "shot_speed": 40.0,
		"color": Color(0.35, 0.55, 0.25), "abilities": [
			{"name": "Volley", "key": "Q", "kind": "volley", "cooldown": 5, "cost": 40.0,
				"damage": 1, "arrows": 5, "spread": 24.0, "range": 15.0, "shot_speed": 40.0, "desc": "A fan of five arrows."},
			{"name": "Snare Trap", "key": "E", "kind": "trap", "cooldown": 6, "cost": 35.0,
				"damage": 1, "root": 2.0, "lifetime": 30.0, "desc": "Plant a trap that roots and hurts the first enemy on it."}]},
	Role.MAGE: {"attack": "spell", "attack_name": "Arcane Bolt", "attack_desc": "A bolt that bursts on impact.",
		"damage": 1, "gate_damage": 2, "range": 13.0, "cooldown": 0.65,
		"energy": "mana", "cost": 12.0, "splash": 1.0, "speed": 0.95,   # splash 1.4 → 1.0 (patch 3: a sidestep now dodges the bolt) "shot_speed": 32.0,
		"color": Color(0.45, 0.3, 0.85), "abilities": [
			{"name": "Fireball", "key": "Q", "kind": "fireball", "cooldown": 5, "cost": 55.0,
				"damage": 2, "splash": 3.2, "range": 13.0, "shot_speed": 24.0, "desc": "A big slow ball of fire: two hearts to everyone near the blast, four hits to a door."},
			{"name": "Blink", "key": "E", "kind": "blink", "cooldown": 5, "cost": 30.0,   # cooldown 4 → 5 (patch 3)
				"distance": 6.0, "desc": "Teleport a short way in the aim direction."}]},
	Role.ENGINEER: {"attack": "melee", "attack_name": "Hammer", "attack_desc": "A heavy swing that wrecks doors, fences and turrets.",
		"damage": 1, "gate_damage": 3, "range": 1.9, "cooldown": 0.6,
		"energy": "stamina", "cost": 9, "speed": 0.98, "armour": 0.2,
		"color": Color(0.85, 0.6, 0.3), "abilities": [
			{"name": "Build Turret", "key": "Q", "kind": "turret", "cooldown": 6, "cost": 45.0,
				"turrets": 2, "desc": "Build a bolt turret in front of you, on your castle walls or grounds. Two at a time; the oldest makes way."},
			{"name": "Tune Up", "key": "E", "kind": "upgrade", "cooldown": 4, "cost": 35.0,
				"desc": "Repair the nearest of your turrets and raise it a level (up to 3), or hurry your door's rebuild."}]},
	Role.ROGUE: {"attack": "melee", "attack_name": "Daggers", "attack_desc": "Two quick blades: the fastest strikes in the game, short reach.",
		"damage": 1, "gate_damage": 1, "range": 1.5, "cooldown": 0.38,
		"energy": "stamina", "cost": 6, "speed": 1.12,
		"color": Color(0.6, 0.4, 0.75), "abilities": [
			{"name": "Shadow Dash", "key": "Q", "kind": "bash", "cooldown": 4, "cost": 35.0,
				"damage": 1, "distance": 5.5, "desc": "A dash through the shadows that cuts everyone in the way for a heart."},
			{"name": "Smoke Bomb", "key": "E", "kind": "smoke", "cooldown": 7, "cost": 40.0,
				"duration": 3.0, "haste": 3.0, "desc": "Vanish in smoke: enemies lose you and you run faster for a moment."}]},
	Role.HEALER: {"attack": "heal", "attack_name": "Mend", "attack_desc": "Heal hurt teammates around you; with nobody to heal, fire a holy bolt instead.",
		"damage": 1, "gate_damage": 1, "range": 10.0, "cooldown": 0.8,
		"energy": "mana", "cost": 16.0, "heal": 1, "heal_radius": 5.0, "speed": 1.0, "shot_speed": 30.0,
		"color": Color(0.95, 0.93, 0.8), "abilities": [
			{"name": "Blessing", "key": "Q", "kind": "blessing", "cooldown": 8, "cost": 60.0,
				"heal": 2, "radius": 8.0, "haste": 3.0, "desc": "Heal every teammate nearby two hearts and speed them up."},
			{"name": "Smite", "key": "E", "kind": "smite", "cooldown": 3, "cost": 30.0,
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
				"range": 2.8, "cooldown": 0.65, "cost": 12, "gate_damage": 3, "block": false, "armour": 0.45},   # armour 0.42 → 0.45 (patch 5)
			"abilities": [
				{"name": "Cleave", "key": "Q", "kind": "cleave", "icon": "cleave", "cooldown": 4.5, "cost": 40.0,
					"damage": 1, "radius": 3.2, "desc": "Spin with the greatsword, hitting and shoving everyone around you."},
				{"name": "Charge", "key": "E", "kind": "bash", "icon": "bash", "cooldown": 4.5, "cost": 40.0,
					"damage": 2, "distance": 6.5, "desc": "A long charge that bowls over everyone in the way for two hearts."}]},
		{"name": "Warden", "icon": "warden", "tint": Color(0.78, 0.84, 1.0), "show": ["1H_Sword", "Rectangle_Shield"],
			"desc": "Tower shield defence: a slam that pins enemies down and a bulwark that shields nearby teammates too.",
			"attack": {"attack_name": "Mace", "attack_desc": "A short, heavy blow that batters doors.",
				"range": 2.2, "cooldown": 0.55, "gate_damage": 3},   # range 2.0 → 2.2 (patch 1)
			"abilities": [
				{"name": "Shield Slam", "key": "Q", "kind": "bash", "icon": "bash", "cooldown": 4, "cost": 40.0,
					"damage": 2, "distance": 3.5, "root": 1.2, "desc": "A short charge for two hearts that pins everyone it hits in place."},
				{"name": "Bulwark", "key": "E", "kind": "guard", "icon": "guard", "cooldown": 7, "cost": 40.0,
					"duration": 2.5, "share": 4.0, "desc": "A longer Shield Wall that also shields teammates close to you."}]}],
	Role.RANGER: [
		{"name": "Sharpshooter", "icon": "sharpshooter", "tint": Color(0.6, 0.8, 0.55), "show": ["2H_Crossbow"],
			"desc": "Longbow marksman: longer, faster arrows, a piercing shot and a two-heart snipe.",
			"attack": {"attack_name": "Longbow", "attack_desc": "A long, fast arrow.", "range": 20.0, "cooldown": 0.65, "shot_speed": 55.0},
			"abilities": [
				{"name": "Piercing Shot", "key": "Q", "kind": "shot", "icon": "pierce", "cooldown": 4, "cost": 40.0,
					"damage": 1, "range": 20.0, "shot_speed": 55.0, "pierce": true, "desc": "An arrow that flies through everyone in its line."},
				{"name": "Snipe", "key": "E", "kind": "shot", "icon": "snipe", "cooldown": 7, "cost": 50.0,
					"damage": 2, "range": 24.0, "shot_speed": 70.0, "desc": "A slow-to-ready shot that takes two hearts."}]},
		{"name": "Trapper", "icon": "trapper", "tint": Color(0.75, 0.6, 0.4), "show": ["1H_Crossbow", "Knife_Offhand"],
			"desc": "Hunter's tricks: slowing arrows, a line of three traps and a smoke bomb that hides you.",
			"attack": {"attack_name": "Poison Arrow", "attack_desc": "An arrow that slows whoever it hits.", "slow": 1.5},
			"abilities": [
				{"name": "Trap Line", "key": "Q", "kind": "trap", "icon": "trap", "cooldown": 7, "cost": 40.0,
					"damage": 1, "root": 2.0, "lifetime": 30.0, "count": 3, "desc": "Plant three snare traps in a row."},
				{"name": "Smoke Bomb", "key": "E", "kind": "smoke", "icon": "smoke", "cooldown": 7, "cost": 40.0,
					"duration": 3.0, "haste": 3.0, "desc": "Vanish in smoke: enemies lose you and you run faster for a moment."}]}],
	Role.MAGE: [
		{"name": "Pyromancer", "icon": "pyromancer", "tint": Color(1.0, 0.6, 0.4), "show": ["2H_Staff"],
			"desc": "Fire: burning bolts, a huge fireball and a wave of flame in front of you.",
			"attack": {"attack_name": "Ember Bolt", "attack_desc": "A burning bolt that splashes.", "fire": true, "splash": 1.3},   # splash 1.8 → 1.3 (patch 3)
			"abilities": [
				{"name": "Inferno", "key": "Q", "kind": "fireball", "icon": "fireball", "cooldown": 6, "cost": 60.0,
					"damage": 2, "splash": 4.5, "range": 13.0, "shot_speed": 24.0, "desc": "A huge fireball: two hearts to everyone near the blast."},
				{"name": "Flame Wave", "key": "E", "kind": "cleave", "icon": "wave", "cooldown": 5, "cost": 40.0,
					"damage": 1, "radius": 4.5, "cone": true, "fire": true, "desc": "A fan of fire that burns everyone in front of you."}]},
		{"name": "Frostweaver", "icon": "frostweaver", "tint": Color(0.65, 0.88, 1.0), "show": ["2H_Staff"],
			"desc": "Ice: slowing bolts, a freezing burst and a longer blink.",
			"attack": {"attack_name": "Frost Bolt", "attack_desc": "A bolt of ice that slows whoever it hits.", "frost": true, "slow": 2.0},
			"abilities": [
				{"name": "Ice Burst", "key": "Q", "kind": "fireball", "icon": "frost", "cooldown": 5, "cost": 45.0,
					"damage": 1, "splash": 3.5, "range": 13.0, "shot_speed": 28.0, "frost": true, "root": 1.0, "desc": "A ball of ice that freezes everyone near the blast in place."},
				{"name": "Blink", "key": "E", "kind": "blink", "icon": "blink", "cooldown": 4, "cost": 30.0,   # cooldown 3 → 4 (patch 3)
					"distance": 8.0, "desc": "Teleport further in the aim direction."}]}],
	Role.ROGUE: [
		{"name": "Assassin", "icon": "assassin", "tint": Color(0.75, 0.55, 0.9), "show": ["1H_Sword"],
			"attacks": ["1H_Melee_Attack_Stab", "1H_Melee_Attack_Slice_Diagonal"], "idle": "Idle",
			"desc": "The killer: venomed blades that slow, a backstab dash for two hearts, and a vanish.",
			"attack": {"attack_name": "Venom Fang", "attack_desc": "A quick cut that slows whoever it catches.", "slow": 0.8, "cost": 7},
			"abilities": [
				{"name": "Backstab", "key": "Q", "kind": "bash", "icon": "bash", "cooldown": 4, "cost": 40.0,
					"damage": 2, "distance": 4.5, "desc": "A short lunge that takes two hearts from everyone in the way."},
				{"name": "Vanish", "key": "E", "kind": "smoke", "icon": "smoke", "cooldown": 7, "cost": 40.0,
					"duration": 3.5, "haste": 3.5, "desc": "Vanish in smoke: enemies lose you and you run faster."}]},
		{"name": "Nightrunner", "icon": "nightrunner", "tint": Color(0.6, 0.7, 0.95), "show": ["1H_Sword"],
			"attacks": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"], "idle": "Idle",
			"desc": "The runner: the quickest feet in the game, a long shadow step and caltrops behind you.",
			"attack": {"attack_name": "Quick Blades", "attack_desc": "Fast strikes with a little more reach.", "range": 1.7, "cooldown": 0.36, "cost": 6, "speed": 1.18},
			"abilities": [
				{"name": "Shadow Step", "key": "Q", "kind": "blink", "icon": "blink", "cooldown": 4, "cost": 30.0,
					"distance": 7.5, "desc": "Step through the shadows, further than any blink."},
				{"name": "Caltrops", "key": "E", "kind": "trap", "icon": "trap", "cooldown": 6, "cost": 35.0,
					"damage": 1, "slow": 2.5, "count": 2, "lifetime": 30.0, "desc": "Two spreads of caltrops that hurt and slow the first enemy on them."}]}],
	Role.ENGINEER: [
		{"name": "Artificer", "icon": "artificer", "tint": Color(0.75, 0.9, 1.0), "show": ["1H_Axe"],
			"desc": "Clockwork: three rapid-fire turrets at a time, and an overclock that doubles their fire for a moment.",
			"attack": {"attack_name": "Spanner", "attack_desc": "A quick, light swing.", "cooldown": 0.5, "cost": 9, "gate_damage": 2},
			"abilities": [
				{"name": "Rapid Turret", "key": "Q", "kind": "turret", "icon": "turret", "cooldown": 5, "cost": 40.0,
					"turrets": 3, "rapid": true, "desc": "A quick-firing turret. Three at a time."},
				{"name": "Overclock", "key": "E", "kind": "overclock", "icon": "overclock", "cooldown": 8, "cost": 40.0,
					"duration": 6.0, "desc": "Every turret you built fires twice as fast for six seconds."}]},
		{"name": "Siegewright", "icon": "siegewright", "tint": Color(1.0, 0.8, 0.6), "show": ["2H_Axe"],
			"attacks": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"], "idle": "2H_Melee_Idle",
			"desc": "Heavy works: a sledge that batters doors, ballista turrets with splashing bolts, and door repairs.",
			"attack": {"attack_name": "Sledge", "attack_desc": "A slow, heavy blow: five hits to a door. The siege harness turns about every fourth hit.", "range": 2.2, "cooldown": 0.75, "cost": 13, "gate_damage": 5, "armour": 0.3},
			"abilities": [
				{"name": "Ballista", "key": "Q", "kind": "turret", "icon": "turret", "cooldown": 7, "cost": 50.0,
					"turrets": 2, "ballista": true, "desc": "A slow turret whose bolts burst on impact and reach further."},
				{"name": "Fortify", "key": "E", "kind": "upgrade", "icon": "upgrade", "cooldown": 5, "cost": 40.0,
					"door": 60, "desc": "Tune up the nearest turret, or mend your door by 60 hits (and hurry its rebuild)."}]}],
	Role.HEALER: [
		{"name": "Cleric", "icon": "cleric", "tint": Color(1.0, 0.95, 0.78), "show": ["1H_Wand", "Spellbook_open"],
			"desc": "Guardian of the group: wider mending, a sanctuary that heals and shields, and a smite that bursts.",
			"attack": {"heal_radius": 6.5},
			"abilities": [
				{"name": "Sanctuary", "key": "Q", "kind": "blessing", "icon": "blessing", "cooldown": 8, "cost": 65.0,
					"heal": 2, "radius": 9.0, "haste": 3.0, "shield": 1.5, "desc": "Heal and speed up every teammate nearby, and shield them for a moment."},
				{"name": "Radiance", "key": "E", "kind": "smite", "icon": "smite", "cooldown": 3.5, "cost": 40.0,
					"damage": 1, "range": 12.0, "shot_speed": 36.0, "splash": 1.6, "desc": "A bolt of light that bursts on impact."}]},
		{"name": "Dark Priest", "icon": "darkpriest", "tint": Color(0.72, 0.55, 0.9), "show": ["1H_Wand", "Spellbook"],
			"desc": "Forbidden rites: bolts that drain life back to you, a curse that saps enemies, and a heavier smite.",
			"attack": {"attack_name": "Drain Bolt", "attack_desc": "Mend nearby teammates; with nobody to heal, a shadow bolt that heals you a heart per hit.",
				"drain": true, "cost": 21.0},
			"abilities": [
				{"name": "Curse", "key": "Q", "kind": "curse", "icon": "curse", "cooldown": 8, "cost": 50.0,
					"damage": 1, "radius": 5.0, "slow": 2.5, "desc": "Every enemy around you loses a heart and crawls for a moment."},
				{"name": "Smite", "key": "E", "kind": "smite", "icon": "smite", "cooldown": 5, "cost": 45.0,
					"damage": 2, "range": 12.0, "shot_speed": 36.0, "desc": "A heavy bolt of shadow: two hearts."}]}],
}

# Faction kits: the same five classes play differently for each side. An
# entry's "attack" fields override the class's base attack, "abilities"
# replace Q and E. Elves are wind and wood (glaives, moonbows, brambles,
# living totems); Humans are steel and faith (shields, crossbows, fire, holy
# light). Promotions sit on top of the kit and are shared by both sides.
const FACTION_KITS := {
	0: {
		Role.KNIGHT: {
			"attack": {"attack_name": "Glaive", "attack_desc": "A light, long-reaching sweep: quicker than a sword.", "range": 2.5, "cooldown": 0.5, "cost": 8, "armour": 0.37},   # armour 0.32 → 0.37 (patch 5: matches the Human plate)
			"abilities": [
				{"name": "Wind Dash", "key": "Q", "kind": "bash", "icon": "bash", "cooldown": 4.5, "cost": 30.0,   # patch 5: damage 1 → 2, cooldown 3.5 → 4.5
					"damage": 2, "distance": 6.0, "desc": "A long, leaf-light dash that cuts everyone in the way for two hearts and shoves them aside."},
				{"name": "Barkskin", "key": "E", "kind": "guard", "icon": "guard", "cooldown": 7, "cost": 35.0,
					"duration": 1.6, "desc": "Living bark turns every blow for a moment, from any side."}]},
		Role.RANGER: {
			"attack": {"attack_name": "Moonbow", "attack_desc": "Swift silver arrows with long reach.", "range": 16.0, "cooldown": 0.55, "cost": 8, "shot_speed": 46.0},
			"abilities": [
				{"name": "Starfall", "key": "Q", "kind": "volley", "icon": "volley", "cooldown": 5, "cost": 40.0,
					"damage": 1, "arrows": 6, "spread": 30.0, "range": 16.0, "shot_speed": 46.0, "desc": "A fan of six silver arrows."},
				{"name": "Vine Snare", "key": "E", "kind": "trap", "icon": "trap", "cooldown": 6, "cost": 35.0,
					"damage": 1, "root": 2.5, "lifetime": 30.0, "desc": "A living snare that roots the first enemy who steps on it."}]},
		Role.MAGE: {
			"attack": {"attack_name": "Thorn Bolt", "attack_desc": "A seed that bursts into thorns and slows whoever it catches.", "slow": 0.8, "splash": 1.0, "cost": 12.0, "nature": true},   # splash 1.3 → 1.0 (patch 3)
			"abilities": [
				{"name": "Bramble Burst", "key": "Q", "kind": "fireball", "icon": "bramble", "cooldown": 5, "cost": 50.0,
					"damage": 1, "splash": 3.4, "range": 13.0, "shot_speed": 26.0, "root": 1.3, "nature": true, "desc": "A seed-ball that bursts into brambles: a heart to everyone near the blast, and they are rooted."},
				{"name": "Fae Step", "key": "E", "kind": "blink", "icon": "blink", "cooldown": 5, "cost": 30.0,   # cooldown 4 → 5 (patch 3)
					"distance": 7.5, "desc": "Step along the fae paths, further than any blink."}]},
		Role.HEALER: {
			"attack": {"attack_name": "Grove Mend", "attack_desc": "Mend teammates around you with living light; with nobody to heal, a bolt of moonlight.", "heal_radius": 5.0, "cooldown": 0.7, "cost": 16.0},
			"abilities": [
				{"name": "Spirit Bloom", "key": "Q", "kind": "blessing", "icon": "blessing", "cooldown": 8, "cost": 60.0,
					"heal": 2, "radius": 8.0, "haste": 4.0, "desc": "Heal every teammate nearby two hearts and quicken them."},
				{"name": "Lunar Lance", "key": "E", "kind": "smite", "icon": "smite", "cooldown": 4, "cost": 30.0,   # cooldown 3 → 4 (patch 4)
					"damage": 1, "range": 13.0, "shot_speed": 38.0, "slow": 1.5, "desc": "A lance of moonlight that slows whoever it hits."}]},
		Role.ENGINEER: {
			"attack": {"attack_name": "Root Maul", "attack_desc": "A heavy wooden maul that wrecks doors, fences and turrets.", "cost": 9},
			"abilities": [
				{"name": "Thorn Totem", "key": "Q", "kind": "turret", "icon": "turret", "cooldown": 6, "cost": 45.0,
					"turrets": 2, "thorn": true, "desc": "A living totem that spits slowing thorns, on your walls or grounds. Two at a time."},
				{"name": "Tend", "key": "E", "kind": "upgrade", "icon": "upgrade", "cooldown": 4, "cost": 35.0,
					"desc": "Grow the nearest of your totems a level (up to 3) and heal it, or hurry your door's regrowth."}]},
	},
	1: {
		Role.KNIGHT: {"attack": {"attack_desc": "A wide swing that also chips at doors. Heavy plate turns about every third hit.", "armour": 0.37}},
		Role.RANGER: {
			"attack": {"attack_name": "Crossbow", "attack_desc": "Heavy bolts: slower to load, hit harder from the walls.", "range": 16.0, "cooldown": 0.62, "cost": 10, "shot_speed": 42.0},   # cooldown 0.75 → 0.68 (patch 1) → 0.62 (patch 4: Moonbow is 0.55)
			"abilities": [
				{"name": "Heavy Bolt", "key": "Q", "kind": "shot", "icon": "snipe", "cooldown": 4, "cost": 40.0,
					"damage": 2, "range": 16.0, "shot_speed": 50.0, "desc": "A wound-up bolt that takes two hearts."},
				{"name": "Caltrops", "key": "E", "kind": "trap", "icon": "trap", "cooldown": 6, "cost": 35.0,
					"damage": 1, "slow": 2.5, "count": 2, "lifetime": 30.0, "desc": "Two spreads of caltrops that hurt and slow the first enemy on them."}]},
		Role.HEALER: {
			"attack": {"attack_name": "Prayer", "attack_desc": "Heal hurt teammates around you; with nobody to heal, fire a holy bolt instead."},
			"abilities": [
				{"name": "Blessing", "key": "Q", "kind": "blessing", "icon": "blessing", "cooldown": 8, "cost": 60.0,
					"heal": 2, "radius": 8.0, "haste": 3.0, "shield": 1.0, "desc": "Heal every teammate nearby two hearts, speed them up and shield them for a second."},
				{"name": "Holy Bubble", "key": "E", "kind": "bubble", "icon": "bubble", "cooldown": 8, "cost": 45.0,
					"duration": 2.0, "radius": 3.0, "desc": "A dome of light: nothing can hurt you or the teammates inside it for two seconds."}]},
	},
}


static func kit(team: int, role: int) -> Dictionary:
	## The class table entry for `role` as `team` plays it.
	var s: Dictionary = ROLES[role].duplicate(true)
	var k: Dictionary = FACTION_KITS.get(team, {}).get(role, {})
	if k.has("attack"):
		s.merge(k.attack, true)
	if k.has("abilities"):
		s.abilities = k.abilities
	return s


# Names for the bots, by faction.
const BOT_NAMES := [["Aelith", "Faelar", "Sylvara", "Thalion", "Nimue", "Lorien"],
	["Garrick", "Brom", "Ysolde", "Cedric", "Maud", "Aldric"]]

# Elves are quicker on their feet; humans recover stamina and mana faster.
# (Regen limits attack rate, so it is worth more than it looks: 1.3 made the
# Humans win three of every four bot matches; 1.12 was still winning two of three once raids rallied and escorted, so 1.06.)
const FACTIONS := [
	{"name": "Elves", "realm": "Forest", "color": Color(0.25, 0.7, 0.35), "speed": 6.15, "regen_mult": 1.0,   # 6.3 → 6.15 (patch 2: still the quicker side, less kiting edge)
		"roles": ["Elf", "Knight", "Ranger", "Mage", "Healer", "Engineer", "Rogue"]},
	{"name": "Humans", "realm": "Kingdom", "color": Color(0.25, 0.45, 0.9), "speed": 6.0, "regen_mult": 1.15,   # 1.06 → 1.15 (patch 1: basic attacks went free, so faster regen is worth less)
		"roles": ["Human", "Knight", "Ranger", "Mage", "Healer", "Engineer", "Rogue"]},
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
