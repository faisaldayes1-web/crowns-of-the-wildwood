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
// Small leaves (visual pass 2026-10-30, picks Battle A / Spawn D): each tuft
// is covered in overlapping leaf scales ~0.3 m across, every leaf a little
// lit dome with its own shade and a shaded lower lip where it laps over the
// leaf below, so a crown reads as layers of small leaves, not a painted blob.
uniform float leaf_scale = 2.7;  // leaves per metre
uniform float leaf_depth = 0.6;  // 0 = off (the old tufts only)

varying float h;

vec2 leaf_hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Leaf scales on a plane: x = the leaf's dome (1 at its middle, falling
// off smoothly towards its neighbours: no hard seam), y = its own random
// shade, zw = the offset from its centre (cells).
vec4 leaf_cells(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	float best = 9.0;
	vec2 id = vec2(0.0);
	vec2 off = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = leaf_hash(c + g);
			// Leaves hang down the slope: stretched along y.
			vec2 d = (g + 0.15 + o * 0.7 - f) * vec2(1.0, 0.8);
			float dist = dot(d, d);
			if (dist < best) {
				best = dist;
				id = c + g;
				off = -d;
			}
		}
	}
	float dome = 1.0 - smoothstep(0.0, 0.55, sqrt(best));
	return vec4(dome, leaf_hash(id * 1.37).x, off);
}
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
	// Small overlapping leaves over the tufts.
	if (leaf_depth > 0.0) {
		// On the sides the leaves hang (v runs down the crown); on top they lie flat.
		vec2 lp = (an.y > 0.6 ? wpos.xz : vec2(an.x > an.z ? wpos.z : wpos.x, -wpos.y * 1.15)) * leaf_scale;
		vec4 lc = leaf_cells(lp + vec2(tuft * 0.6));
		// Each leaf: lit across its upper face, shaded under its lower lip
		// where it laps the leaf below, and a touch of its own shade.
		float lip = clamp(0.5 + lc.w * 1.6, 0.0, 1.0);
		float leaf_v = mix(1.0 - leaf_depth * 0.22, 1.0 + leaf_depth * 0.18, lc.x) * mix(0.9, 1.1, lip);
		leaf_v *= 1.0 + (lc.y - 0.5) * leaf_depth * 0.25;
		col *= leaf_v;
		// Sunlit leaf faces on the upper crown pick up the warm top colour.
		col = mix(col, top_color.rgb * 1.12, lc.x * lip * clamp(wnorm.y + 0.2, 0.0, 1.0) * t * leaf_depth * 0.6);
		// Each leaf bends the light a little, so the sun picks out its dome.
		vec3 ta = an.y > 0.6 ? vec3(1.0, 0.0, 0.0) : (an.x > an.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
		vec3 tb = an.y > 0.6 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, -1.0, 0.0);
		vec3 bend = (ta * lc.z + tb * lc.w) * leaf_depth * 0.7;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bend, 0.0)).xyz);
	}
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
