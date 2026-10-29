shader_type sky;
// Stylized space backdrop for "Facing Yeets": soft nebula gradients, twinkly stars and a
// big friendly planet lit by the scene's sun (LIGHT0).

uniform vec3 top_color : source_color = vec3(0.03, 0.03, 0.1);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.09, 0.28);
uniform vec3 nebula_a : source_color = vec3(0.95, 0.35, 0.65);
uniform vec3 nebula_b : source_color = vec3(0.25, 0.55, 1.0);
uniform vec3 planet_dir = vec3(0.55, 0.32, -0.77);
uniform float planet_radius = 0.34;
uniform vec3 ocean_color : source_color = vec3(0.12, 0.38, 0.9);
uniform vec3 land_color : source_color = vec3(0.35, 0.78, 0.42);
uniform vec3 atmosphere_color : source_color = vec3(0.45, 0.75, 1.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.7, abs(d.y)));
	// Nebula clouds.
	float n1 = fbm(d * 2.5 + vec3(3.1, 0.0, 1.7));
	float n2 = fbm(d * 4.0 + vec3(9.0, 4.0, 0.0));
	col += nebula_a * pow(n1, 3.0) * 0.9;
	col += nebula_b * pow(n2, 3.5) * 0.7;
	// Stars.
	vec3 sp = d * 260.0;
	vec3 cell = floor(sp);
	float r = hash(cell);
	if (r > 0.982) {
		vec3 c = cell + 0.5 + (vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1)) - 0.5) * 0.5;
		float dd = length(sp - c);
		float tw = 0.7 + 0.3 * sin(TIME * (2.0 + r * 5.0) + r * 40.0);
		vec3 star_col = mix(vec3(1.0, 0.85, 0.7), vec3(0.75, 0.85, 1.0), hash(cell + 7.0));
		col += star_col * smoothstep(0.32, 0.0, dd) * (r - 0.982) * 140.0 * tw;
	}
	// Sun glare.
	float sdot = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(sdot, 900.0) * 25.0 + pow(sdot, 24.0) * 0.35);
	// Planet.
	vec3 pd = normalize(planet_dir);
	float pc = dot(d, pd);
	float ang = acos(clamp(pc, -1.0, 1.0));
	float x = ang / planet_radius;
	if (x < 1.0) {
		vec3 perp = normalize(d - pd * pc + vec3(1e-5));
		vec3 nrm = normalize(-pd * sqrt(1.0 - x * x) + perp * x);
		float land = smoothstep(0.5, 0.56, fbm(nrm * 3.0 + vec3(TIME * 0.004, 0.0, 0.0)));
		float cloud = smoothstep(0.55, 0.75, fbm(nrm * 5.0 + vec3(0.0, TIME * 0.006, 2.0)));
		vec3 surf = mix(ocean_color, land_color, land);
		surf = mix(surf, vec3(1.0), cloud * 0.8);
		float lambert = clamp((dot(nrm, LIGHT0_DIRECTION) + 0.2) / 1.2, 0.0, 1.0);
		vec3 lit = surf * (0.06 + lambert * 1.3);
		lit += atmosphere_color * pow(x, 5.0) * (0.25 + lambert);
		col = mix(col, lit, smoothstep(1.0, 0.985, x));
	} else if (x < 1.12) {
		float glow = smoothstep(1.12, 1.0, x);
		col += atmosphere_color * glow * glow * 0.6;
	}
	COLOR = col;
}
