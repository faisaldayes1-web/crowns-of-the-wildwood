shader_type spatial;
// Ember Pass lava: slow-drifting dark crust plates floating on molten rock
// that glows through the cracks between them. World-space, so any plane
// (and the falls) lines up seamlessly.
render_mode cull_disabled, specular_disabled;

uniform float drift = 0.035;
uniform float scale = 0.16;
uniform float glow = 1.15;
uniform vec3 hot : source_color = vec3(1.0, 0.72, 0.22);
uniform vec3 warm : source_color = vec3(0.92, 0.26, 0.03);
uniform vec3 crust_lo : source_color = vec3(0.06, 0.025, 0.025);
uniform vec3 crust_hi : source_color = vec3(0.2, 0.07, 0.04);
uniform float flow = 0.0;   // falls: how fast the pattern pours down (v)

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

float cells(vec2 p, float t) {
	// Distance to the nearest crack between two crust plates.
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.38 * sin(t * 0.25 + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale + vec2(TIME * drift, TIME * drift * 0.6);
	if (flow > 0.0) {
		p = vec2(UV.x * 3.0, UV.y * 4.0 - TIME * flow);
	}
	float warp = fbm(p * 1.2 + TIME * 0.02);
	float edge = cells(p + warp * 0.9, TIME);
	float heat = fbm(p * 0.55 - TIME * 0.04);
	// Wide molten channels, crust plates shrinking where it runs hot.
	float molten = 1.0 - smoothstep(0.05, 0.24 - heat * 0.1, edge);
	molten = clamp(molten + smoothstep(0.68, 0.9, heat) * 0.8, 0.0, 1.0);
	if (flow > 0.0) {
		molten = clamp(molten + 0.35, 0.0, 1.0);
	}
	vec3 crust = mix(crust_lo, crust_hi, heat);
	vec3 lava = mix(warm, hot, smoothstep(0.25, 0.9, molten * (0.6 + heat * 0.6)));
	ALBEDO = mix(crust, lava, molten);
	EMISSION = lava * molten * glow;
	ROUGHNESS = 0.95;
}
