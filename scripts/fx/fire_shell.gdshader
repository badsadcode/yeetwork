shader_type spatial;
// The glowing shell around something on fire (Burning puts it in material_overlay): a
// fresnel rim that glows hot at the silhouette, with flames licking up the body as noise
// rising in world space, and a slight bulge outwards. Premultiplied: the body underneath
// darkens and takes on the fire's colour while the rim and the flames glow, like a ghost's aura.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_back, shadows_disabled;

uniform float intensity = 1.0;
uniform float grow = 0.03;
uniform vec4 deep_color : source_color = vec4(0.85, 0.12, 0.02, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.48, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.92, 0.6, 1.0);

varying vec3 wpos;
varying vec3 wnorm;

// Integer hash of a lattice corner (exact: no seams between noise cells).
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

void vertex() {
	VERTEX += NORMAL * grow * intensity;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(1.0 - clamp(abs(dot(normalize(wnorm), v)), 0.0, 1.0), 2.2);
	// Flames: noise stretched upward and rising, warped sideways so tongues sway.
	float t = TIME;
	vec3 q = wpos * vec3(3.2, 1.6, 3.2) - vec3(0.0, t * 2.6, 0.0);
	q.x += sin(wpos.y * 4.0 + t * 3.0) * 0.25;
	float n = noise(q) * 0.65 + noise(q * 2.3 + 7.1) * 0.35;
	float up = clamp(wnorm.y * 0.5 + 0.6, 0.0, 1.0); // tops burn brighter than undersides
	float flame = smoothstep(0.5, 0.9, n * (0.8 + 0.4 * up) + fres * 0.3);
	// Flowing wisp lines over the body (the thing stays visible between them).
	float wisp = 1.0 - smoothstep(0.0, 0.07, abs(noise(q * 0.8 + 3.7) - 0.5));
	float glow = clamp(fres * 0.9 + wisp * 0.75 + flame * 0.45, 0.0, 1.4);
	vec3 col = mix(deep_color.rgb, core_color.rgb, smoothstep(0.15, 0.65, glow));
	col = mix(col, tip_color.rgb, smoothstep(0.85, 1.25, glow));
	ALBEDO = col * glow * intensity * 1.8;
	ALPHA = clamp((0.22 + glow * 0.5) * intensity, 0.0, 1.0);
}
