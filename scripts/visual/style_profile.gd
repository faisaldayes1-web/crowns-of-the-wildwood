extends RefCounted
## The match world's shared art direction (visual overhaul, 2026-10-14, to
## Faisal's "Crowns of the Wildwood Visual Style Guide"): one table of the
## values every world builder in game.gd and volcano.gd reads, so stone,
## timber, bark, foliage, ground, water and light follow one grammar.
##
## Match worlds and the native menu title/hall share the material grammar.
## World light grades remain map-specific; the hall uses a warm key with
## cooler ambient fill and the title uses the shared daylight sun.
##
## Grammar (world units = metres at the game's UV scales):
##   cobble ~0.8 m, wall block ~0.5 x 0.8 m, floor slab ~1 m, plank ~0.25 m,
##   bark groove ~0.25 m; soft rounded bevels, mid-value joints, matte fills;
##   normal strength 0.5-0.7 of the old maps; roughness 0.9-1.0 (no sheen on
##   stone, wood or leaves); metal and gold the only glossy surfaces.

# Texture families: the style/ copy of each texture (tools/make_style_textures.py),
# the normal map strength and roughness its materials get.
const TEX := {
	"stone": {"normal": 0.7, "rough": 0.92},
	"greystone": {"normal": 0.7, "rough": 0.92},
	"flagstone": {"normal": 0.6, "rough": 0.9},
	"flagstone_moss": {"normal": 0.6, "rough": 0.9},
	"flagstone_grey": {"normal": 0.6, "rough": 0.9},
	"rock": {"normal": 0.6, "rough": 0.95},
	"cobble": {"normal": 0.6, "rough": 0.95},
	"wood": {"normal": 0.5, "rough": 0.9},
	"wood_dark": {"normal": 0.5, "rough": 0.9},
	"bark": {"normal": 0.6, "rough": 1.0},
	"grass": {"normal": 0.4, "rough": 1.0},
}
const TEX_DIR := "res://assets/textures/style/"

# Foliage: one value ramp for every leafy thing (broadleaf crowns, bushes,
# hedges, pines), from the shade under a crown to its sunlit top. HSV.
const LEAF_BOTTOM := Vector3(0.36, 0.80, 0.28)
const LEAF_TOP := Vector3(0.26, 0.74, 0.74)      # warm yellow-green highlights (the guide's trees)
const LEAF_HUE_JITTER := 0.025
const PINE_BOTTOM := Vector3(0.41, 0.80, 0.24)   # the same ramp, cooler and a step darker
const PINE_TOP := Vector3(0.31, 0.66, 0.60)
const WILD_BOTTOM := Vector3(0.42, 0.85, 0.20)   # Elf-side wildwood green
const WILD_TOP := Vector3(0.36, 0.72, 0.56)
const BLOSSOM_BOTTOM := Vector3(0.88, 0.62, 0.40)  # the Wildwood's pink blossom trees
const BLOSSOM_TOP := Vector3(0.90, 0.42, 0.88)
const AUTUMN_BOTTOM := Color(0.58, 0.28, 0.09)
const AUTUMN_TOP := Color(0.96, 0.62, 0.20)
const GOLD_BOTTOM := Color(0.56, 0.38, 0.08)     # the Human wood's golden pines
const GOLD_TOP := Color(0.98, 0.80, 0.28)
const LEAF_RIM := 0.35          # the dark cut-out rim on crown silhouettes (was 0.6)
const LEAF_CLUMP := 0.55        # how deep the shader's leaf tufts read (0 = smooth blobs)

# Emission budget: ambient decoration glows softly; gameplay cues (crowns,
# pickups, the Fire Objective, skill effects) keep their own, brighter glow.
const DECOR_GLOW_MAX := 1.2     # wildwood blossoms and buds (were 3.0)

# Ground detail: patches of flowers and tufts with open lawn between them.
const FLOWERS := 1900           # was 3200, spread evenly
const TUFTS := 5500             # was 9000
const PATCH_FREQ := 0.055       # patch noise frequency (1/m): patches ~10-15 m across
const FLOWER_PATCH := 0.18      # noise above this grows flowers (about a third of the open lawn)
const TUFT_PATCH := -0.15       # tufts are lusher: most of the lawn, thinning in the open
const TUFT_HSV := Vector3(0.29, 0.78, 0.36)  # tufts sit a shade under the meadow, not darker blades
const DETAIL_CHUNK := 24.0      # ground detail MultiMesh cells (m): each cell is culled on its own

# Water (the guide's saturated blue river).
const WATER_SHALLOW := Color(0.22, 0.54, 0.90)   # close to the deep tone: lighter patches read as ripples, not white clouds
const WATER_DEEP := Color(0.08, 0.34, 0.80)
const WATER_OPEN_FOAM := 0.25  # foam keeps to the banks; open-water patches read as white clouds on the deeper blue

# Light grades, applied when the match starts (never on the menus).
const DAY := {
	"sun_color": Color(1.0, 0.9, 0.74), "sun_energy": 1.45,
	"ambient_energy": 0.22, "ambient_color": Color(0.58, 0.64, 0.86), "ambient_sky": 0.3,
	"saturation": 1.15, "contrast": 1.1, "brightness": 1.0,
	"fog_color": Color(0.96, 0.86, 0.68), "fill_energy": 0.12,
}
# Night readability (visual pass 2026-10-16, claude-faisallaptop): a brighter
# moon and a little more ambient, so units, paths and walls read in the
# Moonlit Wildwood without losing the dark mood (was 0.5 / 0.55 / 0.14).
const NIGHT := {
	"ambient_energy": 0.6, "sun_energy": 0.75, "fill_energy": 0.2,
}
const EMBER := {
	"ambient_energy": 0.34,
}

# Approved 2026-10-25 picks: a single miniature material family.
# Agent: Codex-faisal/world. Faction identity stays green/blue everywhere.
const STONE := Color("d8c49a")
const TIMBER := Color("80532e")
const GOLD := Color("d8aa47")
const ELF_CLOTH := Color("28744a")
const HUMAN_CLOTH := Color("315b9c")
const COOL_SHADOW := Color("27364a")
