// Gerstner waves shared by the liquid surface and the underwater pass.
// Liquid.gd mirrors this math on the CPU (buoyancy, waterline, spray), so keep them in sync.

uniform float wave_time = 0.0;
uniform float surface_y = 0.0;
uniform float wave_height = 1.0;
uniform float wave_length = 1.0;
uniform float wave_speed = 1.0;
// Waves shorter than this fade out (a coarser mesh can't show them; set per mesh).
uniform float min_wavelength = 0.0;
// Waves fade out with distance from fade_center (oceans: flat far away, no aliasing).
uniform vec2 fade_center = vec2(0.0);
uniform float fade_inner = 1000000.0;
uniform float fade_outer = 2000000.0;

// x = direction angle, y = wavelength (m), z = steepness. Wavelengths aren't multiples of
// each other and directions spread around the wind, so the pattern never lines up.
const vec3 WAVES[8] = {
	vec3(0.3, 23.0, 0.16),
	vec3(-0.45, 15.3, 0.15),
	vec3(1.05, 10.9, 0.13),
	vec3(0.75, 7.7, 0.12),
	vec3(-1.2, 5.3, 0.1),
	vec3(2.1, 3.9, 0.09),
	vec3(-0.15, 2.7, 0.08),
	vec3(1.6, 1.9, 0.07)
};

float wave_fade(vec2 p) {
	return 1.0 - smoothstep(fade_inner, fade_outer, distance(p, fade_center));
}

// Slow travelling swell groups: each wave grows and shrinks in sets instead of rolling
// in evenly (0.2..1).
float wave_group(vec2 p, float i) {
	float a = dot(p, vec2(0.021, 0.013) * (1.0 + 0.37 * i)) + i * 1.7 - wave_time * 0.11;
	float b = dot(p, vec2(-0.011, 0.024)) - i * 2.3 + wave_time * 0.07;
	return 0.6 + 0.4 * sin(a) * sin(b);
}

// Displacement of the surface point that rests at p. Also returns the normal, a 0..1 crest
// factor (how close to the top of the waves this point is) and the fold: how much the
// surface is squeezed together there (0 = flat, 1 = about to break), which drives foam.
vec3 gerstner(vec2 p, out vec3 n, out float crest, out float fold) {
	float amp_scale = wave_height * wave_fade(p);
	vec3 off = vec3(0.0);
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		float wl = WAVES[i].y * wave_length;
		float res = smoothstep(min_wavelength, min_wavelength * 1.5, wl);
		if (res <= 0.0) {
			continue;
		}
		vec2 d = vec2(cos(WAVES[i].x), sin(WAVES[i].x));
		float k = 6.2831853 / wl;
		float c = sqrt(9.8 / k) * wave_speed;
		float f = k * (dot(d, p) - c * wave_time);
		float q = WAVES[i].z * amp_scale * res * wave_group(p, float(i)); // = amplitude * k
		float a = q / k;
		float sf = sin(f);
		float cf = cos(f);
		off += vec3(d.x * a * cf, a * sf, d.y * a * cf);
		t += vec3(-d.x * d.x * q * sf, d.x * q * cf, -d.x * d.y * q * sf);
		b += vec3(-d.x * d.y * q * sf, d.y * q * cf, -d.y * d.y * q * sf);
		total += a;
	}
	n = normalize(cross(b, t));
	crest = total > 0.0001 ? clamp(off.y / total * 0.5 + 0.5, 0.0, 1.0) : 0.0;
	// Jacobian of the horizontal displacement: < 1 where the waves bunch up.
	float jac = t.x * b.z - t.z * b.x;
	fold = clamp(1.0 - jac, 0.0, 1.0);
	return off;
}

// World height of the surface above the world point p (one fixed-point step undoes the
// horizontal Gerstner shift).
float surface_height(vec2 p) {
	vec3 n;
	float c;
	float f;
	vec3 o = gerstner(p, n, c, f);
	o = gerstner(p - o.xz, n, c, f);
	return surface_y + o.y;
}
