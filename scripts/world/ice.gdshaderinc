// Ice, shared by ice.gdshader (solid: thick ice) and ice_clear.gdshader (#define ICE_CLEAR:
// see-through, for thin ice and small blocks). Grainy frost drifts, long fracture planes and
// trapped bubbles are sampled at several depths along the view, so they sit inside the ice;
// the surface has gentle melted bumps at two scales (the reflections wobble across it);
// boxes have softly rounded, slightly melted edges whose radius wanders. Clear ice tints the
// view through it by how much ice the view crosses (worked out from the box's shape): thin
// ice is nearly clear, a big block goes deep blue. Breakable ice draws damage cracks
// (vertex color R).

uniform vec4 clear_color : source_color = vec4(0.05, 0.2, 0.45, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.16, 1.0);
uniform vec4 frost_color : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.25, 0.6, 1.0, 1.0);
uniform float frost = 0.8;
uniform float fractures = 0.6;
uniform float bubbles = 0.7;
uniform float glow = 0.22;
uniform float roughness_value = 0.03;
// Surface bumps (melted, uneven ice).
uniform float bumpiness = 1.0;
// Half size of a box of ice (ArenaBlock): rounded edges, and the view's path through it.
// Zero: no rounding; the path is Thickness divided by the view angle (slabs).
uniform vec3 box_half = vec3(0.0);
uniform float thickness = 0.3;
uniform float edge_radius = 0.09;
// Clear ice: how fast each colour fades per metre of ice (red first: ice is blue).
uniform vec3 absorption = vec3(1.1, 0.42, 0.15);
uniform float refraction = 0.05;
// Fracture faces of broken ice: frostier.
uniform bool inner = false;
uniform bool use_vertex_damage = false;
// Optional texture maps, wrapped onto every face (triplanar, world space; Map Scale: repeats
// per metre). Clarity map: white = clear, black = cloudy (it also decides how see-through
// clear ice is). Normal map: the surface's bumps (added to the built-in ones).
uniform sampler2D clarity_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_clarity_map = false;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = false;
uniform float normal_strength = 1.0;
uniform float map_scale = 0.5;
// Quality: frost layers looked through (2 low, 4 high); bubbles only on high.
uniform int layers = 4;
uniform bool detail = true;
#ifdef ICE_CLEAR
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
#endif

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

// The melted surface's height: broad swells and finer ripples.
float bumps(vec3 p) {
	return noise(p * 2.2) * 0.65 + noise(p * 6.5 + 4.4) * 0.35;
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
	vec3 into = -view_w;
	// Rounded, melted box edges: the normal of a rounded box whose corner radius wanders
	// along the edges (so they catch the light unevenly, not as a ruled line).
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rounded = 0.0;
	if (box_half.x > 0.0) {
		float r = edge_radius * (0.45 + 1.1 * noise(wp * 2.3)) + 0.02;
		vec3 q = abs(local_pos) - (box_half - r);
		vec3 qp = max(q, vec3(0.0));
		int count = int(q.x > 0.0) + int(q.y > 0.0) + int(q.z > 0.0);
		if (count >= 2 && length(qp) > 0.0001) {
			n_w = normalize((MODEL_MATRIX * vec4(sign(local_pos) * qp / length(qp), 0.0)).xyz);
			rounded = 1.0;
		}
	}
	// Melted bumps: tilt the normal by the height field's slope (along the surface only).
	float e = 0.05;
	float h0 = bumps(wp);
	vec3 grad = vec3(bumps(wp + vec3(e, 0, 0)) - h0, bumps(wp + vec3(0, e, 0)) - h0, bumps(wp + vec3(0, 0, e)) - h0) / e;
	grad -= n_w * dot(grad, n_w);
	vec3 nb = normalize(n_w - grad * 0.06 * bumpiness);
	vec3 tw = pow(abs(n_w), vec3(4.0));
	tw /= tw.x + tw.y + tw.z;
	vec3 mp = wp * map_scale;
	if (use_normal_map) {
		vec2 nx = texture(normal_map, mp.zy).xy * 2.0 - 1.0;
		vec2 ny = texture(normal_map, mp.xz).xy * 2.0 - 1.0;
		vec2 nz = texture(normal_map, mp.xy).xy * 2.0 - 1.0;
		vec3 tilt = tw.x * vec3(0.0, nx.y, nx.x) + tw.y * vec3(ny.x, 0.0, ny.y) + tw.z * vec3(nz.x, nz.y, 0.0);
		nb = normalize(nb + tilt * normal_strength);
	}
	float clarity = 1.0;
	if (use_clarity_map) {
		clarity = texture(clarity_map, mp.zy).r * tw.x + texture(clarity_map, mp.xz).r * tw.y + texture(clarity_map, mp.xy).r * tw.z;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nb, 0.0)).xyz);
	float ndv = clamp(dot(nb, view_w), 0.0, 1.0);
	float fres = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);
	// How much ice the view crosses: through the box (local ray), or across a slab.
	float path;
	if (box_half.x > 0.0) {
		vec3 d = transpose(mat3(MODEL_MATRIX)) * into;
		vec3 t = (sign(d) * box_half - local_pos) / (d + sign(d) * 1e-5 + vec3(1e-6));
		path = clamp(min(t.x, min(t.y, t.z)), 0.0, 30.0);
	} else {
		path = thickness / max(abs(dot(n_w, view_w)), 0.25);
	}

	// Look into the ice: frost drifts, fracture planes and bubbles at a few depths (only as
	// deep as the ice goes).
	float fog = 0.0;
	float lines = 0.0;
	float bub = 0.0;
	float near_frost = 0.0;
	float spacing = min(0.8, path) / float(max(layers, 1));
	for (int k = 0; k < 4; k++) {
		if (k >= layers) {
			break;
		}
		float depth = 0.03 + float(k) * spacing;
		vec3 p = wp + into * depth;
		float drift = smoothstep(0.46, 0.74, fbm(p * vec3(1.3, 1.6, 1.3)));
		float grain = noise(p * 16.0) * 0.6 + noise(p * 37.0) * 0.4;
		float cloud = drift * smoothstep(0.22, 0.75, grain) * (1.0 - float(k) * 0.15);
		fog += cloud * (inner ? 0.55 : 0.38) * 4.0 / float(max(layers, 1));
		if (k == 0) {
			near_frost = cloud;
		}
		if (k % 2 == 0) { // fracture planes on every other layer (they're long and sparse)
			vec2 c = cells(p * 0.45 + 5.0);
			lines += (1.0 - smoothstep(0.0, 0.02, c.x)) * smoothstep(0.6, 0.78, noise(p * 0.5 + 2.0)) * 1.1;
		}
		if (detail && k < 2) {
			vec2 b = cells(p * 7.0 + 11.0);
			float rr = 0.06 + 0.05 * hash(floor(p * 7.0 + 11.0) + 3.0);
			bub += (smoothstep(rr, rr - 0.025, b.y) - smoothstep(rr - 0.03, rr - 0.06, b.y)) * step(0.82, hash(floor(p * 7.0 + 11.0))) * 2.0;
		}
	}
	// Thin ice holds less frost; a clarity map paints where it's cloudy.
	fog = clamp(fog * frost * 1.3 * clamp(path * 1.2, 0.35, 1.0), 0.0, 0.95);
	if (use_clarity_map) {
		fog = clamp(mix(fog * 0.35, 0.95, 1.0 - clarity), 0.0, 0.95);
	}
	lines = clamp(lines * fractures, 0.0, 1.0);
	bub = clamp(bub * bubbles, 0.0, 1.0);
	float crack = 0.0;
	if (damage > 0.05) {
		vec2 ce = cells(wp * 3.0);
		float width = damage * 0.06;
		float aa = fwidth(ce.x);
		crack = (1.0 - smoothstep(width * 0.3 - aa, width + aa, ce.x)) * clamp(width / max(aa, 0.0001), 0.0, 1.0);
		fog = max(fog, damage * 0.4);
	}
	float white = clamp(fog + lines * 0.5 + bub * 0.4 + crack * 0.8, 0.0, 1.0);
	float scatter = glow * (0.15 + 0.85 * fog) * (0.6 + 0.4 * (1.0 - ndv)) + rounded * 0.15;
#ifdef ICE_CLEAR
	// See-through: what's behind, bent by the bumps and blurred by frost, losing its reds
	// and greens the more ice it crosses (Beer-Lambert).
	vec2 ofs = (NORMAL.xy - normalize((VIEW_MATRIX * vec4(n_w, 0.0)).xyz).xy) * refraction * 6.0;
	ofs = clamp(ofs, vec2(-0.03), vec2(0.03));
	vec3 behind = textureLod(screen_tex, SCREEN_UV + ofs, fog * 4.0).rgb;
	vec3 through = behind * exp(-absorption * path);
	// Rounded edges look through a lot of ice at a slant: frosty and bright, not dark.
	white = max(white, rounded * 0.35);
	ALBEDO = frost_color.rgb * white;
	EMISSION = through * (1.0 - white) * (1.0 - fres * 0.6) + glow_color.rgb * scatter * max(white, 0.2)
		+ frost_color.rgb * (bub * 0.25 + crack * 0.3);
#else
	// Solid: deep blue, darker the more ice you look into.
	vec3 ice = mix(clear_color.rgb, deep_color.rgb, clamp((1.0 - ndv) * 0.7 + (inner ? 0.3 : 0.0), 0.0, 1.0));
	ALBEDO = mix(ice, frost_color.rgb, white);
	EMISSION = glow_color.rgb * scatter + frost_color.rgb * (bub * 0.25 + crack * 0.3);
#endif
	// Glossy where clear, matte where the frost reaches the surface.
	ROUGHNESS = mix(roughness_value, 0.55, max(near_frost * 0.8, crack));
	SPECULAR = 0.85;
	METALLIC = 0.0;
}
