shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
// Forest kit (claude-faisal/crowns-foliage 2026-10-31, picks Battle A /
// Spawn D): one material for every kit tree, bush, rock, flower and fence.
// The colours are baked into the meshes' vertex colours (times the
// MultiMesh instance colour); UV.x says what a vertex is:
//   0 leaves, 1 bark and wood, 2 rock, 3 glowing leaves or blooms, 4 plain,
//   5 pine needles (grade pass 2026-10-31: flat tiers with a fine needle
//   grain, no leaf-scale bumps, so the stepped tiers keep crisp edges).
// Plain Lambert (was wrap): shaded sides read darker, crowns less blobby.
// Leaves get the same small overlapping leaf scales as leaf_soft.gdshader,
// so kit crowns read like the rest of the world's foliage.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float sway : hint_range(0.0, 0.3) = 0.025;
uniform float leaf_scale = 3.0;
uniform float leaf_depth = 0.55;
uniform float rim_strength = 0.3;
uniform float glow_energy = 1.2;
uniform float self_lit = 0.0;    // Twilight: leaves keep a little of their own colour under the magenta dusk light

varying vec3 wpos;
varying vec3 wnorm;
varying float kind;

vec2 leaf_hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

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

void vertex() {
	kind = UV.x;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (kind < 0.5 || (kind > 2.5 && kind < 3.5) || kind > 4.5) {
		float w = sin(TIME * 1.3 + wpos.x * 0.7 + wpos.z * 0.5) * sway * clamp(VERTEX.y * 0.3, 0.0, 1.5);
		VERTEX.x += w;
		VERTEX.z += w * 0.5;
	}
}

void fragment() {
	vec3 col = COLOR.rgb;
	vec3 an = abs(wnorm);
	bool leafy = kind < 0.5 || (kind > 2.5 && kind < 3.5);
	if (leafy) {
		vec2 p = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
		float tuft = texture(noise_tex, p * 0.9).r * 0.65 + texture(noise_tex, p * 2.3 + 0.37).r * 0.35;
		col *= mix(0.8, 1.06, smoothstep(0.38, 0.62, tuft));
		vec2 lp = (an.y > 0.6 ? wpos.xz : vec2(an.x > an.z ? wpos.z : wpos.x, -wpos.y * 1.15)) * leaf_scale;
		vec4 lc = leaf_cells(lp + vec2(tuft * 0.6));
		float lip = clamp(0.5 + lc.w * 1.6, 0.0, 1.0);
		float lv = mix(1.0 - leaf_depth * 0.24, 1.0 + leaf_depth * 0.16, lc.x) * mix(0.9, 1.1, lip);
		lv *= 1.0 + (lc.y - 0.5) * leaf_depth * 0.3;
		col *= lv;
		// Sunlit leaf faces on top of each clump warm up.
		col = mix(col, col * vec3(1.18, 1.14, 0.9), lc.x * lip * clamp(wnorm.y, 0.0, 1.0) * 0.5);
		vec3 ta = an.y > 0.6 ? vec3(1.0, 0.0, 0.0) : (an.x > an.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
		vec3 tb = an.y > 0.6 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, -1.0, 0.0);
		vec3 bend = (ta * lc.z + tb * lc.w) * leaf_depth * 0.7;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bend, 0.0)).xyz);
	} else if (kind > 4.5) {
		// Pine needles: a fine grain down the slope and a soft mottle.
		float m = texture(noise_tex, wpos.xz * 0.6).r;
		float g = texture(noise_tex, vec2((wpos.x - wpos.z) * 3.0, wpos.y * 0.6)).r;
		col *= 0.9 + 0.14 * m + 0.1 * (g - 0.5);
	} else if (kind < 1.5) {
		// Bark and planks: soft vertical grain.
		float g = texture(noise_tex, vec2((wpos.x + wpos.z) * 2.5, wpos.y * 0.35)).r;
		col *= 0.82 + 0.32 * g;
	} else if (kind < 2.5) {
		// Rock: broad blotches and a little grit.
		float b = texture(noise_tex, wpos.xz * 0.45 + wpos.y * 0.3).r;
		float g = texture(noise_tex, (wpos.xz + wpos.y) * 3.1).r;
		col *= 0.8 + 0.3 * b + 0.12 * (g - 0.5);
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col *= 1.0 - rim * rim_strength * (leafy ? 1.0 : 0.5) * (kind > 4.5 ? 0.0 : 1.0);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	if (kind > 2.5 && kind < 3.5) {
		EMISSION = COLOR.rgb * glow_energy * smoothstep(0.55, 0.9, COLOR.a);
	} else if (leafy || kind > 4.5) {
		EMISSION = col * self_lit;
	}
}
