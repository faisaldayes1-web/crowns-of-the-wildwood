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
	// Polish round 3: the farthest of five depth samples (centre and 2 px
	// round it) must still be 1.5 m nearer than the unit, so MSAA-resolved
	// edges, hair and the unit's own parts never leave pale specks.
	vec2 px = 2.0 / VIEWPORT_SIZE;
	float scene = 0.0;
	for (int i = 0; i < 5; i++) {
		vec2 o = i == 0 ? vec2(0.0) : (i == 1 ? vec2(px.x, 0.0) : (i == 2 ? vec2(-px.x, 0.0) : (i == 3 ? vec2(0.0, px.y) : vec2(0.0, -px.y))));
		vec2 uv = SCREEN_UV + o;
		scene = max(scene, lin(uv, texture(depth_tex, uv).r, INV_PROJECTION_MATRIX));
	}
	float me = lin(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	if (scene > me - 1.5) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * (0.55 + 0.45 * rim);
}
