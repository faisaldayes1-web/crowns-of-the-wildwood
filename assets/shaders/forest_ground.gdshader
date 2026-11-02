shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert_wrap, specular_disabled;
// Forest kit ground tint (claude-faisal/crowns-foliage 2026-10-31): soft
// see-through patches of lighter, darker and warmer grass (or worn dirt)
// over the meadow, so the ground outside the walls is not one flat green.
// Vertex alpha fades each patch out to its ragged rim; the MultiMesh
// instance colour is its tone (alpha its strength).
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
varying vec3 wpos;

void vertex() {
	// Lifted 3 cm: the patches sat 1-2 cm over the lawn and z-fought it into a stipple at a distance.
	VERTEX.y += 0.03;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.21).r;
	float m = texture(noise_tex, wpos.xz * 0.93 + 0.31).r;
	ALBEDO = COLOR.rgb * (0.9 + 0.2 * m);
	ALPHA = clamp(COLOR.a * (0.45 + 0.9 * n) - 0.1, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
