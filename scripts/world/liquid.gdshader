shader_type spatial;
// Stylized liquid surface (water, acid, lava): Gerstner waves, refraction with a touch of
// colour dispersion, depth absorption, caustics on what lies below, shore and crest foam,
// fizzing bubbles and an optional glow. Seen from below it shows a Snell's window.
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

#include "res://scripts/world/liquid_waves.gdshaderinc"

uniform vec4 shallow_color : source_color = vec4(0.12, 0.62, 0.62, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.13, 0.24, 1.0);
// Light scattered inside thin wave crests (the green-teal glow).
uniform vec4 scatter_color : source_color = vec4(0.1, 0.75, 0.55, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy = 0.0;
// Metres of liquid before what lies below fades out (per channel: red goes first).
uniform float clarity = 6.0;
uniform vec3 absorption = vec3(1.7, 1.0, 0.75);
// Metres of depth until the colour is fully "deep".
uniform float depth_fade = 5.0;
uniform float refraction = 0.045;
uniform float dispersion = 0.25;
uniform float roughness_value = 0.035;
uniform float detail_strength = 0.6;
uniform float detail_scale = 1.0;
uniform float foam_amount = 1.0;
uniform float foam_width = 0.7;
uniform float bubbles = 0.0;
uniform float caustics = 1.0;
uniform float scatter_strength = 0.6;

uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;
varying float crest;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n;
	float c;
	vec3 off = gerstner(wp.xz, n, c);
	crest = c;
	VERTEX += off; // liquids are never rotated or scaled, so world offset == local offset
	NORMAL = n;
	world_pos = wp + off;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Animated Voronoi edges: bright wobbly lines like light focused by waves.
float caustic(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.42 * sin(t * 0.9 + 6.2831 * o);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.16, f2 - f1);
}

// View-space position of the opaque scene behind this pixel.
vec3 scene_view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, max(d, 0.000001), 1.0);
	return v.xyz / v.w;
}

void fragment() {
	float t = wave_time;
	vec2 uv1 = world_pos.xz * 0.06 * detail_scale + vec2(t * 0.031, t * 0.017) * wave_speed;
	vec2 uv2 = world_pos.xz * 0.11 * detail_scale - vec2(t * 0.023, -t * 0.029) * wave_speed;
	vec3 nm = (texture(normal_a, uv1).rgb + texture(normal_b, uv2).rgb) * 0.5;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = detail_strength;
	vec2 wobble = (nm.xy - 0.5) * 2.0;

	// How much liquid the view ray crosses before hitting the scene.
	float surf_dist = length(VERTEX);
	vec3 behind = scene_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	float thick = max(length(behind) - surf_dist, 0.0);

	// Refraction: bend the lookup by the surface normal; red/green/blue bend by slightly
	// different amounts (dispersion). Ignore offsets that would sample things in front.
	vec2 ofs = (wobble + NORMAL.xz * 0.6) * refraction * clamp(thick * 0.6, 0.0, 1.0) / max(surf_dist * 0.08, 1.0);
	vec3 behind_r = scene_view_pos(SCREEN_UV + ofs, INV_PROJECTION_MATRIX);
	if (length(behind_r) < surf_dist) {
		ofs = vec2(0.0);
		behind_r = behind;
	}
	float thick_r = max(length(behind_r) - surf_dist, 0.0);
	vec3 refr = vec3(
		textureLod(screen_tex, SCREEN_UV + ofs * (1.0 - dispersion), 0.0).r,
		textureLod(screen_tex, SCREEN_UV + ofs, 0.0).g,
		textureLod(screen_tex, SCREEN_UV + ofs * (1.0 + dispersion), 0.0).b);

	// Depth of the floor below the surface (for colour, foam and caustics).
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(behind_r, 1.0)).xyz;
	float floor_depth = max(world_pos.y - floor_world.y, 0.0);
	float shore_depth = max(world_pos.y - (INV_VIEW_MATRIX * vec4(behind, 1.0)).y, 0.0);
	if (texture(depth_tex, SCREEN_UV).r < 0.000001) {
		floor_depth = 1000.0; // open sky below (oceans): bottomless
		shore_depth = 1000.0;
	}

	float cst = 0.0;
	if (caustics > 0.0 && floor_depth < 30.0) {
		vec2 cp = floor_world.xz * 0.45 + wobble * 0.15;
		cst = caustic(cp, t) * 0.6 + caustic(cp * 1.7 + 3.1, t * 1.3) * 0.4;
		cst *= caustics * exp(-floor_depth * 0.12) * smoothstep(0.0, 0.4, floor_depth);
	}
	vec3 transmit = exp(-thick_r / max(clarity, 0.01) * absorption);
	refr *= transmit * (1.0 + cst * 1.6);

	vec3 body = mix(shallow_color.rgb, deep_color.rgb, 1.0 - exp(-floor_depth / max(depth_fade, 0.01)));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);

	// Foam: where the liquid gets shallow against things, and on the tallest crests.
	float n1 = texture(foam_noise, world_pos.xz * 0.12 + vec2(t * 0.015, 0.0)).r;
	float n2 = texture(foam_noise, world_pos.xz * 0.31 - vec2(0.0, t * 0.02)).r;
	float shore = 1.0 - smoothstep(0.0, foam_width, shore_depth);
	float crest_foam = smoothstep(0.62, 0.98, crest) * wave_height * wave_fade(world_pos.xz);
	float foam = clamp((shore * 1.3 + crest_foam * 1.4) * foam_amount - (1.0 - n1 * n2 * 2.2) * 0.85, 0.0, 1.0);
	if (bubbles > 0.0) {
		float b = texture(foam_noise, world_pos.xz * 0.7 + vec2(0.0, t * 0.13)).r;
		float pop = smoothstep(0.78, 0.84, b) * (0.5 + 0.5 * sin(t * 6.0 + b * 40.0));
		foam = max(foam, pop * bubbles);
	}

	vec3 transmit_avg = vec3((transmit.r + transmit.g + transmit.b) / 3.0);
	if (FRONT_FACING) {
		ALBEDO = body * (1.0 - transmit_avg) * 0.6;
		EMISSION = refr * (1.0 - fres * 0.8);
		// Thin crests let light through: the teal glow near the wave tops.
		EMISSION += scatter_color.rgb * scatter_strength * pow(crest, 3.0) * wave_height * wave_fade(world_pos.xz) * (0.4 + 0.6 * n1);
		ALPHA = clamp(thick * 4.0, 0.0, 1.0);
	} else {
		// From below: a bright window onto the world above, a dim mirror outside it.
		float window = smoothstep(0.55, 0.75, abs(dot(normalize(NORMAL), VIEW)));
		ALBEDO = deep_color.rgb * 0.3;
		EMISSION = mix(deep_color.rgb * 0.5, refr * 1.15 + shallow_color.rgb * 0.15, window);
		ALPHA = 1.0;
		fres = 0.0;
	}
	EMISSION += glow_color.rgb * glow_energy * (0.65 + 0.35 * n1 + cst * 0.3);
	ALBEDO = mix(ALBEDO, foam_color.rgb, foam);
	EMISSION *= 1.0 - foam * 0.85;
	ALPHA = max(ALPHA, foam);
	ROUGHNESS = mix(roughness_value, 0.75, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
