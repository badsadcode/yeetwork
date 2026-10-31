shader_type canvas_item;
// Screen effects for the power-ups, layered (each 0..1, fading in and out):
// speed: thin blue streaks rushing out from the middle; super: a pulsing orange edge glow;
// feather: a soft cyan haze; iron: a cool metallic rim with a sheen sliding across.

uniform float speed = 0.0;
uniform float super_yeet = 0.0;
uniform float feather = 0.0;
uniform float iron = 0.0;

void fragment() {
	vec2 c = UV - 0.5;
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // round, whatever the screen's shape
	float r = length(c);
	float edge = smoothstep(0.32, 0.85, r);
	vec4 acc = vec4(0.0); // rgb weighted by alpha, alpha summed

	float ang = atan(c.y, c.x);
	float lines = pow(max(0.0, sin(ang * 70.0 + sin(ang * 11.0) * 4.0)), 24.0);
	float rush = fract(r * 2.5 - TIME * 2.2);
	float s = lines * smoothstep(0.22, 0.75, r) * (0.35 + 0.65 * rush) * speed;
	acc += vec4(vec3(0.7, 0.88, 1.0), 1.0) * s * 0.7;
	acc += vec4(vec3(0.3, 0.6, 1.0), 1.0) * edge * speed * 0.22;

	float pulse = 0.65 + 0.35 * sin(TIME * 6.0);
	acc += vec4(vec3(1.0, 0.5, 0.1), 1.0) * edge * super_yeet * 0.5 * pulse;

	float drift = 0.5 + 0.5 * sin(UV.y * 9.0 + TIME * 1.3 + sin(UV.x * 7.0 - TIME) * 1.5);
	acc += vec4(vec3(0.6, 1.0, 0.95), 1.0) * (0.07 + edge * (0.3 + drift * 0.15)) * feather;

	float sheen = smoothstep(0.85, 1.0, sin((UV.x + UV.y) * 5.0 - TIME * 1.8));
	acc += vec4(vec3(0.62, 0.68, 0.8), 1.0) * smoothstep(0.42, 0.8, r) * iron * (0.5 + sheen * 0.4);

	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), clamp(acc.a, 0.0, 0.75));
}
