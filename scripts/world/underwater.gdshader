shader_type spatial;
// Full-screen pass drawn by the local camera near a liquid. Every pixel checks whether
// its point on the near plane is under the (waving) surface, so with your eyes at the
// waterline the screen splits: above stays clear, below gets underwater fog, tint and
// light shafts, with a wobbly meniscus line where the surface cuts the lens.
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/world/liquid_waves.gdshaderinc"

uniform vec4 fog_color : source_color = vec4(0.03, 0.27, 0.33, 1.0);
uniform vec4 shaft_color : source_color = vec4(0.55, 0.95, 0.9, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Metres until the world disappears into the fog.
uniform float visibility = 14.0;
uniform float shafts = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0); // near plane (reversed Z), covers the screen
}

void fragment() {
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec4 nv = INV_PROJECTION_MATRIX * vec4(ndc, 1.0, 1.0);
	nv.xyz /= nv.w;
	vec3 near_world = (INV_VIEW_MATRIX * vec4(nv.xyz, 1.0)).xyz;
	float h = surface_height(near_world.xz);
	float below = h - near_world.y; // > 0: this pixel looks out from under the surface

	// Meniscus: a thin dark-then-bright band where the surface crosses the lens.
	float line_w = 0.012;
	float meniscus = 1.0 - smoothstep(0.0, line_w, abs(below));
	if (below < -line_w) {
		discard;
	}

	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(ndc, max(d, 0.000001), 1.0);
	sv.xyz /= sv.w;
	float dist = d < 0.000001 ? 10000.0 : length(sv.xyz);
	float fog = 1.0 - exp(-dist / max(visibility, 0.1));

	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(nv.xyz, 0.0)).xyz);
	// Light shafts: soft vertical streaks that sway, strongest looking up toward the surface.
	float sway = sin(dir.x * 9.0 + wave_time * 0.4) * 0.6 + sin(dir.z * 7.0 - wave_time * 0.3) * 0.6;
	float rays = pow(0.5 + 0.5 * sin(atan(dir.x, dir.z) * 23.0 + sway), 6.0);
	rays *= smoothstep(-0.2, 0.7, dir.y) * shafts * clamp(1.0 - below * 0.05, 0.2, 1.0);

	vec3 col = mix(fog_color.rgb * 1.1, fog_color.rgb, fog);
	col += shaft_color.rgb * rays * 0.25 + glow_color.rgb * 0.15;
	// Darker the deeper you are.
	col *= clamp(1.0 - below * 0.03, 0.35, 1.0);
	float a = clamp(0.32 + fog * 0.68 + rays * 0.15, 0.0, 1.0);
	if (below < line_w) {
		// Inside the meniscus band.
		col = mix(col, vec3(0.02, 0.06, 0.08), meniscus * 0.8);
		a = max(a * smoothstep(-line_w, 0.0, below), meniscus * 0.7);
	}
	ALBEDO = col;
	ALPHA = a;
}
