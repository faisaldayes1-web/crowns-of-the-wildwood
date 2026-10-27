extends RefCounted
## Agent: Codex-faisal/characters
## Picked miniature finish: satin armour, matte fabric and soft skin.
## Keep the existing palette textures and player colours authoritative.
## Shared world shadow #27364A anchors the thin silhouette; no extra pass.

const OUTLINE := Color(0.08412, 0.11647, 0.15961)
const OUTLINE_WIDTH := 0.018

# These are actual separate mesh nodes in the shipped character GLBs.
# Bodies mix armour, cloth and skin in one palette, so never metallicize them.
const METAL_PARTS := ["Knight_Helmet", "1H_Sword", "1H_Sword_Offhand", "2H_Sword",
	"Knife", "Knife_Offhand", "1H_Axe", "1H_Axe_Offhand", "2H_Axe"]
const SHIELDS := ["Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield",
	"Barbarian_Round_Shield"]


static func apply(mat: StandardMaterial3D, mesh_name: StringName) -> void:
	# Standard materials remain compatible with hit flashes and store finishes.
	mat.metallic = 0.0
	mat.roughness = 0.88
	mat.rim_enabled = true
	mat.rim = 0.18
	mat.rim_tint = 0.45
	if String(mesh_name) in METAL_PARTS:
		mat.metallic = 0.35
		mat.roughness = 0.43
		mat.rim = 0.25
	elif String(mesh_name) in SHIELDS:
		# Shields also contain painted/wooden faces: a softer satin finish.
		mat.metallic = 0.15
		mat.roughness = 0.58
	elif String(mesh_name).ends_with("_Head"):
		mat.roughness = 0.78
		mat.rim = 0.12

