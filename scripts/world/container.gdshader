shader_type spatial;
// Shipping container (BoxMesh of half_size): corrugated side walls, a darker steel frame
// along the edges, door bars on the -X end, worn paint on the corners. Stylized PBR.

uniform vec4 paint : source_color = vec4(0.1, 0.35, 0.75, 1.0);
uniform vec3 half_size = vec3(6.1, 1.3, 1.22);
uniform float wear = 0.35;

varying vec3 lp;
varying vec3 ln;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 a = abs(lp) / half_size; // 0 at the centre, 1 at each face
	// Frame: within ~12 cm of two faces at once (the box's edges).
	vec3 edge = smoothstep(vec3(1.0) - 0.12 / half_size, vec3(1.0), a);
	float frame = max(max(edge.x * edge.y, edge.y * edge.z), edge.x * edge.z);
	vec3 col = paint.rgb;
	vec3 n = vec3(0.0);
	float rough = 0.55;
	if (abs(ln.z) > 0.5) {
		// Long side walls: vertical corrugation along X.
		float c = sin(lp.x * 6.2831853 / 0.28);
		n.x = cos(lp.x * 6.2831853 / 0.28) * 0.5;
		col *= 0.92 + 0.08 * c;
	} else if (abs(ln.x) > 0.5) {
		// Ends: corrugation along Z, and on -X the doors with locking bars.
		float c = sin(lp.z * 6.2831853 / 0.28);
		n.z = cos(lp.z * 6.2831853 / 0.28) * 0.4;
		col *= 0.93 + 0.07 * c;
		if (ln.x < 0.0) {
			float bars = 0.0;
			for (int i = 0; i < 4; i++) {
				float z = (float(i) - 1.5) * half_size.z * 0.45;
				bars = max(bars, 1.0 - smoothstep(0.025, 0.035, abs(lp.z - z)));
			}
			float seam = 1.0 - smoothstep(0.01, 0.02, abs(lp.z));
			col = mix(col, vec3(0.16, 0.17, 0.2), max(bars * 0.9, seam * 0.7));
		}
	} else {
		col *= 0.95; // roof / floor
	}
	col = mix(col, paint.rgb * 0.55, frame);
	// Wear: scuffed corners and edges show steel, plus faint rust streaks.
	float w = vnoise(lp * 3.1) * 0.6 + vnoise(lp * 9.0) * 0.4;
	float scuff = smoothstep(0.8, 0.92, w + frame * 0.3) * wear;
	col = mix(col, vec3(0.55, 0.56, 0.6), scuff * 0.7);
	float rust = smoothstep(0.7, 0.95, vnoise(vec3(lp.x * 2.0, lp.y * 0.4, lp.z * 2.0))) * wear * (1.0 - a.y);
	col = mix(col, vec3(0.45, 0.22, 0.1), rust * 0.2);
	ALBEDO = col;
	NORMAL_MAP = normalize(vec3(0.5) + vec3(n.x, n.z, 1.0) * 0.5);
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = mix(rough, 0.4, scuff);
	METALLIC = mix(0.15, 0.6, scuff);
	SPECULAR = 0.45;
}
