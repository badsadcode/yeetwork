shader_type spatial;
// A streak of pushed air (Effects._push_streaks): a thin ribbon along the particle's flight
// (its Y axis: CPUParticles3D aligns it to the velocity) that turns about that line to face
// the camera; bright near its head, fading to its tail and soft at its edges. The particle's
// colour (team or neutral, fading out) comes in as COLOR.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz; // (scaled: the streak's length)
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 side = normalize(cross(normalize(axis), to_cam) + vec3(1e-5));
	float width = length(MODEL_MATRIX[0].xyz) * 0.05;
	vec3 world = origin + axis * VERTEX.y + side * VERTEX.x * width;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float along = UV.y; // 0 head .. 1 tail
	float a = smoothstep(0.0, 0.15, along) * (1.0 - smoothstep(0.35, 1.0, along));
	a *= 1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5));
	ALBEDO = COLOR.rgb * COLOR.a * a * 1.4;
}
