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

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0); // near plane (reversed Z), covers the screen
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

	float a = max(fog, 0.2);
	if (below < line_w) {
		// Inside the meniscus band.
		col = mix(col, vec3(0.02, 0.06, 0.08), meniscus * 0.8);
		a = max(a * smoothstep(-line_w, 0.0, below), meniscus * 0.7);
		acc *= smoothstep(-line_w, 0.0, below);
	}
	// Premultiplied: fog mixes over the scene, the shafts add light on top.
	ALBEDO = col * a + shaft_color.rgb * acc * (1.0 - fog * 0.5);
	ALPHA = a;
}
