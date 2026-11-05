shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// The character outline: an inflated back-face hull. It grows along the
// smoothed direction stored in TANGENT (character_model._smooth_outline_dirs),
// not the faceted normal, so the hull stays one piece across hard edges.

uniform vec4 color : source_color = vec4(0.084, 0.116, 0.16, 1.0);
uniform float width = 0.018;

void vertex() {
	VERTEX += normalize(TANGENT) * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
