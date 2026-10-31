// Body of the underwater pass, shared by underwater.gdshader (classic waves) and
// underwater_sculpted.gdshader. Include it after a waves include that defines surface_height().

uniform vec4 fog_color : source_color = vec4(0.03, 0.27, 0.33, 1.0);
uniform vec4 shaft_color : source_color = vec4(0.55, 0.95, 0.9, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Metres until the world disappears into the fog.
uniform float visibility = 14.0;
uniform float shafts = 1.0;
// Direction toward the sun (world space), and how many samples the shafts take per pixel.
uniform vec3 sun_dir = vec3(0.35, 0.8, 0.45);
uniform int shaft_steps = 10;
uniform sampler2D shaft_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// How strongly the waving surface focuses sunlight into dancing lines on things below.
uniform float caustics = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0); // near plane (reversed Z), covers the screen
}

vec2 uw_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Animated Voronoi edges: bright wobbly lines like light focused by waves (the same pattern
// the surface shader lays on the floor seen from above).
float uw_caustic(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = uw_hash2(i + g);
			o = 0.5 + 0.42 * sin(t * 0.9 + 6.2831 * o);
			float dd = length(g + o - f);
			if (dd < f1) {
				f2 = f1;
				f1 = dd;
			} else if (dd < f2) {
				f2 = dd;
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.16, f2 - f1);
}

// Interleaved gradient noise: per-pixel jitter that hides the banding of few shaft samples.
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec4 nv = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	nv.xyz /= nv.w;
	vec3 near_world = (INV_VIEW_MATRIX * vec4(nv.xyz, 1.0)).xyz;
	float h = surface_height(near_world.xz);
	float below = h - near_world.y; // > 0: this pixel looks out from under the surface

	// Meniscus: a thin dark band where the surface crosses the lens.
	float line_w = 0.012;
	float meniscus = 1.0 - smoothstep(0.0, line_w, abs(below));
	if (below < -line_w) {
		discard;
	}

	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = normalize(near_world - cam);
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(ndc, max(d, 0.000001), 1.0);
	sv.xyz /= sv.w;
	float dist = d < 0.000001 ? 10000.0 : length(sv.xyz);
	float to_surface = dir.y > 0.001 ? max(below, 0.0) / dir.y : 10000.0;
	float water = min(dist, to_surface);
	float fog = 1.0 - exp(-water / max(visibility, 0.1));

	// Fog colour: darker the deeper you are, brighter looking up toward the light.
	float depth_here = max(below, 0.0);
	vec3 col = fog_color.rgb * exp(-depth_here * 0.045) * (1.0 + max(dir.y, 0.0) * 0.7);
	col += glow_color.rgb * 0.15;

	// Light shafts: march the view ray. Light reaching each sample came down along the sun
	// direction through the waving surface, which focuses it into drifting bright patches.
	vec3 sd = normalize(vec3(sun_dir.x, max(sun_dir.y, 0.25), sun_dir.z));
	float march = min(water, visibility * 0.9);
	float jitter = ign(FRAGCOORD.xy);
	float acc = 0.0;
	for (int i = 0; i < shaft_steps; i++) {
		float s = (float(i) + jitter) / float(shaft_steps);
		float tt = s * s * march; // more samples close by
		vec3 p = near_world + dir * tt;
		float dep = max(surface_y - p.y, 0.0);
		vec2 q = p.xz + sd.xz / sd.y * dep;
		// Bright cells of the cellular noise (mean ~0.3) become beams, a second layer
		// makes them flicker.
		float pat = texture(shaft_noise, q * 0.028 + vec2(wave_time * 0.004, 0.0)).r;
		pat *= 0.55 + 0.9 * texture(shaft_noise, q * 0.047 - vec2(0.0, wave_time * 0.005)).r;
		acc += smoothstep(0.28, 0.6, pat) * exp(-dep * 0.05 - tt / visibility);
	}
	acc *= shafts * 1.6 / float(shaft_steps);

	// Caustics on whatever the view ray hits under water: strongest on floors facing up,
	// fading with depth and into the fog.
	float caust = 0.0;
	if (caustics > 0.0 && d >= 0.000001 && dist < to_surface) {
		vec3 hit = (INV_VIEW_MATRIX * vec4(sv.xyz, 1.0)).xyz;
		float hdep = surface_y - hit.y;
		if (hdep > 0.0) {
			vec3 hn = normalize(cross(dFdx(hit), dFdy(hit)));
			float up = mix(0.3, 1.0, smoothstep(0.3, 0.85, abs(hn.y)));
			vec2 cq = (hit.xz + sd.xz / sd.y * hdep) * 0.42;
			caust = uw_caustic(cq, wave_time) * 0.6 + uw_caustic(cq * 1.6 + 3.1, wave_time * 1.3) * 0.4;
			caust *= caustics * up * exp(-hdep * 0.1) * smoothstep(0.0, 0.4, hdep) * (1.0 - fog);
		}
	}

	float a = max(fog, 0.2);
	if (below < line_w) {
		// Inside the meniscus band.
		col = mix(col, vec3(0.02, 0.06, 0.08), meniscus * 0.8);
		a = max(a * smoothstep(-line_w, 0.0, below), meniscus * 0.7);
		acc *= smoothstep(-line_w, 0.0, below);
		caust *= smoothstep(-line_w, 0.0, below);
	}
	// Premultiplied: fog mixes over the scene, the shafts add light on top.
	ALBEDO = col * a + shaft_color.rgb * (acc * (1.0 - fog * 0.5) + caust * 0.45);
	ALPHA = a;
}
