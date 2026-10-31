shader_type spatial;
// One tongue of flame (Burning's "new" fire look puts many in one MultiMesh around and over
// whatever burns). A quad that turns to face the camera around its upright axis, its base at
// the bottom edge. Its shape: a flame silhouette (round foot, pointed swaying tip) eaten by
// noise scrolling up, the erosion growing toward the tip and with each tongue's own flicker
// cycle, so tongues lick up, thin out and regrow out of step; cut with a soft edge
// (after Minionsart's stylized fire). Hot yellow core, orange body, red edges, tips going dark
// red-violet like the smoke they turn into.
// INSTANCE_CUSTOM: x seed, y sway, z flicker rate, w heat (1 = a hot middle tongue).
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled;

uniform float intensity = 1.0;
uniform vec4 deep_color : source_color = vec4(0.85, 0.12, 0.02, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.48, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.92, 0.6, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.32, 0.08, 0.22, 1.0);
uniform float edge_softness = 0.22;

varying vec4 custom;

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

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}

void vertex() {
	custom = INSTANCE_CUSTOM;
	// Upright billboard: turn about the vertical axis to face the camera, keep the size.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	// (the quad's foot sits on the instance's origin)
	vec3 world = origin + right * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * (VERTEX.y + 0.5) * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float t = TIME;
	float seed = custom.x * 31.7;
	float v = 1.0 - UV.y; // 0 at the foot, 1 at the tip
	float u = UV.x - 0.5;
	// The tongue sways more toward its tip.
	u += sin(t * (2.0 + custom.z) + seed + v * 3.0) * 0.2 * v * (0.5 + custom.y);
	u += sin(t * 5.3 + seed * 1.7 + v * 7.0) * 0.05 * v; // a quicker flutter on top
	// A flame silhouette: wide round foot, a soft round body narrowing toward the tip.
	float half_w = max(0.48 * pow(max(1.0 - v, 0.0), 0.5) * smoothstep(0.0, 0.22, v + 0.08), 0.002);
	float mask = 1.0 - smoothstep(half_w * 0.5, half_w, abs(u)); // (never zero-wide: no NaN at the tip)
	mask *= 1.0 - smoothstep(0.82, 1.0, v);
	// Noise rising through it; erosion toward the tip and through the flicker cycle.
	float n = fbm(vec2(u * 3.2 + seed, v * 2.2 - t * (2.4 + custom.z * 0.8)));
	float life = fract(t * (0.55 + custom.z * 0.35) + custom.x);
	float erosion = v * 0.55 + life * life * 0.35 + (1.0 - intensity) * 0.8;
	float a = clamp(n * mask * 1.25 - erosion, 0.0, 1.0);
	float body = smoothstep(0.0, edge_softness, a);
	float halo = smoothstep(-0.12, 0.25, n * mask * 1.25 - erosion) * 0.3; // a soft glow round it
	// Colour: mostly orange; yellow only in the hot core low down; red at the edges; the tips
	// turning dark red-violet like smoke.
	float heat = clamp(a * 1.5 + (1.0 - v) * 0.25 * custom.w, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, core_color.rgb, smoothstep(0.08, 0.5, heat));
	col = mix(col, tip_color.rgb, smoothstep(0.62, 1.0, heat));
	col = mix(col, smoke_color.rgb, smoothstep(0.5, 0.95, v) * (1.0 - heat) * 0.85);
	float alpha = max(body, halo) * (0.95 - smoothstep(0.7, 1.0, v) * 0.45);
	ALBEDO = col * alpha * 1.6;
	ALPHA = alpha;
}
