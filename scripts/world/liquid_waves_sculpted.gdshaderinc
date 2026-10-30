// "Sculpted" water waves (the alternative to liquid_waves.gdshaderinc, which stays as the
// classic look). Directional Gerstner-style waves with sharpened, forward-leaning crests,
// broad smooth troughs and secondary ripples riding on the swells.
// Liquid.gd mirrors this math on the CPU (_sculpted), so keep them in sync.

uniform float wave_time = 0.0;
uniform float surface_y = 0.0;
uniform float wave_height = 1.0;
uniform float wave_length = 1.0;
uniform float wave_speed = 1.0;
// Waves shorter than this fade out (a coarser mesh can't show them; set per mesh).
uniform float min_wavelength = 0.0;
uniform vec2 fade_center = vec2(0.0);
uniform float fade_inner = 1000000.0;
uniform float fade_outer = 2000000.0;
// Main wave direction (radians) and how widely the waves fan out around it.
uniform float wind_angle = 0.3;
uniform float spread = 1.0;
// Horizontal displacement: pulls water toward the crests (kept below folding).
uniform float choppiness = 1.0;
// > 1: narrow ridges and wide, flat troughs.
uniform float crest_sharpness = 1.7;
// Forward-leaning fronts: steeper on the side the wave travels to.
uniform float asymmetry = 0.35;
// Small secondary waves on top of the swells.
uniform float ripple_intensity = 1.0;
// Quality: how many of the 12 waves to sum.
uniform int wave_count = 12;
// Long ocean swell from far-away storms (oceans only): two long gentle waves the wind sea
// rides on, which big things like ships respond to (Ship). Height 0 = none.
uniform float swell_height = 0.0;
uniform float swell_length = 170.0;
uniform float swell_angle = 1.2;
// Confused sea (storms, after Thornwake's SpectrumWaves): 0 = every wave fans out around
// one wind direction (above). 1 = each wavelength runs in three fixed compass directions
// (120 deg apart, turned by the golden angle from one wavelength to the next), weighted at
// every point by how close they run to the local heading (cos^dir_power, energy kept), so
// wave trains cross at wide angles instead of marching in parallel lines.
uniform float cross_sea = 0.0;
// Directional spread of the confused sea: low = wide (storm), high = narrow.
uniform float dir_power = 1.6;
// The local heading: the wind turned by a slow regional field (radians, over ~1 km).
uniform float heading_vary = 0.0;

// x = direction offset from the wind (times spread), y = wavelength (m),
// z = height / wavelength, w = phase. Waves 7+ are the secondary ripples.
const vec4 SWAVES[12] = {
	vec4(0.0, 31.0, 0.022, 0.0),
	vec4(-0.35, 19.7, 0.02, 1.3),
	vec4(0.5, 13.3, 0.018, 2.1),
	vec4(0.2, 9.1, 0.016, 4.0),
	vec4(-0.8, 6.7, 0.014, 0.7),
	vec4(1.1, 4.9, 0.012, 5.2),
	vec4(-0.15, 3.6, 0.01, 3.3),
	vec4(0.7, 2.7, 0.009, 1.9),
	vec4(-1.3, 2.0, 0.008, 4.6),
	vec4(1.6, 1.5, 0.007, 2.8),
	vec4(0.4, 1.1, 0.006, 0.4),
	vec4(-0.6, 0.8, 0.005, 3.7)
};

float wave_fade(vec2 p) {
	return 1.0 - smoothstep(fade_inner, fade_outer, distance(p, fade_center));
}

// Slow travelling swell groups (0.25..1): waves come in sets.
float wave_group(vec2 p, float i) {
	float a = dot(p, vec2(0.017, 0.011) * (1.0 + 0.29 * i)) + i * 2.3 - wave_time * 0.09;
	float b = dot(p, vec2(-0.009, 0.021)) - i * 1.1 + wave_time * 0.06;
	return 0.625 + 0.375 * sin(a) * sin(b);
}

// Local wave heading at p: the wind turned by a smooth regional field (Liquid._heading()).
float wave_heading(vec2 p) {
	float f = 0.6 * sin(p.x * 0.0061 + 1.7 * sin(p.y * 0.0043 + 0.8)) + 0.4 * sin(p.y * 0.0089 - p.x * 0.0027 + 2.1);
	return wind_angle + heading_vary * f;
}

// Height of the swell at p (two crossing components; Liquid.swell_at() mirrors it).
float swell(vec2 p) {
	if (swell_height <= 0.0) {
		return 0.0;
	}
	float h = 0.0;
	for (int i = 0; i < 2; i++) {
		float ang = swell_angle + (i == 0 ? 0.0 : -1.35);
		float wl = swell_length * (i == 0 ? 1.0 : 0.71);
		float a = swell_height * (i == 0 ? 1.0 : 0.45);
		float k = 6.2831853 / wl;
		float c = sqrt(9.8 / k);
		h += a * sin(k * (dot(vec2(cos(ang), sin(ang)), p) - c * wave_time) + float(i) * 2.1);
	}
	return h * wave_fade(p);
}

// Displacement of the surface point resting at p; crest = 0..1 height within the waves.
// Choppiness goes mostly to the big steep waves (share ~ k^2 A^3, after the storm sea in
// Tom's Thornwake): their crests pinch into sharp knife edges while the small ripples stay
// round; the total stays just below folding.
vec3 sculpted_offset(vec2 p, out float crest) {
	float amp_scale = wave_height * wave_fade(p);
	float amps[36];
	float ks[36];
	float us[36];
	vec2 dirs[36];
	float off_y = 0.0;
	float total = 0.0;
	float share_sum = 0.0;
	bool cross = cross_sea > 0.5;
	int per = cross ? 3 : 1;
	float head = cross ? wave_heading(p) : 0.0;
	for (int n = 0; n < 36; n++) {
		amps[n] = 0.0;
	}
	for (int i = 0; i < 12; i++) {
		if (i >= wave_count) {
			continue;
		}
		vec4 w = SWAVES[i];
		float wl = w.y * wave_length;
		float res = smoothstep(min_wavelength, min_wavelength * 1.5, wl);
		if (res <= 0.0) {
			continue;
		}
		float k = 6.2831853 / wl;
		float c = sqrt(9.8 / k) * wave_speed;
		float a0 = w.z * wl * amp_scale * res * wave_group(p, float(i)) * (i >= 7 ? ripple_intensity : 1.0);
		// Confused sea: this wavelength's three compass directions and their weights.
		float wts[3] = {1.0, 0.0, 0.0};
		float wsum = 1.0;
		if (cross) {
			wsum = 0.0;
			for (int j = 0; j < 3; j++) {
				float cj = cos(float(i) * 2.3999632 + float(j) * 2.0943951 - head);
				wts[j] = cj > 0.0 ? pow(cj, dir_power) : 0.0;
				wsum += wts[j];
			}
		}
		for (int j = 0; j < per; j++) {
			if (wts[j] <= 0.0) {
				continue;
			}
			float ang = cross ? float(i) * 2.3999632 + float(j) * 2.0943951 : wind_angle + w.x * spread;
			vec2 d = vec2(cos(ang), sin(ang));
			float a = a0 * sqrt(wts[j] / max(wsum, 1e-6)); // energy kept whatever the weights
			a = min(a, 0.34 / k); // no wave steeper than it can stand
			float f = k * (dot(d, p) - c * wave_time) + w.w + float(j) * 1.7;
			float u = f + asymmetry * 0.5 * sin(f); // skew: steep front, gentle back
			float s = max(0.5 + 0.5 * sin(u), 1e-5); // pow(0, x) can be NaN on some GPUs
			off_y += a * (2.0 * pow(s, crest_sharpness) - 1.0);
			int n = i * 3 + j;
			amps[n] = a;
			ks[n] = k;
			us[n] = u;
			dirs[n] = d;
			total += a;
			share_sum += k * k * a * a * a;
		}
	}
	// Each wave's share of the chop, and a cap so the sum of k*a*q stays below 1 (no folding).
	vec2 hor = vec2(0.0);
	float pinch = 0.0;
	for (int i = 0; i < 36; i++) {
		if (amps[i] <= 0.0) {
			continue;
		}
		float share = ks[i] * ks[i] * amps[i] * amps[i] * amps[i] / max(share_sum, 1e-9);
		float q = choppiness * mix(1.0, share * float(wave_count), 0.7);
		hor += dirs[i] * amps[i] * q * cos(us[i]);
		pinch += ks[i] * amps[i] * q;
	}
	hor *= min(1.0, 0.96 / max(pinch, 0.0001));
	crest = total > 0.0001 ? clamp(off_y / total * 0.5 + 0.5, 0.0, 1.0) : 0.0;
	return vec3(hor.x, off_y + swell(p), hor.y);
}

// World height of the surface above the world point p.
float surface_height(vec2 p) {
	float c;
	vec3 o = sculpted_offset(p, c);
	o = sculpted_offset(p - o.xz, c);
	return surface_y + o.y;
}
