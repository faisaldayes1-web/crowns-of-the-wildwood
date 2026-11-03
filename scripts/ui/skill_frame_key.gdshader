// Agent: Codex-faisal/build_delivery. Original owner image, runtime UI matte only.
shader_type canvas_item;
render_mode unshaded;
uniform vec3 background_key = vec3(0.92156862745);
uniform float key_inner = 0.045;
uniform float key_outer = 0.080;
uniform float neutral_inner = 0.015;
uniform float neutral_outer = 0.040;
varying vec4 vertex_modulation;
void vertex() {
	vertex_modulation = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float hi = max(source.r, max(source.g, source.b));
	float lo = min(source.r, min(source.g, source.b));
	float distance_to_key = max(abs(source.r-background_key.r), max(abs(source.g-background_key.g), abs(source.b-background_key.b)));
	float neutral = 1.0-smoothstep(neutral_inner, neutral_outer, hi-lo);
	float matching_background = 1.0-smoothstep(key_inner, key_outer, distance_to_key);
	COLOR = vec4(source.rgb, source.a * (1.0-neutral*matching_background)) * vertex_modulation;
}
