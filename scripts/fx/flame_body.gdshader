shader_type spatial;
// The big flame wrapping something on fire (Burning): one upright, camera-facing sheet in
// front of the thing, drawn as a soft, gooey cartoon flame: a hull around the thing with
// tongues of fire peeling off it - a tall one in the middle, smaller licks at the sides
// that curl outward and up. Each tongue is a stream of round blobs melted together (a
// smooth union, like metaballs), shrinking as they climb until the tip pinches off as a
// droplet; tongues stretch and shrink, so it flickers and never ends in a sharp point. The middle
// stays see-through where the object is (bright rim, flowing wisp lines over it). Colours
// come from a palette (orange, blue, green...).
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 edge_color : source_color = vec4(1.0, 0.32, 0.04, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.6, 1.0);
uniform float intensity = 1.0;
uniform float energy = 1.4;
// Fraction of the sheet's height the burning object takes up (see-through there; 0 = none).
uniform float hole_top = 0.4;
// How far the sheet sits toward the camera from its anchor (m): in front of the object.
uniform float push = 0.5;
uniform float seed = 0.0;
// Height / width of the sheet (shapes are drawn in width units, so blobs stay round).
uniform float aspect = 1.5;
// Flame columns side by side (a fire place: 1-3), all melted into one mass.
uniform int columns = 1;
// Tongues per column: 5 (a centre one and two licks each side) or 3 on low graphics.
uniform int tongues = 5;
// The burning thing's half-width and height, in sheet half-widths: the base hugs it.
uniform vec2 hull = vec2(0.6, 1.0);
// How round the thing's outline is: 0 = a box (crate), 1 = a ball.
uniform float roundness = 0.35;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// Integer hash of a lattice corner: exact, so neighbouring noise cells always agree (a
// sin()-based hash can give one corner two values and tear the noise into blocks).
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h ^= h >> 13u;
	return float(h & 16777215u) / 16777216.0;
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	// Upright and turned to the camera, then slid toward it (so it draws in front of the
	// burning thing) and shrunk by the same perspective, so on screen it still lines up
	// exactly with the thing's outline.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 anchor = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = cam - anchor;
	vec3 fwd = normalize(vec3(to_cam.x, 0.0, to_cam.z) + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(up, fwd));
	vec3 world = anchor + right * VERTEX.x + up * VERTEX.y;
	float dist = length(to_cam);
	float k = max(dist - push, 0.25) / max(dist, 0.26);
	world = cam + (world - cam) * k;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = world;
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1 + 5.3) * 0.4;
}

// Smooth union: blobs melt into each other instead of meeting at a crease.
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

void fragment() {
	float t = TIME + seed * 31.0;
	float top = 2.0 * aspect; // the sheet's height in width units (width = 2)
	vec2 p = vec2(UV.x * 2.0 - 1.0, (1.0 - UV.y) * top);
	// Lumpy, slowly boiling outline: a gentle low-frequency warp (no spikes).
	// (Low down it stays tight around the burning thing; the tongues above wobble.)
	vec2 warp = vec2(fbm(p * 1.3 + vec2(seed * 4.0, -t * 1.1)), fbm(p * 1.3 + vec2(7.7, -t * 1.3))) - 0.5;
	p += warp * mix(0.05, 0.22, smoothstep(hull.y * 0.7, hull.y * 1.15, p.y));
	float sway_t = t * 1.4 + seed * 6.0;
	// One metaball mass: the base hugging the thing plus every blob of every tongue, melted
	// together (smooth union), so overlapping flames have no borders inside, only the
	// outline of the whole.
	int cols = clamp(columns, 1, 3);
	float spread = cols > 1 ? hull.x * 1.3 / float(cols) : 0.0;
	// The base: a rounded box fitted around the burning thing's outline (square-ish for a
	// crate, round for a ball; a low mound for a fire place).
	vec2 hb = vec2(hull.x + 0.06, hull.y * 0.5 + 0.05);
	float rr = mix(0.12, min(hb.x, hb.y), clamp(roundness, 0.0, 1.0));
	vec2 q = abs(p - vec2(0.0, hull.y * 0.5)) - (hb - rr);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
	float sc = clamp(hull.x / float(cols) / 0.5, 0.45, 1.2); // tongue thickness
	for (int c = 0; c < 3; c++) {
		if (c >= cols) {
			break;
		}
		float cx = (float(c) - float(cols - 1) * 0.5) * spread;
		float cs = seed + float(c) * 0.37;
		// Tongues: 0 = the tall centre one, then licks right/left, inner then outer.
		for (int j = 0; j < 5; j++) {
			if (j >= tongues) {
				break;
			}
			float side = j == 0 ? 0.0 : (j % 2 == 1 ? 1.0 : -1.0);
			float ring = j == 0 ? 0.0 : (j < 3 ? 0.45 : 0.85); // where on the base it peels off
			float js = cs + float(j) * 0.213;
			float hw = cols > 1 ? hull.x / float(cols) : hull.x;
			vec2 start = vec2(cx + side * ring * hw, hull.y * (0.9 - 0.35 * ring * ring));
			float climb = max(top - start.y - 0.18 - 0.1 * sc, 0.1); // stays inside the sheet
			// Each tongue stretches and shrinks on its own rhythm (the flicker).
			float len = (j == 0 ? 1.0 : (j < 3 ? 0.8 : 0.55)) * climb * (0.72 + 0.28 * sin(t * (2.3 + 0.4 * float(j)) + js * 11.0));
			int blobs = j == 0 ? 7 : 5;
			for (int i = 0; i < 7; i++) {
				if (i >= blobs) {
					break;
				}
				float ph = fract(t * 0.95 + float(i) / float(blobs) + js * 0.37);
				float y = start.y + ph * len;
				// The path: out to the side first, then curling back in and up (an S), swaying.
				float curl = side * (0.7 * ph - 0.55 * ph * ph) * sc;
				float sway = sin(ph * 3.2 - sway_t * 1.4 + js * 5.0) * (j == 0 ? 0.2 : 0.1) * ph * sc;
				float x = start.x + curl + sway;
				float r = mix(j == 0 ? 0.4 : 0.26, j == 0 ? 0.11 : 0.08, pow(ph, 1.1)) * sc; // chunky, round tips
				float k = mix(0.26, 0.09, smoothstep(0.5, 1.0, ph)); // near the tip they let go: the droplet pinches off
				d = smin(d, length(p - vec2(x, y)) - r, k);
			}
		}
	}
	// Flamy detail: small rounded licks rising along the outline (low-frequency, so they
	// bulge and roll upward instead of turning into spikes).
	float lick = fbm(vec2(p.x * 3.2 + seed * 5.0, p.y * 2.2 - t * 2.8));
	d += (lick - 0.5) * mix(0.05, 0.14, smoothstep(hull.y * 0.7, hull.y * 1.15, p.y));
	// Never reach the sheet's edges: whatever gets close is rounded off, not cut straight.
	d = -smin(-d, -(abs(p.x) - 0.93), 0.12);
	d = -smin(-d, -(p.y - top + 0.04), 0.12);
	float edge = 0.025;
	float mask = 1.0 - smoothstep(-edge, edge, d);
	if (mask <= 0.002) {
		discard;
	}
	float depth = clamp(-d / 0.34, 0.0, 1.0); // 0 at the outline, 1 inside
	// Like a fresnel metaball: see-through in the middle of the mass, building up to a
	// bright glowing edge, with a thin darker outline just outside it.
	float edge_glow = 1.0 - smoothstep(0.0, 0.85, depth);
	float rim = 1.0 - smoothstep(0.0, 0.18, depth);
	// Flowing wisp lines inside the mass.
	float wn = fbm(vec2(p.x * 2.0 + t * 0.35 + seed * 7.0, p.y * 1.4 - t * 1.4));
	float wisp = 1.0 - smoothstep(0.0, 0.06, abs(wn - 0.5));
	float yy = p.y / top;
	// Over the burning object the middle is clearer still.
	float hole = hole_top > 0.0 ? 1.0 - smoothstep(hole_top * 0.8, hole_top * 1.1, yy) : 0.0;
	float fill = 0.14 + 0.86 * edge_glow * edge_glow + wisp * 0.35;
	fill *= 1.0 - hole * 0.35 * (1.0 - edge_glow);
	// Coating: patches of flame licking up across the burning thing (thicker low down,
	// thinning toward its top), each with a bright edge, so it reads as burning rather than
	// framed by fire.
	float cn = fbm(vec2(p.x * 2.3 + seed * 3.0, p.y * 1.5 - t * 1.7));
	float coat_w = hole * mix(1.0, 0.45, clamp(yy / max(hole_top, 0.01), 0.0, 1.0));
	float coat = smoothstep(0.47, 0.6, cn) * coat_w;
	float coat_edge = (1.0 - smoothstep(0.0, 0.05, abs(cn - 0.5))) * coat_w;
	fill = max(fill, coat * 0.7 + coat_edge * 0.6);
	// Colour: a deep outline, a hot bright band just inside it, the fire's own colour
	// (see-through) toward the middle, and the tips a little deeper.
	float heat = clamp(edge_glow * (1.0 - rim) + wisp * 0.3 + coat_edge * 0.8 + coat * 0.25, 0.0, 1.0);
	vec3 col = mid_color.rgb;
	col = mix(col, hot_color.rgb, smoothstep(0.45, 0.95, heat) * 0.75);
	col = mix(col, edge_color.rgb, rim * 0.75 + smoothstep(0.5, 1.0, yy) * 0.3);
	float a = mask * clamp(fill, 0.0, 1.0) * intensity;
	// Fade where the sheet meets the ground.
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	a *= clamp((-sv.z / sv.w + VERTEX.z) / 0.25, 0.0, 1.0);
	ALBEDO = col * energy * a;
	ALPHA = a * mix(0.75, 0.45, heat);
}
