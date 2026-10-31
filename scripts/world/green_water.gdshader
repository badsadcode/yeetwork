shader_type spatial;
// Green water on the deck (ShipWash) and a rogue wave's wall (RogueWave): sea-green water
// churned into foam, the foam in drifting blotches (world-space noise), see-through where it's
// clear, fading out with `fade`.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec4 water : source_color = vec4(0.08, 0.42, 0.46, 1.0);
uniform vec4 foam : source_color = vec4(0.9, 0.96, 1.0, 1.0);
uniform float fade = 1.0;
uniform float clarity = 0.55; // (how see-through the clear water is: 0 opaque)
uniform float flow = 1.0; // which way the foam drifts (along local z)

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 q = wp.xz + wp.yy * 0.5;
	float n = noise(q * 1.1 + vec2(t * 0.9, t * 1.6 * flow)) * 0.6 + noise(q * 3.3 - vec2(t * 1.7, t * 2.3 * flow)) * 0.4;
	float f = smoothstep(0.42, 0.72, n);
	ALBEDO = mix(water.rgb, foam.rgb, f);
	ROUGHNESS = mix(0.06, 0.65, f);
	SPECULAR = 0.6;
	ALPHA = clamp((1.0 - clarity + clarity * f) * fade, 0.0, 1.0);
}
