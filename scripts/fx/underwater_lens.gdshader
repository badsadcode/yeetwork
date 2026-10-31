shader_type canvas_item;
// Under water, the finished picture (the 3D view, not the HUD) gently swims: a slow wobble,
// as if seen through moving water, and a soft colour fringe (red and blue pulled apart
// toward the edges of the screen, none in the middle). `amount`: 0 above water, 1 under.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float aspect = 1.78;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	// Wobble: slow crossing ripples, a fraction of a percent of the screen.
	vec2 w = vec2(
		sin(uv.y * 13.0 + t * 1.5) + 0.5 * sin(uv.y * 29.0 - t * 2.2 + uv.x * 7.0),
		sin(uv.x * 11.0 * aspect - t * 1.3) + 0.5 * sin(uv.x * 23.0 + t * 1.9 + uv.y * 6.0)) * 0.0022 * amount;
	// Colour fringe: outward from the middle, growing toward the edges.
	vec2 c = uv - 0.5;
	vec2 cc = vec2(c.x * aspect, c.y);
	vec2 ab = c * (0.003 + 0.016 * dot(cc, cc)) * amount;
	vec2 p = uv + w;
	COLOR = vec4(
		textureLod(screen_tex, p + ab, 0.0).r,
		textureLod(screen_tex, p, 0.0).g,
		textureLod(screen_tex, p - ab, 0.0).b,
		1.0);
}
