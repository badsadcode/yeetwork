// Flood water (FloodZone): the liquid's flat plane bends to the flood's surface, read from a
// texture over the zone (R = surface height, G = water depth). Off (flood_on false) for
// every other liquid, which then draws exactly as before.
uniform bool flood_on = false;
uniform sampler2D flood_tex : filter_linear, repeat_disable;
uniform vec4 flood_rect = vec4(0.0, 0.0, 1.0, 1.0); // min x, min z, size x, size z
varying float flood_depth;

// The flood's surface height at world xz; also its depth there and its slope.
float flood_height(vec2 xz, out float depth, out vec2 slope) {
	vec2 uv = (xz - flood_rect.xy) / flood_rect.zw;
	vec2 texel = 1.0 / vec2(textureSize(flood_tex, 0));
	vec2 s = textureLod(flood_tex, uv, 0.0).rg;
	float hx = textureLod(flood_tex, uv + vec2(texel.x, 0.0), 0.0).r;
	float hz = textureLod(flood_tex, uv + vec2(0.0, texel.y), 0.0).r;
	depth = s.g;
	slope = clamp(vec2(hx - s.r, hz - s.r) / (texel * flood_rect.zw), vec2(-1.0), vec2(1.0));
	return s.r;
}
