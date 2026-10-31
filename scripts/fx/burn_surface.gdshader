shader_type spatial;
// The surface of something on fire (Burning puts it in material_overlay; the "new" fire
// look): the thing chars dark in crisp patches, glowing ember cracks split it (cell borders
// of 3D Voronoi noise, a finer second level in some cells, wobbled by smooth noise so they
// wander), the odd cell glowing as a hot ember, and hard-edged flame licks crawl up its
// faces. Everything comes from world space, so the pattern runs across faces and round
// corners without a seam; the cracks are anti-aliased with fwidth, so they stay sharp but
// don't shimmer.
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

// 3D Voronoi: distances to the nearest and second-nearest cell points, and the nearest
// cell's own random number.
void voronoi(vec3 x, out float f1, out float f2, out float id) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f1 = 8.0;
	f2 = 8.0;
	id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int k = -1; k <= 1; k++) {
				vec3 g = vec3(float(k), float(y), float(z));
				vec3 c = i + g + 512.0; // (positive: the hash takes whole numbers)
				vec3 o = vec3(hash(c), hash(c + vec3(17.0, 31.0, 7.0)), hash(c + vec3(59.0, 11.0, 83.0)));
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < f1) {
					f2 = f1;
					f1 = d;
					id = hash(c + vec3(5.0, 3.0, 1.0));
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	f1 = sqrt(f1);
	f2 = sqrt(f2);
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
	// Ember cracks: the borders between cells, crisp.
	vec3 warp = vec3(noise(wpos * 1.6), noise(wpos * 1.6 + 7.0), noise(wpos * 1.6 + 13.0)) - 0.5;
	vec3 cp = wpos * 2.2 + warp * 0.7;
	float f1;
	float f2;
	float id;
	voronoi(cp, f1, f2, id);
	float e = f2 - f1;
	float cracks = 1.0 - smoothstep(0.05, 0.06 + fwidth(e) * 1.5, e);
	// A finer level of cracks in about half the cells.
	float g1;
	float g2;
	float gid;
	voronoi(cp * 2.4 + 5.0, g1, g2, gid);
	float e2 = g2 - g1;
	float cracks2 = (1.0 - smoothstep(0.035, 0.045 + fwidth(e2) * 1.5, e2)) * step(0.5, id);
	// Each crack cell pulses on its own.
	cracks *= 0.7 + 0.3 * sin(t * 2.4 + id * 40.0);
	cracks2 *= 0.6 + 0.4 * sin(t * 3.1 + gid * 40.0);
	// The odd cell glows right through: a hot ember, brightest in its middle.
	float ember = step(0.87, id) * smoothstep(0.03, 0.25, e) * (0.6 + 0.4 * sin(t * 3.3 + id * 70.0));
	// Hard-edged flame licks crawling up the faces, swaying.
	vec3 q = wpos * vec3(2.2, 1.1, 2.2) - vec3(0.0, t * 2.0, 0.0);
	q.x += sin(wpos.y * 3.0 + t * 2.0) * 0.3;
	float n = noise(q) * 0.65 + noise(q * 2.2 + 4.1) * 0.35;
	float up = clamp(wnorm.y * 0.5 + 0.55, 0.0, 1.0);
	float ln = n * (0.85 + 0.3 * up) + fres * 0.2;
	float licks = smoothstep(0.66, 0.66 + fwidth(ln) * 1.5 + 0.01, ln);
	float glow = clamp(cracks * 1.45 + cracks2 * 0.95 + ember * 0.9 + licks * 0.4 + fres * 0.12, 0.0, 1.6);
	vec3 col = mix(deep_color.rgb, core_color.rgb, smoothstep(0.2, 0.75, glow));
	col = mix(col, tip_color.rgb, smoothstep(0.95, 1.4, glow));
	// Charring in crisp patches: each cell burnt a little darker or lighter
	// (premultiplied: the alpha darkens what's under it).
	float char = 0.68 + 0.2 * hash(vec3(floor(id * 97.0)));
	ALBEDO = col * glow * 1.9 * intensity;
	ALPHA = clamp((char + glow * 0.4) * intensity, 0.0, 0.94);
}
