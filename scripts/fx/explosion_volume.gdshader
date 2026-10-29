shader_type spatial;
// Volumetric explosion: ray-marched through 3D cloud noise inside a sphere. A lumpy
// fireball (hot white-yellow core, orange, red edges) cools into a rolling ball of soot as
// `progress` goes 0 -> 1. Drawn on the sphere's back faces, so it also works with the
// camera inside it. Only for Medium/High explosions; Low uses billboard puffs (puff.gdshader).
render_mode unshaded, blend_mix, depth_draw_never, cull_front, shadows_disabled;

uniform sampler3D noise3d : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float progress = 0.0;
uniform int steps = 24;
uniform float seed = 0.0;
// Colour of the fire as it cools: core, flame, edge, then smoke.
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.7, 0.12, 0.04, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.17, 0.15, 0.16, 1.0);
uniform vec3 light_dir = vec3(0.3, 0.9, 0.3);

varying vec3 center_w;
varying float radius_w;

void vertex() {
	center_w = MODEL_MATRIX[3].xyz;
	radius_w = length(MODEL_MATRIX[0].xyz); // the mesh is a unit sphere, scaled
}

float fbm(vec3 p) {
	float n = texture(noise3d, p).r * 0.55;
	n += texture(noise3d, p * 2.03 + 0.37).r * 0.3;
	n += texture(noise3d, p * 4.11 + 0.71).r * 0.15;
	return n;
}

// Density at a point (0 outside the lumpy ball), and how hot it is (0..1).
float density(vec3 p, out float heat) {
	vec3 q = (p - center_w) / radius_w; // unit ball
	float r = length(q);
	float t = progress;
	// Billowing: the noise rolls outward and upward as it ages.
	vec3 np = q * 0.55 + vec3(seed, seed * 1.7, -seed) - vec3(0.0, t * 0.35, 0.0) + normalize(q + 0.0001) * t * 0.15;
	float n = fbm(np);
	float shell = mix(0.55, 0.92, smoothstep(0.0, 0.35, t)); // grows fast, then stays
	float d = (shell - r) + (n - 0.5) * 0.75;
	heat = clamp((1.0 - t * 1.4) * (1.0 - r * 0.9) + (n - 0.5) * 0.6, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.65, 1.0, t);
	return clamp(d * 6.0, 0.0, 1.0) * fade;
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(wpos - cam);
	// Ray-sphere: where the view ray enters and leaves the ball (start at the eye if inside).
	vec3 oc = cam - center_w;
	float b = dot(oc, rd);
	float c = dot(oc, oc) - radius_w * radius_w;
	float h = b * b - c;
	if (h < 0.0) {
		discard;
	}
	h = sqrt(h);
	float t0 = max(-b - h, 0.0);
	float t1 = -b + h;
	// Stop at opaque geometry.
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	t1 = min(t1, length(sv.xyz / sv.w));
	if (t1 <= t0) {
		discard;
	}
	float dt = (t1 - t0) / float(steps);
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	vec3 col = vec3(0.0);
	float trans = 1.0;
	vec3 ld = normalize(light_dir);
	for (int i = 0; i < steps; i++) {
		vec3 p = cam + rd * (t0 + (float(i) + jitter) * dt);
		float heat;
		float dens = density(p, heat);
		if (dens > 0.01) {
			// Cheap self-shadow: one step toward the light.
			float hs;
			float shadow = density(p + ld * radius_w * 0.18, hs);
			vec3 smoke = smoke_color.rgb * (1.25 - shadow * 0.8);
			vec3 fire = mix(edge_color.rgb, flame_color.rgb, smoothstep(0.15, 0.55, heat));
			fire = mix(fire, core_color.rgb, smoothstep(0.6, 0.95, heat)) * (2.0 + heat * 6.0);
			vec3 s = mix(smoke, fire, smoothstep(0.08, 0.4, heat));
			float a = 1.0 - exp(-dens * dt / radius_w * 9.0);
			col += s * a * trans;
			trans *= 1.0 - a;
			if (trans < 0.02) {
				break;
			}
		}
	}
	float alpha = 1.0 - trans;
	if (alpha < 0.005) {
		discard;
	}
	ALBEDO = col / alpha;
	ALPHA = alpha;
}
