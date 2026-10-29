shader_type spatial;
// Stylized PBR for arena surfaces: soft triplanar panels, gentle large-scale color
// variation and a warm-top / cool-bottom height gradient. No outlines, no cel bands.

uniform vec4 base_color : source_color = vec4(0.6, 0.6, 0.7, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.7;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float emission_energy = 0.0;
uniform float panel_size = 2.0;
uniform float seam_width = 0.035;
uniform vec3 warm_tint : source_color = vec3(1.06, 0.99, 0.92);
uniform vec3 cool_tint : source_color = vec3(0.9, 0.95, 1.06);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float panel(vec2 uv) {
	vec2 f = abs(fract(uv / panel_size) - 0.5);
	float edge = max(f.x, f.y);
	// 1 inside the panel, softly darkening toward the seam.
	return smoothstep(0.5, 0.5 - seam_width, edge) * 0.7 + smoothstep(0.5, 0.2, edge) * 0.3;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float p = panel(world_pos.zy) * w.x + panel(world_pos.xz) * w.y + panel(world_pos.xy) * w.z;
	float n = value_noise(world_pos * 0.18) * 0.6 + value_noise(world_pos * 0.9) * 0.4;
	float h = clamp((world_pos.y + 4.0) / 26.0, 0.0, 1.0);
	vec3 grad = mix(cool_tint, warm_tint, smoothstep(0.0, 1.0, h));
	vec3 col = base_color.rgb * grad * (0.9 + 0.1 * p) * (0.95 + 0.1 * n);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_value + (n - 0.5) * 0.12 - p * 0.05, 0.05, 1.0);
	METALLIC = metallic_value;
	SPECULAR = 0.45;
	EMISSION = base_color.rgb * emission_energy;
}
