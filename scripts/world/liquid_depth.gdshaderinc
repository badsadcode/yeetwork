// The "Depth" water look (Options: Water look; Liquid sets depth_look on water only):
// what's under the water fades by how far below the surface it is. Just under, it shows
// clearly with a pale blue tint; a metre or two down it has faded into the water's own rich
// blue, so the top of a sunken box shows and its bottom is gone, and a deep floor is hidden.
// (Not by how much water the view crosses: that fades a shallow floor seen at a low angle
// as much as a deep one.) Its edges melt into whatever they meet.

uniform bool depth_look = false;
// Metres below the surface where things are about two thirds faded into the water colour.
uniform float fade_depth = 0.9;
uniform vec4 depth_color : source_color = vec4(0.07, 0.32, 0.64, 1.0);
uniform vec4 near_tint : source_color = vec4(0.66, 0.86, 1.0, 1.0);

// How much of what's behind comes through: by its depth below the surface (and a little
// by the water the view crosses), tinted pale blue once it's under.
vec3 depth_transmit(float floor_depth, float thick) {
	float v = exp(-floor_depth / max(fade_depth, 0.01) - thick * 0.04);
	return v * mix(vec3(1.0), near_tint.rgb, smoothstep(0.0, 0.3, floor_depth));
}

// The water's own colour: a touch lighter over shallow ground.
vec3 depth_body(float floor_depth) {
	return mix(depth_color.rgb * 1.3, depth_color.rgb, smoothstep(0.0, 2.5, floor_depth));
}

// Opacity where the surface meets things: melts in over a third of a metre of water.
float depth_edge(float thick) {
	return smoothstep(0.0, 0.35, thick);
}

// Foam where the water touches something that comes up through it (walls, a pool's edge,
// a floating crate, a swimmer): a crisp white band with a ragged edge, and a thinner ring
// drifting in and out a little further off, broken into pieces. `d`: metres of water along
// the view between the surface and what's behind it.
uniform float foam_band = 0.65;

float depth_foam(float d, vec2 xz, float t) {
	float fine = texture(foam_noise, xz * 1.35 + vec2(t * 0.02, -t * 0.015)).r;
	float mid = texture(foam_noise, xz * 0.45 - vec2(t * 0.012, 0.0)).r;
	float aa = max(fwidth(d), 0.004);
	float edge = foam_band * (0.45 + 1.1 * fine);
	float band = 1.0 - smoothstep(edge - aa, edge + aa, d);
	float r = foam_band * (2.0 + 0.35 * sin(t * 1.4 + mid * 6.0));
	float w = 0.025 + 0.02 * fine;
	float ring = (1.0 - smoothstep(w - aa, w + aa, abs(d - r))) * smoothstep(0.42, 0.5, mid);
	return max(band, ring * 0.85);
}
