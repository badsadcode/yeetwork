// Gerstner waves shared by the liquid surface and the underwater pass.
// Liquid.gd mirrors this math on the CPU (buoyancy, waterline, spray), so keep them in sync.

uniform float wave_time = 0.0;
uniform float surface_y = 0.0;
uniform float wave_height = 1.0;
uniform float wave_length = 1.0;
uniform float wave_speed = 1.0;
// Waves fade out with distance from fade_center (oceans: flat far away, no aliasing).
uniform vec2 fade_center = vec2(0.0);
uniform float fade_inner = 1000000.0;
uniform float fade_outer = 2000000.0;

// x = direction angle, y = wavelength (m), z = steepness.
const vec3 WAVES[4] = {
	vec3(0.3, 14.0, 0.25),
	vec3(1.4, 8.5, 0.22),
	vec3(-0.8, 5.2, 0.2),
	vec3(2.4, 3.1, 0.15)
};

float wave_fade(vec2 p) {
	return 1.0 - smoothstep(fade_inner, fade_outer, distance(p, fade_center));
}

// Displacement of the surface point that rests at p. Also returns the normal and a
// 0..1 crest factor (how close to the top of the waves this point is).
vec3 gerstner(vec2 p, out vec3 n, out float crest) {
	float amp_scale = wave_height * wave_fade(p);
	vec3 off = vec3(0.0);
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = vec2(cos(WAVES[i].x), sin(WAVES[i].x));
		float k = 6.2831853 / (WAVES[i].y * wave_length);
		float c = sqrt(9.8 / k) * wave_speed;
		float f = k * (dot(d, p) - c * wave_time);
		float q = WAVES[i].z * amp_scale; // = amplitude * k
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
	return off;
}

// World height of the surface above the world point p (one fixed-point step undoes the
// horizontal Gerstner shift).
float surface_height(vec2 p) {
	vec3 n;
	float c;
	vec3 o = gerstner(p, n, c);
	o = gerstner(p - o.xz, n, c);
	return surface_y + o.y;
}
