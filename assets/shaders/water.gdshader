shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;
// A stylized river: two drifting layers of noise make ripples and foam,
// a gentle vertex bob, and a soft colour between shallows and depth.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 shallow : source_color = vec4(0.28, 0.62, 0.78, 1.0);
uniform vec4 deep : source_color = vec4(0.06, 0.26, 0.50, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.92;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.8 + wpos.x * 1.7 + wpos.z * 0.9) * 0.025;
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.09 + TIME * vec2(0.020, 0.035)).r;
	float n2 = texture(noise_tex, wpos.xz * 0.06 - TIME * vec2(0.017, 0.012)).r;
	float v = n1 + n2;
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.75, 1.35, v));
	float foam = smoothstep(1.38, 1.5, v);
	col = mix(col, vec3(0.85, 0.95, 1.0), foam * 0.6);
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
	// Ripple normals from the two noise layers.
	NORMAL_MAP = normalize(vec3((n1 - 0.5) * 0.6, (n2 - 0.5) * 0.6, 1.0)) * 0.5 + 0.5;
	EMISSION = vec3(0.1, 0.25, 0.3) * foam;
}
