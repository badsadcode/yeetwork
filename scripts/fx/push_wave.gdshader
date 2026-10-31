shader_type spatial;
// The gravity gun's push: a wave of pushed air rushing out from the muzzle. A disc facing
// along the push: its colour is strongest at the rim and fades to clear toward the middle,
// and around the rim what's behind it bends outward (refraction), so it reads as a wave
// through the air rather than a drawn circle. `life` 0 -> 1 as it spreads and fades.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float life = 0.0;
uniform float refraction = 0.09;

varying vec3 radial_v; // the outward direction across the disc, in view space

void vertex() {
	// (PlaneMesh: the disc lies in its XZ plane)
	radial_v = (MODELVIEW_MATRIX * vec4(VERTEX.x, 0.0, VERTEX.z, 0.0)).xyz;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0; // 0 middle .. 1 rim
	if (r > 1.0) {
		discard;
	}
	// Spreading and fading; seen edge-on it thins away rather than leaving a line.
	float fade = (1.0 - smoothstep(0.35, 1.0, life)) * smoothstep(0.05, 0.35, abs(dot(NORMAL, VIEW)));
	// (soft where it cuts into the floor or a wall: no straight edge)
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	fade *= smoothstep(0.0, 0.5, length(sv.xyz / sv.w) - length(VERTEX));
	float edge = 1.0 - smoothstep(0.9, 1.0, r);
	// Colour: a faint tint, clear in the middle, strongest at the rim.
	float tint = pow(smoothstep(0.35, 0.96, r), 2.2) * edge * fade * 0.4;
	// Refraction: a wide band round the rim pushing the picture outward, with ripples
	// running out through it so it shimmers like a wave.
	float band = smoothstep(0.3, 0.85, r) * edge * fade;
	float ripple = 0.55 + 0.45 * sin(r * 34.0 - life * 26.0);
	vec2 dir = normalize(radial_v.xy + vec2(1e-5));
	vec2 suv = SCREEN_UV + dir * vec2(1.0, -1.0) * band * ripple * refraction / max(-VERTEX.z * 0.12, 1.0);
	vec3 bent = textureLod(screen_tex, suv, 0.0).rgb;
	// Premultiplied: bent background where the band is, the tint glowing over it.
	ALBEDO = bent * band * (1.0 - tint) + color.rgb * 1.2 * tint;
	ALPHA = 1.0 - (1.0 - band) * (1.0 - tint);
}
