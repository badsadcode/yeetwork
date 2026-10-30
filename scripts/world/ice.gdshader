shader_type spatial;
// Ice: clear blue ice that bends what's behind it, with milky frost clouds deep inside
// (sampled at several depths along the view, so they read as inside the block), fine
// fracture planes, tiny trapped bubbles, bright edges and a glossy wet surface. Thick frost
// also blurs the view through it. Breakable ice (destructibles) also draws damage cracks
// from vertex color R, like glass. The Low "simple glass" option uses a plain material.
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.5, 0.76, 1.0, 1.0);
uniform vec4 deep_tint : source_color = vec4(0.08, 0.27, 0.6, 1.0);
uniform float frost = 0.75;
uniform float fractures = 0.6;
uniform float bubbles = 0.7;
uniform float refraction = 0.05;
uniform float roughness_value = 0.05;
// Half size of a box of ice (ArenaBlock): its edges glow. Zero: no edge glow.
uniform vec3 box_half = vec3(0.0);
// Fracture faces of broken ice: frostier.
uniform bool inner = false;
uniform bool use_vertex_damage = false;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 local_pos;
varying float damage;

// Integer hash: exact, no seams between noise cells.
float hash(vec3 p) {
	uvec3 q = uvec3(ivec3(p));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u ^ q.z * 2654435761u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h ^= h >> 13u;
	return float(h & 16777215u) / 16777216.0;
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.13 + 3.1) * 0.3 + noise(p * 4.7 + 7.7) * 0.15;
}

// Distance to the nearest cell wall (F2 - F1) and to the nearest cell point (F1).
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash(i + g + 101.0), hash(i + g + 117.0), hash(i + g + 131.0));
		float d = length(g + o - f);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return vec2(f2 - f1, f1);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
	damage = use_vertex_damage ? COLOR.r : 0.0;
}

const vec3 OFS = vec3(0.371, 0.213, 0.537); // off the integer lattice (no flicker on cell faces)

void fragment() {
	vec3 wp = world_pos + OFS;
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz); // toward the camera
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);
	// Look into the ice: frost clouds, fracture planes and bubbles at a few depths.
	vec3 into = -view_w;
	float fog = 0.0;
	float lines = 0.0;
	float bub = 0.0;
	for (int k = 0; k < 4; k++) {
		float depth = 0.08 + float(k) * 0.22;
		vec3 p = wp + into * depth;
		// Frost: drifts of tiny crystals (grainy, not soft clouds), streaked a little.
		float drift = smoothstep(0.48, 0.74, fbm(p * vec3(1.3, 1.6, 1.3)));
		float grain = noise(p * 16.0) * 0.6 + noise(p * 37.0) * 0.4;
		float cloud = drift * smoothstep(0.25, 0.75, grain) * (1.0 - float(k) * 0.12);
		fog += cloud * (inner ? 0.6 : 0.42);
		// A few long fracture planes, only in places.
		vec2 c = cells(p * 0.45 + 5.0);
		lines += (1.0 - smoothstep(0.0, 0.02, c.x)) * smoothstep(0.6, 0.78, noise(p * 0.5 + 2.0)) * 0.6;
		vec2 b = cells(p * 7.0 + 11.0);
		float r = 0.06 + 0.05 * hash(floor(p * 7.0 + 11.0) + 3.0);
		bub += (smoothstep(r, r - 0.025, b.y) - smoothstep(r - 0.03, r - 0.06, b.y)) * step(0.82, hash(floor(p * 7.0 + 11.0)));
	}
	fog = clamp(fog * frost * 1.4, 0.0, 0.92);
	lines = clamp(lines * fractures, 0.0, 1.0);
	bub = clamp(bub * bubbles, 0.0, 1.0);
	// Damage cracks (breakable ice), bright and white like glass.
	float crack = 0.0;
	if (damage > 0.05) {
		vec2 e = cells(wp * 3.0);
		float width = damage * 0.06;
		float aa = fwidth(e.x);
		crack = (1.0 - smoothstep(width * 0.3 - aa, width + aa, e.x)) * clamp(width / max(aa, 0.0001), 0.0, 1.0);
		fog = max(fog, damage * 0.4);
	}
	// A slightly uneven, melted surface bends the view; frost blurs it.
	vec3 bump = vec3(noise(wp * 1.7) - 0.5, noise(wp * 1.7 + 5.1) - 0.5, noise(wp * 1.7 + 9.3) - 0.5);
	vec3 n = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz * 0.35);
	NORMAL = n;
	float dist = length(VERTEX);
	vec2 ofs = bump.xy * refraction * 2.0 / max(dist * 0.06, 1.0);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + ofs, fog * 4.0).rgb;
	// Light through it: blue, deeper blue the longer the path (grazing views, inner faces).
	float path = mix(1.0, 3.0, 1.0 - ndv) * (inner ? 2.0 : 1.0);
	vec3 transmit = mix(tint.rgb, deep_tint.rgb, clamp(path * 0.25, 0.0, 0.8)) * 0.85;
	// Box edges catch the light.
	float edge = 0.0;
	if (box_half.x > 0.0) {
		vec3 d = box_half - abs(local_pos);
		float m1 = min(d.x, min(d.y, d.z));
		float m2 = max(min(d.x, d.y), max(min(d.y, d.z), min(d.x, d.z)));
		edge = 1.0 - smoothstep(0.0, 0.07, m2); // near two faces at once: an edge
	}
	vec3 frost_col = vec3(0.9, 0.95, 1.0);
	vec3 col = behind * transmit;
	col = mix(col, frost_col * (0.55 + 0.45 * ndv), fog);
	// Glints: a few tiny sparkles on the surface, catching the light as you move.
	float glint = step(0.997, hash(floor(wp * 28.0) + floor(view_w * 6.0) * 13.0)) * (0.4 + 0.6 * (1.0 - ndv));
	col += frost_col * (lines * 0.6 + bub * 0.6 + crack * 0.8 + edge * 0.75 + glint * 1.5);
	col += mix(tint.rgb, vec3(1.0), 0.5) * fres * 0.7;
	ALBEDO = vec3(0.02);
	EMISSION = col;
	ROUGHNESS = mix(roughness_value, 0.45, max(fog * 0.6, crack));
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
