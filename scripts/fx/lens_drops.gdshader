shader_type canvas_item;
// Water on the camera lens after coming out of the water (techniques after the lens drops
// in Tom's Thornwake): the lens starts soaked and dries over a few seconds.
// * beads: drops of two sizes that sit and evaporate, each at its own moment;
// * runners: bigger drops gather for a moment, break loose and run down in stick-slip
//   jerks, wandering a little sideways, as teardrops whose tail narrows into a trail; they
//   wipe the beads off their path and leave an uneven wet smear with tiny beads that dries;
// * every drop is a small lens: the picture from across its centre (flipped), bent harder
//   toward the rim, dispersed (red bends least, blue most), lit on the upper edge, darker
//   at the lower rim, with a thin dark outline, a small highlight and a faint spectral fringe.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float wet = 0.0; // 1 just surfaced ... 0 dry
uniform float age = 0.0; // seconds since the lens got wet
uniform float aspect = 1.7778;
uniform float seed = 0.0;
uniform float trail_fade = 3.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
float hash1(float n) { return fract(sin(n * 91.345 + 3.17 + seed) * 43758.5453); }

// A round drop as a lens at q (screen heights). Returns (sample offset, coverage, distance
// from the centre in radii).
vec4 lens(vec2 q, vec2 centre, float r) {
	vec2 d = q - centre;
	float dist = length(d) / r;
	float body = 1.0 - smoothstep(0.82, 1.0, dist);
	if (body <= 0.0) {
		return vec4(0.0, 0.0, 0.0, 9.0);
	}
	vec2 n = d / r;
	return vec4(-n * r * (2.2 + 1.6 * dist * dist), body, dist); // a spherical cap
}

// A running drop: round below, drawn out above into a tail narrowing into the trail.
vec4 tear(vec2 q, vec2 centre, float r) {
	vec2 d = q - centre;
	float up = clamp(-d.y / (r * 2.6), 0.0, 1.0);
	float w = r * mix(1.0, 0.22, smoothstep(0.0, 1.0, up));
	float dy = d.y < 0.0 ? d.y / 2.6 : d.y;
	vec2 e = vec2(d.x * r / max(w, 1e-5), dy);
	float dist = length(e) / r;
	float body = 1.0 - smoothstep(0.8, 1.0, dist);
	if (body <= 0.0) {
		return vec4(0.0, 0.0, 0.0, 9.0);
	}
	vec2 n = vec2(d.x / max(w, 1e-5), dy / r);
	return vec4(-n * r * (1.5 + 1.1 * dist * dist), body, dist);
}

vec4 pick(vec4 a, vec4 b) {
	return a.z >= b.z ? a : b;
}

// Beads in cells of `cell` screen heights: each lands at once and evaporates at its own pace.
vec4 beads(vec2 q, float cell, float s, float rate) {
	vec2 c = floor(q / cell);
	vec2 f = q / cell - c;
	if (hash(c + s) > rate) {
		return vec4(0.0, 0.0, 0.0, 9.0);
	}
	float dries = hash(c + s + 4.1) * 0.9; // the wetness at which this one is gone
	float left = clamp((wet - dries) / 0.35, 0.0, 1.0);
	vec2 centre = vec2(0.2 + 0.6 * hash(c + s + 2.3), 0.2 + 0.6 * hash(c + s + 7.7)) * cell;
	float r = cell * (0.16 + 0.22 * hash(c + s + 1.9)) * (0.3 + 0.7 * left) * step(0.01, left);
	return lens(f * cell, centre, max(r, 1e-4));
}

// The runner of lane `col` (lanes `lane` screen heights wide). smear: its wet trail at q.
vec4 runner(vec2 q, float lane, float col, float s, float rate, out float smear) {
	smear = 0.0;
	if (hash1(col * 3.7 + s) > rate) {
		return vec4(0.0, 0.0, 0.0, 9.0);
	}
	float h = hash1(col * 7.1 + s);
	float wait = 0.15 + 0.9 * hash1(col + s * 2.3);  // seconds spent gathering
	float y0 = 0.05 + 0.5 * hash1(col * 5.3 + s);     // where it gathers (from the top)
	float run = max(age - wait, 0.0);
	float travel = 0.22 * pow(run, 1.5);              // speeding up as it goes
	float y = y0 + travel + 0.008 * sin(travel * 60.0 + h * 6.0) * step(0.001, run);
	float cx = (col + 0.5) * lane;
	float wander = lane * 0.24 * (sin(q.y * 9.0 + h * 6.3) * 0.6 + sin(q.y * 23.0 + h * 2.1) * 0.4);
	float wander_at = lane * 0.24 * (sin(y * 9.0 + h * 6.3) * 0.6 + sin(y * 23.0 + h * 2.1) * 0.4);
	float r = lane * (0.15 + 0.1 * h) * mix(0.55, 1.0, clamp(age / max(wait, 0.01), 0.0, 1.0)) * smoothstep(0.0, 0.25, wet + 0.1);
	vec4 drop = run > 0.0 ? tear(q, vec2(cx + wander_at, y), r) : lens(q, vec2(cx + wander_at, y), max(r, 1e-4));
	// The trail: uneven, broken in places, drying unevenly.
	float behind = y - q.y;
	float passed_at = wait + pow(max(q.y - y0, 0.0) / 0.22, 1.0 / 1.5); // when the drop was here
	float since = age - passed_at;
	float n1 = hash1(floor(q.y / (r * 2.5 + 1e-3)) + col * 7.3);
	float n2 = hash1(floor(q.y / (r * 0.9 + 1e-3)) * 1.7 + col);
	float uneven = 0.55 + 0.25 * sin(q.y / max(r, 1e-3) * 1.7 + h * 9.0) + 0.25 * n2;
	float dry_at = trail_fade * (0.35 + 0.9 * n1);
	float fresh = smoothstep(-r * 0.5, r * 1.5, behind) * smoothstep(y0, y0 + r * 4.0, q.y) * smoothstep(-0.02, 0.0, since)
		* (1.0 - smoothstep(dry_at * 0.5, dry_at, since)) * step(0.12, n2 + 0.1);
	float neck = 1.0 - smoothstep(r * 1.5, r * 3.5, behind);
	float tw = max(r, 1e-4) * mix(0.12 * uneven, 0.3, neck) * (0.6 + 0.4 * fresh);
	float dx = q.x - (cx + wander);
	float on_path = exp(-dx * dx / (tw * tw));
	smear = fresh * on_path * 0.5;
	vec4 line = vec4(-dx * 1.8, 0.0, fresh * on_path * 0.6, abs(dx) / (tw * 1.6));
	vec4 trail = vec4(0.0, 0.0, 0.0, 9.0);
	float bcell = max(r, 1e-3) * 1.1;
	float bi = floor(q.y / bcell);
	if (fresh > 0.0 && neck < 1.0 && hash1(bi + col * 13.0) < 0.45) {
		float br = r * (0.12 + 0.14 * hash1(bi * 3.1 + col)) * (0.35 + 0.65 * fresh) * (1.0 - neck);
		vec2 bc = vec2(cx + wander + (hash1(bi + 5.0) - 0.5) * r * 0.3, (bi + 0.5) * bcell);
		trail = lens(q, bc, max(br, 1e-4));
	}
	return pick(pick(drop, line), trail);
}

vec3 spectrum(float a) {
	return clamp(vec3(abs(a * 6.0 - 3.0) - 1.0, 2.0 - abs(a * 6.0 - 2.0), 2.0 - abs(a * 6.0 - 4.0)), 0.0, 1.0);
}

void fragment() {
	if (wet <= 0.001) {
		discard;
	}
	vec2 uv = SCREEN_UV;
	vec2 q = vec2(uv.x * aspect, uv.y);
	float w1;
	float w2;
	vec4 run = pick(runner(q, 0.09, floor(q.x / 0.09), 1.7, 0.6, w1),
		runner(q + vec2(0.045, 0.0), 0.13, floor((q.x + 0.045) / 0.13), 8.3, 0.4, w2));
	float smear = max(w1, w2);
	float wiped = clamp(smear * 1.8, 0.0, 1.0);
	vec4 bead = pick(beads(q, 0.035, 2.9, 0.5 * (1.0 - wiped)), beads(q + vec2(0.017, 0.011), 0.022, 6.1, 0.4 * (1.0 - wiped)));
	vec4 l = pick(run, bead);
	if (l.z <= 0.002 && smear <= 0.002) {
		discard;
	}
	vec3 here = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 smeared = mix(here, textureLod(screen_tex, uv, 1.5).rgb * 1.05, smear);
	vec2 off = l.xy / vec2(aspect, 1.0);
	vec2 ca = vec2(0.001);
	vec2 cb = vec2(0.999);
	float split = 0.05 + 0.1 * smoothstep(0.4, 1.0, l.w);
	vec3 behind = vec3(
		textureLod(screen_tex, clamp(uv + off * (1.0 - split), ca, cb), 0.5).r,
		textureLod(screen_tex, clamp(uv + off, ca, cb), 0.5).g,
		textureLod(screen_tex, clamp(uv + off * (1.0 + split), ca, cb), 0.5).b);
	vec2 nrm = normalize(-l.xy + vec2(1e-5));
	float rim = smoothstep(0.55, 0.92, l.w) * (1.0 - smoothstep(0.92, 1.0, l.w));
	float edge_k = smoothstep(0.35, 0.9, l.w);
	float top_edge = smoothstep(0.4, 1.0, -nrm.y) * 0.08 * edge_k;
	float low_edge = smoothstep(0.4, 1.0, nrm.y) * 0.18 * edge_k;
	vec3 fringe = spectrum(fract(atan(nrm.y, nrm.x) / 6.2832 + 0.15)) * rim * 0.045 * (0.6 + 0.4 * dot(here, vec3(0.33)));
	float outline = smoothstep(0.78, 0.96, l.w) * (1.0 - smoothstep(0.96, 1.0, l.w)) * 0.35;
	vec2 hp = -l.xy / max(length(l.xy), 1e-5) * min(l.w, 1.0);
	float spec = smoothstep(0.22, 0.0, length(hp - vec2(-0.38, -0.42))) * 0.5 * step(l.w, 0.9);
	vec3 drop = behind * (1.0 - low_edge) * (1.0 - outline) + vec3(top_edge + spec) + fringe;
	COLOR = vec4(mix(smeared, drop, l.z), 1.0);
}
