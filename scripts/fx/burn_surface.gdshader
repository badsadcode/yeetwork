shader_type spatial;
// The surface of something on fire (Burning puts it in material_overlay; the "new" fire
// look): the thing chars dark, glowing ember cracks run through it, and flame licks crawl up
// its faces, hottest at the silhouette. Everything comes from 3D noise in world space, so
// the pattern runs on round corners and across faces without a seam.
// Premultiplied: the body underneath darkens (charring) where the glow doesn't cover it.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_back, shadows_disabled;

uniform float intensity = 1.0;
uniform vec4 deep_color : source_color = vec4(0.85, 0.12, 0.02, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.48, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.92, 0.6, 1.0);

varying vec3 wpos;
varying vec3 wnorm;

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
	VERTEX += NORMAL * 0.004; // (just over the surface)
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = TIME;
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(1.0 - clamp(abs(dot(wnorm, v)), 0.0, 1.0), 2.0);
	// Ember cracks: thin ridges of noise (where it crosses its middle), pulsing.
	vec3 cp = wpos * 3.2 + vec3(0.0, t * 0.05, 0.0);
	float ridge = 1.0 - abs(noise(cp) * 2.0 - 1.0);
	float ridge2 = 1.0 - abs(noise(cp * 2.3 + 11.0) * 2.0 - 1.0);
	float cracks = smoothstep(0.9, 0.98, ridge) + smoothstep(0.93, 0.985, ridge2) * 0.6;
	cracks *= 0.75 + 0.25 * sin(t * 2.4 + noise(wpos * 1.3) * 6.0);
	// Flame licks crawling up the faces: noise stretched upward and rising, swaying.
	vec3 q = wpos * vec3(2.6, 1.3, 2.6) - vec3(0.0, t * 2.2, 0.0);
	q.x += sin(wpos.y * 3.0 + t * 2.0) * 0.3;
	float n = noise(q) * 0.65 + noise(q * 2.2 + 4.1) * 0.35;
	float up = clamp(wnorm.y * 0.5 + 0.55, 0.0, 1.0);
	float licks = smoothstep(0.56, 0.82, n * (0.85 + 0.3 * up) + fres * 0.2);
	float glow = clamp(cracks * 1.3 + licks * 0.7 + fres * 0.3, 0.0, 1.6);
	vec3 col = mix(deep_color.rgb, core_color.rgb, smoothstep(0.2, 0.75, glow));
	col = mix(col, tip_color.rgb, smoothstep(0.95, 1.4, glow));
	// Charring: the body darkens where nothing glows (premultiplied: the alpha darkens it).
	float char = 0.78;
	ALBEDO = col * glow * 1.7 * intensity;
	ALPHA = clamp((char + glow * 0.4) * intensity, 0.0, 0.92);
}
