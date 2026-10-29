shader_type spatial;
// Puffy cartoon clouds: a cluster of soft balls, lumpy from noise, lit like cotton wool:
// warm sunlit tops, cool flat-ish undersides, a silver lining where the sun is behind them
// and light glowing through the thin edges. Soft gradients only (no cel bands, no outlines).
render_mode diffuse_lambert_wrap, specular_disabled, cull_back;

uniform vec4 lit_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 shade_color : source_color = vec4(0.62, 0.7, 0.88, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float lumpiness = 0.18;
uniform float time = 0.0;

varying vec3 local_pos;
varying float height01;

float n3(vec3 p) {
	return sin(p.x * 1.7 + sin(p.z * 1.3)) * sin(p.y * 2.1 + p.x * 0.7) * sin(p.z * 1.9 + p.y * 1.1);
}

void vertex() {
	vec3 p = VERTEX;
	// Billowing lumps: three octaves of a cheap smooth noise, slowly churning.
	float n = n3(p * 0.9 + time * 0.05) * 0.6 + n3(p * 2.3 - time * 0.04) * 0.3 + n3(p * 5.1) * 0.1;
	VERTEX += NORMAL * n * lumpiness;
	local_pos = VERTEX;
	height01 = clamp(UV.y, 0.0, 1.0); // set by the mesh builder: 0 at the base, 1 at the top
}

void fragment() {
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Undersides go cool and a little darker; tops stay bright.
	float up = smoothstep(-0.6, 0.8, wn.y) * 0.6 + height01 * 0.4;
	ALBEDO = mix(shade_color.rgb, lit_color.rgb, up);
	// Silver lining: light through the thin edges seen against the sky.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * rim * 0.25 * (0.5 + 0.5 * up);
	ROUGHNESS = 1.0;
	BACKLIGHT = lit_color.rgb * 0.35;
}
