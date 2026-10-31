shader_type spatial;
// Flames as an outline around something on fire (Options: Flame outline): a second pass
// after the glowing shell (fire_shell.gdshader), an inverted hull pushed out by noise rising
// in world space, so it licks upward in tongues (longer on top) instead of sitting as an even
// rim. Drawn the way Minionsart's stylized fire is: noise scrolling upward, seen from two
// sides (xy and zy, blended by which way the surface faces), eroded more toward the tongue
// tips, and cut with a soft edge, so the flames have crisp, cartoon shapes, no particles.
// (After flame-outline and stylized-fire shaders Tomek shared; procedural noise and the
// burning palette instead of textures.)
render_mode cull_front, unshaded, world_vertex_coords, depth_draw_never, shadows_disabled;

uniform float intensity = 1.0;
uniform float thickness = 0.05;
uniform float tongue = 0.34; // how far the tongues reach, metres
uniform float speed = 1.0;
uniform float edge_softness = 0.08;
uniform vec4 deep_color : source_color = vec4(0.85, 0.12, 0.02, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.48, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.92, 0.6, 1.0);

varying vec3 wpos;
varying vec3 wnorm;
varying float tip; // 0 at the body, 1 at the end of a tongue

float hash3(vec3 p) {
	uvec3 q = uvec3(ivec3(p));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u ^ q.z * 2654435761u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h ^= h >> 13u;
	return float(h & 16777215u) / 16777216.0;
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// 2D noise for the flame pattern (on a plane: z = 0 of the 3D one), two octaves.
float noise2(vec2 p) {
	return noise3(vec3(p, 0.0)) * 0.65 + noise3(vec3(p * 2.2 + 5.1, 0.0)) * 0.35;
}

void vertex() {
	// (world_vertex_coords: VERTEX and NORMAL are in world space here)
	float t = TIME * speed;
	vec3 q = VERTEX * vec3(3.5, 1.8, 3.5) - vec3(0.0, t * 3.0, 0.0);
	float f = noise3(q) * 0.65 + noise3(q * 2.1 + 5.3) * 0.35;
	// Out from the middle more than along the face: a box's faces would part at its edges
	// (each pushed its own way); this keeps the outline closed round the corners.
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 out_dir = normalize(mix(NORMAL, normalize(VERTEX - centre + NORMAL * 0.001), 0.8));
	float up = clamp(out_dir.y * 0.5 + 0.5, 0.0, 1.0); // the tops lick further
	float reach = f * f * (0.3 + up);
	VERTEX += out_dir * (thickness + tongue * reach) * intensity;
	VERTEX.y += tongue * f * up * 0.9 * intensity; // and lean upward, like flames
	tip = clamp(reach * 1.4 + up * f * 0.5, 0.0, 1.0);
	wpos = VERTEX;
	wnorm = out_dir;
}

void fragment() {
	float t = TIME * speed;
	vec2 pan = vec2(0.2, 1.0) * (-t * 1.4); // scrolling up (and a little sideways)
	float n_xy = noise2(wpos.xy * 2.6 + pan);
	float n_zy = noise2(wpos.zy * 2.6 + pan + vec2(0.7, 0.3));
	float n = mix(n_xy, n_zy, clamp(abs(wnorm.x), 0.0, 1.0));
	// Eroded more toward the tongue tips: pointed flames with crisp edges.
	float erosion = 0.18 + tip * 0.45 + (1.0 - intensity) * 0.6;
	float a = clamp(n - erosion, 0.0, 1.0);
	float body = smoothstep(0.0, edge_softness, a);
	float heat = clamp(a * 2.4 + (1.0 - tip) * 0.35, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, core_color.rgb, smoothstep(0.1, 0.5, heat));
	col = mix(col, tip_color.rgb, smoothstep(0.55, 0.95, heat));
	ALBEDO = col * 1.8;
	ALPHA = body;
}
