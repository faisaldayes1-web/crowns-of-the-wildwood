shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;
// Stylized foliage: dark at the bottom, light at the sunlit top, dappled
// with noise, with a slow wind sway. Colours are per tree.

uniform vec4 bottom_color : source_color = vec4(0.10, 0.30, 0.12, 1.0);
uniform vec4 top_color : source_color = vec4(0.50, 0.75, 0.30, 1.0);
uniform float height : hint_range(0.1, 10.0) = 2.0;
uniform float sway : hint_range(0.0, 0.3) = 0.06;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying float h;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = VERTEX.y;
	float w = sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5) * sway;
	VERTEX.x += w * clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	VERTEX.z += w * 0.5 * clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = clamp(h / height + 0.5, 0.0, 1.0);
	float n = texture(noise_tex, wpos.xz * 0.35 + wpos.y * 0.2).r;
	vec3 col = mix(bottom_color.rgb, top_color.rgb, smoothstep(0.0, 1.0, t + (n - 0.5) * 0.5));
	// Leaf clumps: a finer noise breaks the gradient into painted tufts.
	float n2 = texture(noise_tex, wpos.xz * 1.4 + wpos.y * 0.9).r;
	col *= 0.86 + 0.3 * smoothstep(0.35, 0.7, n2);
	// Sunlit crown and a darker rim at the silhouette for a cut-out look.
	col = mix(col, top_color.rgb * 1.25, smoothstep(0.78, 1.0, t) * 0.45);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, bottom_color.rgb * 0.75, rim * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
