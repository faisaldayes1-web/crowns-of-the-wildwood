// Frozen tarn ice (claude-faisal/crowns-visual2 2026-11-04, Faisal: "the
// ice circle must look like ice: glossy, cracks, reflections"). Cartoony:
// a deep-blue centre fading to pale frosted edges, a crack web drawn from
// cell edges, a sky-tinted fresnel sheen and a slow moving glint band.
shader_type spatial;
render_mode cull_back;
uniform vec3 deep : source_color = vec3(0.2, 0.46, 0.78);
uniform vec3 pale : source_color = vec3(0.68, 0.85, 0.97);
uniform vec3 crack_col : source_color = vec3(0.95, 0.99, 1.0);
uniform vec3 sky : source_color = vec3(0.78, 0.9, 1.0);
uniform float crack_scale = 0.32;
varying vec3 wpos;
varying vec2 lpos;

vec2 h2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float cell_edge(vec2 p) {
	// distance to the nearest Voronoi edge (F2 - F1)
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h2(i + g);
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX.xz;   // unit disc, scaled per axis by the node
}

void fragment() {
	float r = clamp(length(lpos), 0.0, 1.0);
	vec3 col = mix(deep, pale, smoothstep(0.5, 1.05, r));
	// A few long, wobbly cracks (a warped cell web, most edges dropped) and
	// frost streaks; nothing tile-like.
	vec2 q = wpos.xz * crack_scale;
	q += 0.35 * vec2(sin(q.y * 2.3 + 1.7), cos(q.x * 2.1 + 0.4));
	float e1 = cell_edge(q);
	vec2 cid = floor(q + 0.5);
	float keep = step(0.45, fract(sin(dot(cid, vec2(41.3, 17.9))) * 9137.1));
	float crack = (1.0 - smoothstep(0.012, 0.045, e1)) * keep;
	float e2 = cell_edge(q * 3.1 + 7.0);
	crack += 0.45 * (1.0 - smoothstep(0.008, 0.03, e2)) * smoothstep(0.12, 0.0, e1);   // splinters off the big cracks
	col = mix(col, crack_col, clamp(crack, 0.0, 1.0) * 0.9);
	// Under-ice depth: darker swirls between the cracks.
	col *= 0.9 + 0.1 * smoothstep(0.05, 0.4, e1);
	// Reflections: fresnel towards the sky colour and a slow diagonal glint.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float band = smoothstep(0.9, 1.0, sin((wpos.x + wpos.z) * 0.35 - TIME * 0.6) * 0.5 + 0.5);
	float band2 = smoothstep(0.95, 1.0, sin((wpos.x * 0.6 - wpos.z) * 0.5 + TIME * 0.35) * 0.5 + 0.5);
	// A mirrored sky: the far side of the sheet (away from the camera) picks
	// up the pale sky, the near side the deep water, like a frozen mirror.
	vec3 rv = reflect(-VIEW, NORMAL);
	float skyward = clamp(rv.y * 0.5 + 0.5, 0.0, 1.0);
	col = mix(col, sky, smoothstep(0.6, 0.95, skyward) * 0.2 * (1.0 - clamp(crack, 0.0, 1.0)));
	ALBEDO = col;
	EMISSION = sky * (fres * 0.3 + band * 0.32 + band2 * 0.22) + crack_col * crack * 0.06;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
