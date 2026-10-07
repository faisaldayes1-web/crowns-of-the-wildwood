shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
// Cartoon ink lines over the whole view: a full-screen quad parented to each
// camera that darkens pixels where the depth buffer breaks (silhouettes) or
// folds (corners of walls, steps, stones). Works on inverse depth, which is
// linear across any flat surface, so open ground and floors stay clean.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 ink : source_color = vec4(0.09, 0.07, 0.06, 1.0);
uniform float thickness = 1.0;
uniform float threshold = 0.012;   // relative change in inverse depth that starts a line
uniform float softness = 0.03;     // how quickly a line goes from faint to full
uniform float strength = 0.9;
uniform float fade_far = 120.0;    // lines thin out into the distance
uniform float vignette = 0.45;     // a soft storybook darkening at the screen's edges

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float inv_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);   // Forward+ / Mobile depth range is 0..1
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.w / v.z;   // 1 / linear depth
}

void fragment() {
	// About one pixel per 720 lines of screen, so 1080p and 4K keep the weight.
	vec2 px = thickness * max(1.0, floor(VIEWPORT_SIZE.y / 720.0 + 0.5)) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float c = inv_depth(uv, INV_PROJECTION_MATRIX);
	float l = inv_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = inv_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = inv_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float b = inv_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// Strongest on the near side of a break (silhouettes, convex corners),
	// lighter on the far side and in concave folds such as a wall's foot.
	float lap = (l + r + u + b) - 4.0 * c;
	float e = (max(-lap, 0.0) + max(lap, 0.0) * 0.4) / max(c, 1e-5);
	// Silhouettes: this pixel sits clearly in front of a neighbour.
	float back = min(min(l, r), min(u, b));
	e = max(e, (c - back) / max(c, 1e-5) * 0.5);
	float a = smoothstep(threshold, threshold + softness, e);
	float dist = 1.0 / max(c, 1e-5);
	a *= 1.0 - smoothstep(fade_far * 0.6, fade_far, dist);
	// Vignette: the same warm ink, faint, towards the corners.
	vec2 q = (uv - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.3, 0.8, length(q)) * vignette;
	ALBEDO = ink.rgb;
	ALPHA = max(a * strength, v);
}
