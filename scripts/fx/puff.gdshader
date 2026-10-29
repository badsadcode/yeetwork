shader_type spatial;
// Soft cloudy puff for dust, smoke, mist and fireballs (CPUParticles3D with a QuadMesh).
// Camera-facing, shaped by layered cloud noise, lit from above (bright tops, cool undersides),
// coloured by the particle's colour ramp over its life (COLOR), eroding from the edges as it
// fades, and softened where it meets geometry (no hard intersection lines).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Underside tint (multiplied in): cool shadows, warm light.
uniform vec4 shade_color : source_color = vec4(0.62, 0.66, 0.82, 1.0);
// Fireballs: a hot glowing core early in life (0 = plain dust/smoke).
uniform float heat = 0.0;
uniform vec4 heat_color : source_color = vec4(1.0, 0.75, 0.3, 1.0);
// How lumpy the outline is, and how fast the puff erodes away at the end of its life.
uniform float lumpiness = 0.55;
uniform float erosion = 0.85;
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
	seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 o = vec2(seed * 7.13, seed * 3.71);
	// Two octaves of cloud noise, drifting a little as the puff ages.
	float n = texture(noise_tex, UV * 0.55 + o + vec2(life * 0.15, -life * 0.1)).r * 0.65;
	n += texture(noise_tex, UV * 1.3 - o * 1.7 + vec2(0.0, life * 0.25)).r * 0.35;
	float body = (1.0 - r * r) - (1.0 - n) * lumpiness;
	// Erode: the threshold rises with age, so the puff breaks up into wisps and vanishes.
	float thr = life * erosion;
	float a = smoothstep(thr, thr + 0.25, body);
	if (a <= 0.003) {
		discard;
	}
	// Light from above: brighter towards the top and in the denser middle.
	float lit = clamp((1.0 - UV.y) * 0.75 + body * 0.6, 0.0, 1.0);
	vec3 col = COLOR.rgb * mix(shade_color.rgb, vec3(1.08), lit);
	if (heat > 0.0) {
		float hot = heat * (1.0 - smoothstep(0.0, 0.45, life)) * smoothstep(0.1, 0.6, body);
		col = mix(col, heat_color.rgb * 3.0, hot);
	}
	// Soft contact with the world.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene = -sv.z / sv.w;
	float soft = clamp((scene + VERTEX.z) / softness, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = a * COLOR.a * opacity * soft;
}
