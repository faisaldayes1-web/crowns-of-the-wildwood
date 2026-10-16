shader_type spatial;
// The title scene's waterfall: a sheet of water pouring down, with white
// streaks scrolling over a blue body and foam toward the bottom.
render_mode cull_disabled, specular_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.18, 0.55, 0.92, 1.0);
uniform vec4 light : source_color = vec4(0.72, 0.92, 1.0, 1.0);
uniform float speed = 0.9;
uniform vec2 stretch = vec2(2.5, 0.35);

void fragment() {
	vec2 uv = UV * stretch;
	float n1 = texture(noise_tex, vec2(uv.x, uv.y - TIME * speed)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 1.7 + 0.3, uv.y * 1.3 - TIME * speed * 1.4)).r;
	float streak = smoothstep(0.52, 0.72, n1 * 0.6 + n2 * 0.5);
	float foam = smoothstep(0.65, 1.0, UV.y) * 0.8;
	vec3 c = mix(deep.rgb, light.rgb, clamp(streak + foam, 0.0, 1.0));
	ALBEDO = c;
	EMISSION = c * 0.25;
	ROUGHNESS = 0.2;
	// Soft side edges.
	ALPHA = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x) * 0.95;
}
