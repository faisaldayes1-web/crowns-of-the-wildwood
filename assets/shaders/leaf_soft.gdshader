shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;
// Match-world foliage (visual overhaul 2026-10-14, the style guide's trees):
// the same per-crown gradient and wind as leaf.gdshader, lit with the soft
// wrapped light every other world material gets (leaf.gdshader's two-band
// toon light made crowns read as flat cut-outs beside the stone and timber),
// and broken into leaf tufts: rounded clusters with darker crevices between
// them and sunlit tips, so a crown reads as many small leaves, not a smooth
// blob. leaf.gdshader stays as it was for the menus' title diorama.

uniform vec4 bottom_color : source_color = vec4(0.10, 0.30, 0.12, 1.0);
uniform vec4 top_color : source_color = vec4(0.50, 0.75, 0.30, 1.0);
uniform float height : hint_range(0.1, 10.0) = 2.0;
uniform float sway : hint_range(0.0, 0.3) = 0.06;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform bool world_gradient = false;
uniform float crown_base = 0.0;
uniform float rim_strength = 0.35;
uniform float clump = 0.55;      // depth of the leaf tufts

varying float h;
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	h = world_gradient ? wpos.y - crown_base - height * 0.5 : VERTEX.y;
	float w = sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5) * sway;
	VERTEX.x += w * clamp(h / height + 0.5, 0.0, 1.0);
	VERTEX.z += w * 0.5 * clamp(h / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = clamp(h / height + 0.5, 0.0, 1.0);
	// Broad dapple, as leaf.gdshader.
	float n = texture(noise_tex, wpos.xz * 0.35 + wpos.y * 0.2).r;
	vec3 col = mix(bottom_color.rgb, top_color.rgb, smoothstep(0.0, 1.0, t + (n - 0.5) * 0.45));
	// Leaf tufts (~0.4 m): the noise read along the surface (two planes
	// picked by the normal) and cut into rounded cells.
	vec3 an = abs(wnorm);
	vec2 p = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	float tuft = texture(noise_tex, p * 0.9).r * 0.65 + texture(noise_tex, p * 2.3 + 0.37).r * 0.35;
	float cell = smoothstep(0.38, 0.62, tuft);
	col *= mix(1.0 - clump * 0.45, 1.0 + clump * 0.12, cell);
	// Sunlit tips on the upper face of each tuft.
	float up = clamp(wnorm.y, 0.0, 1.0);
	col = mix(col, top_color.rgb * 1.18, smoothstep(0.62, 0.85, tuft) * up * t * 0.55);
	// A darker rim at the silhouette (kept light: the ink pass draws the edge
	// on Forward+, and the Compatibility renderer still gets a soft outline).
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, bottom_color.rgb * 0.8, rim * rim_strength);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
