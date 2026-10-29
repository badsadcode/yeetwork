shader_type spatial;
// Electric arc ribbons (gravity-gun tether), added on top of the scene so the glow blooms.
// Vertex COLOR = tint (rgb) and intensity (a). UV.y runs across the ribbon (0..1),
// UV.x = how much white-hot core the ribbon has (0 = soft glow only, 1 = hot core).
// UV2.x > 0.5: a round glow sprite (the starbursts at the ends), UV = 0..1 over the quad.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 3.0;

void fragment() {
	vec3 c;
	if (UV2.x > 0.5) {
		float r = length(UV * 2.0 - 1.0);
		float core = exp(-r * r * 40.0);
		float glow = exp(-r * r * 6.0) * 0.55 + exp(-r * 3.5) * 0.15;
		c = COLOR.rgb * glow + mix(COLOR.rgb, vec3(1.0), 0.7) * core * 0.6;
	} else {
		float x = abs(UV.y * 2.0 - 1.0); // 0 in the middle, 1 at the edges
		float core = exp(-x * x * 60.0) * UV.x;
		float glow = exp(-x * x * 4.0) * (0.6 - UV.x * 0.25);
		c = COLOR.rgb * glow + mix(COLOR.rgb, vec3(1.0), 0.65) * core * 1.2;
	}
	ALBEDO = c * COLOR.a * energy;
}
