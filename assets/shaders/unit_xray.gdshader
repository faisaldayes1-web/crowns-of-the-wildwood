shader_type spatial;
// Polish pass (claude-faisal/crowns-polish 2026-11-01; reviewers: the gate
// tower and tree crowns hide the local player and the crown carrier). A
// pass chained after the character outline: where the unit is hidden behind
// scenery (the opaque depth is nearer than this fragment) it draws a soft
// flat silhouette in the given colour; where the unit is in plain view it
// draws nothing, so the normal look is unchanged.
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.4, 0.55);

float lin(vec2 uv, float z, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, z, 1.0);
	return -v.z / v.w;
}

void fragment() {
	float scene = lin(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float me = lin(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	// Only scenery at least 1.2 m nearer than the unit counts, so the unit's
	// own hat, hair or shield (self-occlusion) never tints its visible face.
	if (scene > me - 1.2) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * (0.55 + 0.45 * rim);
}
