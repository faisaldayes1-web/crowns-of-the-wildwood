shader_type canvas_item;
// The title's painted background (assets/ui/menu/title_bg.png), brought to
// life: water streaks pour down the waterfalls, the pool shimmers and the
// torch flames flicker. Rects and points are in the image's UV (0..1).

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 falls[4];        // x0, y0, x1, y1 of each waterfall
uniform vec4 pool;            // the water below the bridge
uniform vec2 flames[16];
uniform int flame_count = 0;
uniform float flame_r = 0.012;
uniform float aspect = 1.777;

float waterness(vec3 c) {
	// Blue-white water, not the stone or figures in front of it.
	return smoothstep(0.02, 0.18, c.b - c.r) * smoothstep(0.35, 0.6, c.b);
}

void fragment() {
	vec2 uv = UV;
	vec4 base = texture(TEXTURE, uv);
	vec3 col = base.rgb;
	// Waterfalls: a gentle sideways shimmer and bright streaks scrolling down.
	for (int i = 0; i < 4; i++) {
		vec4 r = falls[i];
		if (uv.x > r.x && uv.x < r.z && uv.y > r.y && uv.y < r.w) {
			vec2 local = (uv - r.xy) / (r.zw - r.xy);
			float edge = smoothstep(0.0, 0.12, local.x) * smoothstep(1.0, 0.88, local.x) * smoothstep(0.0, 0.08, local.y);
			float w = waterness(col) * edge;
			vec2 wob = vec2(sin(local.y * 40.0 - TIME * 9.0) * 0.0006, 0.0);
			vec3 moved = texture(TEXTURE, uv + wob).rgb;
			float n1 = texture(noise_tex, vec2(local.x * 2.2 + float(i) * 0.37, local.y * 0.5 - TIME * 0.9)).r;
			float n2 = texture(noise_tex, vec2(local.x * 3.7 + 0.5, local.y * 0.8 - TIME * 1.4)).r;
			float streak = smoothstep(0.55, 0.8, n1 * 0.6 + n2 * 0.5);
			vec3 fall = mix(moved, vec3(0.9, 0.97, 1.0), streak * 0.55);
			// Foam churns at the foot.
			float foam = smoothstep(0.75, 1.0, local.y) * smoothstep(0.45, 0.75, texture(noise_tex, vec2(local.x * 4.0 + TIME * 0.3, local.y * 2.0 - TIME * 0.6)).r);
			fall = mix(fall, vec3(1.0), foam * 0.4);
			col = mix(col, fall, w);
		}
	}
	// The pool: soft ripples that move the reflections.
	if (uv.x > pool.x && uv.x < pool.z && uv.y > pool.y && uv.y < pool.w) {
		vec2 local = (uv - pool.xy) / (pool.zw - pool.xy);
		float w = waterness(col) * smoothstep(0.0, 0.1, local.y);
		vec2 rip = vec2(texture(noise_tex, vec2(local.x * 3.0 + TIME * 0.05, local.y * 2.0 - TIME * 0.08)).r - 0.5,
			texture(noise_tex, vec2(local.x * 2.0 - TIME * 0.04, local.y * 3.0 + TIME * 0.06)).r - 0.5) * 0.004;
		vec3 moved = texture(TEXTURE, uv + rip).rgb;
		float glint = smoothstep(0.78, 0.9, texture(noise_tex, vec2(local.x * 6.0 + TIME * 0.1, local.y * 5.0 - TIME * 0.12)).r);
		col = mix(col, moved + glint * 0.25, w);
	}
	// Torch flames: the fire licks upward and flickers, with a pulsing glow.
	for (int i = 0; i < 16; i++) {
		if (i >= flame_count) {
			break;
		}
		vec2 d = (uv - flames[i]) * vec2(aspect, 1.0);
		float dist = length(d);
		if (dist < flame_r * 3.0) {
			float seed = float(i) * 1.7;
			float fl = texture(noise_tex, vec2(seed + TIME * 1.3, seed * 0.5 + TIME * 0.9)).r;
			float k = smoothstep(flame_r * 1.4, 0.0, dist);
			vec2 lick = vec2(sin(TIME * 13.0 + uv.y * 900.0 + seed) * 0.0012, (fl - 0.5) * 0.004) * k;
			vec3 fire = texture(TEXTURE, uv + lick).rgb;
			float hot = smoothstep(0.55, 0.8, fire.r) * smoothstep(0.15, 0.45, fire.r - fire.b);
			col = mix(col, fire * (0.85 + fl * 0.5), hot * k);
			float glow = smoothstep(flame_r * 3.0, 0.0, dist) * (0.08 + fl * 0.12);
			col += vec3(1.0, 0.55, 0.18) * glow;
		}
	}
	COLOR = vec4(col, 1.0);
}
