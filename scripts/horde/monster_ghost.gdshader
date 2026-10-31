shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, shadows_disabled;
// Ghosts (Horde's MultiMesh for them): monster.gdshader's swaying, see-through and glowing,
// flickering now and then; a hit flash makes them flare.
// INSTANCE_CUSTOM: x its own phase, y how much it's walking (0..1), z a hit flash (0..1),
// w flailing (flying through the air).

varying float v_flash;
varying float v_glow;

vec3 rot_x(vec3 p, vec3 pivot, float a) {
	vec3 q = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(q.x, q.y * c - q.z * s, q.y * s + q.z * c);
}

void vertex() {
	float part = UV.x;
	float phase = INSTANCE_CUSTOM.x * 6.2832;
	float walk = INSTANCE_CUSTOM.y;
	float flail = INSTANCE_CUSTOM.w;
	float cyc = TIME * 4.2 + phase;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (part > 0.5 && part < 2.5) { // legs: a stiff, lurching stride
		float side = part < 1.5 ? 0.0 : 3.1416;
		float a = sin(cyc + side) * 0.55 * walk + flail * sin(TIME * 17.0 + side + phase) * 0.7;
		v = rot_x(v, vec3(0.0, 0.8, 0.0), a);
		n = rot_x(n, vec3(0.0), a);
	} else if (part > 2.5 && part < 4.5) { // arms: reaching, bobbing, flailing in the air
		float side = part < 3.5 ? 0.0 : 1.7;
		float a = sin(cyc * 0.5 + side) * 0.18 * walk - 0.1 + flail * sin(TIME * 21.0 + side + phase) * 1.3;
		v = rot_x(v, vec3(0.0, 1.35, 0.0), a);
		n = rot_x(n, vec3(0.0), a);
	}
	// The whole body sways side to side and bobs with the stride; the head lolls.
	float sway = sin(cyc) * 0.05 * walk * (v.y / 1.8);
	v.x += sway;
	v.y += abs(sin(cyc)) * 0.04 * walk;
	if (part > 4.5) {
		v.x += sin(cyc * 0.5 + phase) * 0.05;
	}
	VERTEX = v;
	NORMAL = normalize(n);
	v_flash = INSTANCE_CUSTOM.z;
	v_glow = UV.y;
}

void fragment() {
	float flicker = 0.85 + 0.15 * sin(TIME * 13.0 + VERTEX.y * 3.0);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), v_flash);
	EMISSION = COLOR.rgb * (0.35 + v_glow * 3.0) * flicker + vec3(1.0) * v_flash * 1.5;
	ROUGHNESS = 0.4;
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALPHA = clamp((0.35 + rim * 0.4 + v_glow * 0.6) * flicker + v_flash * 0.4, 0.0, 1.0);
}
