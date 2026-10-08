shader_type spatial;
// Ember Pass lava: thick, nearly black crust plates drifting on deep red
// molten rock. Only the cracks between the plates burn, hottest (orange to
// yellow-white) in their thin cores, the crust's edges glowing ember red and
// bevelled so the plates read as solid slabs. The whole sea breathes with a
// slow pulse, like something alive underneath. World-space, so any plane
// (and the falls) lines up seamlessly.
render_mode cull_disabled, fog_disabled;   // no red haze over the black crust

uniform float drift = 0.03;
uniform float scale = 0.16;
uniform float glow = 3.2;
uniform vec3 core : source_color = vec3(1.0, 0.78, 0.32);      // the hottest crack cores
uniform vec3 hot : source_color = vec3(1.0, 0.34, 0.04);      // molten rock
uniform vec3 deep : source_color = vec3(0.45, 0.04, 0.015);    // cooling, deep red
uniform vec3 crust_lo : source_color = vec3(0.008, 0.006, 0.007);   // near black
uniform vec3 crust_hi : source_color = vec3(0.06, 0.03, 0.028);
uniform float flow = 0.0;   // falls: how fast the pattern pours down (v)
uniform float pulse = 0.18; // how much the glow breathes

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 cells(vec2 p, float t) {
	// x: distance to the nearest crack between two crust plates;
	// y: a random id for the plate we are on; z: distance to its centre.
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.36 * sin(t * 0.2 + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d2) - sqrt(d1), hash(id), sqrt(d1));
}

float field(vec2 p, out float edge, out float plate, out float heat) {
	float warp = fbm(p * 1.1 + TIME * 0.015);
	vec3 c = cells(p + warp * 0.8, TIME);
	edge = c.x;
	plate = c.y;
	heat = fbm(p * 0.5 - TIME * 0.03);
	// Crust height: flat-topped slabs that slope down into the cracks.
	return smoothstep(0.02, 0.22, edge) * (0.85 + 0.15 * fbm(p * 3.0));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale + vec2(TIME * drift, TIME * drift * 0.6);
	if (flow > 0.0) {
		p = vec2(UV.x * 3.0, UV.y * 4.0 - TIME * flow);
	}
	float edge;
	float plate;
	float heat;
	float h = field(p, edge, plate, heat);
	// Bevel the slabs: a normal from the crust height's slope.
	vec2 dh = vec2(dFdx(h), dFdy(h));
	vec3 n_view = normalize(NORMAL + (TANGENT * -dh.x + BINORMAL * dh.y) * 6.0);

	// Molten where the crust is missing: thin cracks, wider where it runs hot.
	// Wide open pools where it runs hot (the 2026-10-08 reference: bright
	// molten rivers with black crust islands), thin cracks elsewhere.
	float open = smoothstep(0.52, 0.88, heat) * 0.85;
	float molten = 1.0 - smoothstep(0.02, 0.13 + heat * 0.1, edge);
	molten = clamp(max(molten, open * (1.0 - h * 0.6)), 0.0, 1.0);
	if (flow > 0.0) {
		molten = clamp(molten + 0.3, 0.0, 1.0);
	}
	// A slow breath through the whole sea, offset across it so it rolls.
	float breath = 1.0 + pulse * sin(TIME * 1.3 + wpos.x * 0.05 + wpos.z * 0.03);

	// Crust: near black, a few plates faintly rusty.
	vec3 crust = mix(crust_lo, crust_hi, plate * 0.7 + fbm(p * 4.0) * 0.3);
	vec3 lava = mix(deep, hot, smoothstep(0.1, 0.7, molten * (0.5 + heat)));
	lava = mix(lava, core, smoothstep(0.75, 1.0, molten) * smoothstep(0.35, 0.8, heat));
	// Glow falls off steeply from the crack, so the crust around it stays black.
	float burn = molten * molten;
	ALBEDO = mix(crust, lava * 0.7, burn);
	// Only a thin ember line right at the crack's lip; the plates stay black.
	float lip = 1.0 - smoothstep(0.02, 0.08, edge);
	vec3 ember = deep * lip * 0.7 * (1.0 - molten);
	EMISSION = (lava * burn * glow + ember) * breath;
	NORMAL = mix(n_view, NORMAL, burn);
	ROUGHNESS = mix(0.7, 0.95, molten);
	SPECULAR = 0.12 * (1.0 - molten);
}
