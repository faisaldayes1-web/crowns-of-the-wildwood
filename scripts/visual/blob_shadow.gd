extends RefCounted
## Soft contact shadows under trees (claude-faisal/crowns-visual2 2026-11-04,
## Faisal: "a slight shadow under trees", the same on all five maps, cheap
## on the GPU). A flat quad with a radial falloff, unshaded, drawn without
## depth writes (so the screen ink ignores it), one MultiMesh per 32 m cell
## (each cell culls on its own) and no sun-shadow casting. The sun's own
## tree shadows still fall where the light says; this is the darker ground
## right under the crown that anchors a tree on Low, where sun shadows are
## short or off, and on every preset alike.

const CHUNK := 32.0
const LIFT := 0.035   # metres over the ground (over the road cores at 0.012-0.02)
const STRENGTH := 0.8

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.04, 0.07, 0.05);
uniform float strength = 0.34;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = 1.0 - smoothstep(0.2, 1.0, d);
	ALBEDO = tint;
	ALPHA = a * a * strength;
}
"""

static var _mat: ShaderMaterial
static var _quad: QuadMesh


static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("strength", STRENGTH)
		# After the screen ink (a full-screen pass at priority 100 that redraws
		# the opaque scene over earlier transparents), like the kit's cover pass.
		_mat.render_priority = 101
	return _mat


static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2.0, 2.0)   # radius 1 before scaling
		_quad.orientation = PlaneMesh.FACE_Y
	return _quad


static func radius_for(mesh: Mesh, xf: Transform3D) -> float:
	## A blob a bit inside the crown's footprint.
	var a: AABB = mesh.get_aabb()
	var s: float = xf.basis.get_scale().x
	return clampf(maxf(a.size.x, a.size.z) * 0.5 * s * 1.45, 0.6, 5.0)


static func build(parent: Node, spots: Array) -> void:
	## spots: [Vector3 ground point, float radius]. One MultiMesh per cell.
	var cells := {}
	for sp in spots:
		var p: Vector3 = sp[0]
		var k := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(sp)
	for k in cells:
		var items: Array = cells[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad()
		mm.instance_count = items.size()
		for i in items.size():
			var p: Vector3 = items[i][0]
			var r: float = items[i][1]
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), p + Vector3(0, LIFT, 0)))
			mm.set_instance_color(i, Color(1, 1, 1, 1))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TreeBlobShadows"
		mmi.multimesh = mm
		mmi.material_override = material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta("no_batch", true)
		parent.add_child(mmi)


static func single(parent: Node3D, radius: float, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	## One blob as a child (trees that are felled and regrow carry their own).
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = quad()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, LIFT, 0)
	mi.scale = Vector3(radius, 1.0, radius)
	mi.set_meta("no_batch", true)
	parent.add_child(mi)
	return mi
