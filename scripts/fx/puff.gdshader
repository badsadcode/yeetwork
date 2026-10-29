shader_type spatial;
// Cauliflower puffs for dust, smoke, mist and fireballs (CPUParticles3D with a QuadMesh):
// each particle is a cluster of 5-7 round lobes, every lobe shaded like a little sphere
// (warm lit tops, cool shadowed undersides), so clouds read dense and billowy in the
// stylized Pixar way. The particle's colour ramp (COLOR) colours it over its life; lobes
// shrink and part as it ages; it fades softly where it meets geometry.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Shadow side tint (multiplied in): cool shadows, warm light.
uniform vec4 shade_color : source_color = vec4(0.6, 0.64, 0.82, 1.0);
// Fireballs: a hot glowing core early in life (0 = plain dust/smoke).
uniform float heat = 0.0;
uniform vec4 heat_color : source_color = vec4(1.0, 0.62, 0.18, 1.0);
// How far lobes shrink by the end of life (0 = not at all).
uniform float erosion = 0.75;
uniform float softness = 0.6;
uniform float opacity = 1.0;

varying float life;
varying float seed;

void vertex() {
	// Billboard with the particle's own spin (INSTANCE_CUSTOM.x) and scale.
	float a = INSTANCE_CUSTOM.x;
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	face = face * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	life = INSTANCE_CUSTOM.y;
	seed = fract(float(INSTANCE_ID) * 0.6180339 + 0.13);
}

float h1(float n) {
	return fract(sin(n * 91.345 + seed * 47.13) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y; // up on screen
	// The lobes: a big one in the middle, the rest around it, biggest near the top.
	float best_z = -1.0;
	vec3 n = vec3(0.0, 0.0, 1.0);
	float cover = 0.0;
	float shrink = 1.0 - erosion * smoothstep(0.35, 1.0, life);
	int count = 5 + int(h1(1.0) * 3.0);
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		vec2 c = vec2(0.0, -0.05);
		float r = 0.5;
		if (i > 0) {
			float ang = float(i) / float(count - 1) * 6.2831853 + h1(float(i)) * 1.2;
			float dist = 0.32 + 0.12 * h1(float(i) + 3.0);
			c = vec2(cos(ang), sin(ang) * 0.85) * dist;
			r = (0.24 + 0.14 * h1(float(i) + 7.0)) * (1.0 + 0.25 * max(c.y, 0.0));
		}
		r *= shrink;
		// Lumpy edges: a touch of noise on the lobe outline.
		float wob = (texture(noise_tex, (p + c) * 0.7 + seed * 5.0 + float(i) * 0.31).r - 0.5) * 0.08;
		vec2 d = p - c;
		float q = length(d) / max(r + wob, 0.001);
		if (q < 1.0) {
			float z = sqrt(1.0 - q * q) * r + float(i) * 0.002; // height of this lobe's sphere
			if (z > best_z) {
				best_z = z;
				n = normalize(vec3(d / max(r, 0.001), sqrt(max(1.0 - q * q, 0.0))));
			}
		}
		cover = max(cover, 1.0 - smoothstep(0.9, 1.0, q));
	}
	if (cover <= 0.003) {
		discard;
	}
	// Light from above and slightly in front (screen space): sphere-lit lobes.
	vec3 l = normalize(vec3(0.35, 0.75, 0.55));
	float lit = clamp(dot(n, l) * 0.6 + 0.45, 0.0, 1.0);
	lit = lit * lit * (3.0 - 2.0 * lit); // smooth, slightly punchy terminator
	float rim = pow(1.0 - n.z, 3.0) * 0.25;
	vec3 col = COLOR.rgb * mix(shade_color.rgb, vec3(1.12), lit) + COLOR.rgb * rim;
	if (heat > 0.0) {
		// Hot core: glowing where the lobes are thick, early in life, cooling to smoke.
		float hot = heat * (1.0 - smoothstep(0.0, 0.5, life)) * smoothstep(0.4, 0.95, n.z);
		col = mix(col, heat_color.rgb * 3.2, hot);
	}
	// Soft contact with the world.
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	float scene = -sv.z / sv.w;
	float soft = clamp((scene + VERTEX.z) / softness, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = cover * COLOR.a * opacity * soft;
}
