shader_type spatial;
// Stylized glass for breakable windows and glass shards: refraction through a slightly
// wavy pane with a touch of colour dispersion, a cool tint that deepens at grazing angles
// and on thick edges, Fresnel reflections (screen-space where possible, the sky
// otherwise), sharp sun glints, and white crack lines that spread with damage.
// The Low "simple glass" option uses a plain transparent material instead (Mats.slab).
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.78, 0.95, 1.0, 1.0);
// How strongly the pane bends what is behind it.
uniform float refraction = 0.04;
uniform float dispersion = 0.35;
// Old-window waviness of the surface.
uniform float waviness = 0.25;
uniform float roughness_value = 0.04;
// Fracture faces of broken glass: thick edges, greener and less clear.
uniform bool inner = false;
// Destructibles: vertex color R carries damage (0..1) and draws cracks.
uniform bool use_vertex_damage = true;
uniform bool reflections = true;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

#include "res://scripts/world/ssr.gdshaderinc"

varying vec3 world_pos;
varying float damage;

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

// Distance to the nearest Voronoi edge (F2 - F1): crack lines.
float crack_edges(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash(i + g), hash(i + g + 17.0), hash(i + g + 31.0));
		float d = length(g + o - f);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return f2 - f1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	damage = use_vertex_damage ? COLOR.r : 0.0;
}

void fragment() {
	// Wavy pane: a gentle world-space bump, so neighbouring panes line up.
	vec3 q = world_pos * 0.7;
	vec2 wob = vec2(value_noise(q) - 0.5, value_noise(q + 7.3) - 0.5) * waviness;
	float crack = 0.0;
	if (damage > 0.05) {
		float mask = smoothstep(0.3, 0.6, value_noise(world_pos * 1.5) + damage * 0.5);
		float e = crack_edges(world_pos * 3.0);
		float width = damage * 0.05 * mask;
		crack = 1.0 - smoothstep(width * 0.3, width, e);
		wob += (vec2(hash(floor(world_pos * 3.0)), hash(floor(world_pos * 3.0) + 3.1)) - 0.5) * damage * 0.6;
	}
	vec3 n = normalize(NORMAL + vec3(wob, 0.0) * 0.25); // meshes have no tangents
	NORMAL = n;
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - ndv, 5.0);

	// Refraction: shift the lookup by the pane's tilt; colours split slightly.
	float dist = length(VERTEX);
	vec2 ofs = wob * refraction * 0.6 / max(dist * 0.08, 1.0);
	if (inner) {
		ofs *= 2.5;
	}
	vec3 behind = vec3(
		textureLod(screen_tex, SCREEN_UV + ofs * (1.0 - dispersion), 0.0).r,
		textureLod(screen_tex, SCREEN_UV + ofs, 0.0).g,
		textureLod(screen_tex, SCREEN_UV + ofs * (1.0 + dispersion), 0.0).b);

	// Light passing through gets the tint, more so at grazing angles (longer path).
	float path = mix(1.0, 2.5, 1.0 - ndv) * (inner ? 3.0 : 1.0);
	vec3 transmit = pow(tint.rgb, vec3(path));

	vec4 refl = vec4(0.0);
	if (reflections && ssr_steps > 0) {
		refl = ssr(VERTEX, n, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, 0.25 + 0.5 * ign(FRAGCOORD.xy));
	}
	float fr = clamp(fres * 1.3 + 0.06, 0.0, 1.0); // a bit shinier than real glass
	vec3 crack_col = vec3(0.92, 0.97, 1.0);
	ALBEDO = mix(tint.rgb * 0.04, crack_col, crack);
	EMISSION = behind * transmit * (1.0 - fr) * (1.0 - crack * 0.7) + refl.rgb * fr * refl.a;
	// The sky reflection (from the engine) only where the screen-space one found nothing.
	SPECULAR = 0.5 * (1.0 - refl.a);
	ROUGHNESS = mix(roughness_value, 0.6, crack);
	METALLIC = 0.0;
	ALPHA = 1.0;
}
