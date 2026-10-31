shader_type spatial;
// The fire round something burning (Burning's "new" fire look): ray-marched through a box
// over the burning thing, so the flames have real depth from every side and wrap round it.
// Their shape: a layer hugging the thing's sides (thicker higher up) and a plume over its top
// narrowing to the tips; 3D noise stretched upward and rising through it (two speeds, so it
// churns rather than scrolls) eats into that shape, more and more toward the tips, which
// tears the top into separate licking tongues. Hot (yellow-white) deep inside and low down,
// orange, red at the edges and tips, going to dark smoke where it cools. The thing itself
// hides the flames behind it (the depth buffer stops each ray).
// The box mesh is a unit cube scaled over the volume (world-aligned: flames rise up even when
// the thing tumbles); drawn on its back faces, so it also works with the camera inside it.
render_mode unshaded, blend_premul_alpha, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;

uniform sampler3D noise3d : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float intensity = 1.0;
uniform int steps = 24;
uniform float seed = 0.0;
// The burning thing: world -> its own space (centred on it), its half size and how round its
// corners are; its bounds in the world (footprint min x, min z, max x, max z; bottom; top).
uniform mat4 fuel_inv;
uniform vec3 fuel_half = vec3(0.5);
uniform float corner = 0.1;
uniform vec4 foot = vec4(-0.5, -0.5, 0.5, 0.5);
uniform float fuel_bottom = 0.0;
uniform float fuel_top = 1.0;
uniform float flame_height = 1.2; // how far the plume rises over its top
uniform vec4 deep_color : source_color = vec4(1.0, 0.3, 0.04, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.6, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.93, 0.58, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.2, 0.16, 0.15, 1.0);

varying vec3 box_c;
varying vec3 box_h;

void vertex() {
	box_c = MODEL_MATRIX[3].xyz;
	box_h = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)) * 0.5;
}

float sd_box(vec3 q, vec3 b, float r) {
	vec3 d = abs(q) - (b - r);
	return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0) - r;
}

float sd_rect(vec2 q, vec2 b, float r) {
	vec2 d = abs(q) - (b - r);
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// Flame density at p (0..1) and how hot it is there (0..1).
float flame(vec3 p, float t, out float heat) {
	float total = fuel_top - fuel_bottom + flame_height;
	float yf = clamp((p.y - fuel_bottom) / total, 0.0, 1.0); // 0 at the foot, 1 at the tips
	// The whole fire sways, more toward the top.
	p.x += sin(p.y * 1.7 - t * 2.3 + seed) * 0.1 * yf;
	p.z += sin(p.y * 1.3 - t * 1.9 + seed * 2.1) * 0.1 * yf;
	// How far outside the flame's shape p is (negative inside).
	float env;
	if (p.y < fuel_top) {
		vec3 q = (fuel_inv * vec4(p, 1.0)).xyz;
		env = sd_box(q, fuel_half, corner) - mix(0.02, 0.24, yf);
	} else {
		float s = max((p.y - fuel_top) / flame_height, 0.0);
		vec2 hb = (foot.zw - foot.xy) * 0.5;
		float d2 = sd_rect(p.xz - (foot.xy + foot.zw) * 0.5, hb, corner);
		env = d2 - mix(0.24, -min(hb.x, hb.y) - 0.1, pow(min(s, 1.0), 0.75));
		env += max(s - 0.8, 0.0) * 2.5; // (nothing much past the tips)
	}
	env += (1.0 - intensity) * 0.7;
	if (env > 0.7) {
		heat = 0.0;
		return 0.0;
	}
	// Noise rising through it: a slow big churn and a quicker smaller flicker (big, bold
	// shapes: cartoon flames, not fine wisps).
	vec3 np = vec3(p.x * 0.55, p.y * 0.26 - t * 0.38, p.z * 0.55) + seed;
	float n = texture(noise3d, np).r * 0.66;
	n += texture(noise3d, vec3(p.x * 1.15, p.y * 0.7 - t * 1.1, p.z * 1.15) + seed * 1.37 + 0.31).r * 0.34;
	n = (n - 0.5) * 2.2; // (the texture's noise sits mostly within 0.3..0.7)
	float amp = mix(0.3, 0.8, yf);
	float d = n * amp - env;
	heat = clamp(0.8 - yf * 1.1 + n * 0.35 + clamp(d, 0.0, 0.3) * 1.1, 0.0, 1.0);
	// Crisp edges; and gone before the top of the box (or the tips get cut off flat).
	return clamp(d * 11.0, 0.0, 1.0) * smoothstep(box_c.y + box_h.y, box_c.y + box_h.y - 0.6, p.y);
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(wpos - cam);
	// Where the view ray crosses the box (from the eye if inside it).
	vec3 inv_rd = 1.0 / (rd + vec3(1e-6));
	vec3 ta = (box_c - box_h - cam) * inv_rd;
	vec3 tb = (box_c + box_h - cam) * inv_rd;
	vec3 tmin = min(ta, tb);
	vec3 tmax = max(ta, tb);
	float t0 = max(max(max(tmin.x, tmin.y), tmin.z), 0.0);
	float t1 = min(min(tmax.x, tmax.y), tmax.z);
	// Stop at opaque geometry (the burning thing itself, the floor, anything in front).
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	t1 = min(t1, length(sv.xyz / sv.w));
	if (t1 <= t0) {
		discard;
	}
	float dt = (t1 - t0) / float(steps);
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float t = TIME;
	vec3 col = vec3(0.0);
	float trans = 1.0;
	for (int i = 0; i < steps; i++) {
		vec3 p = cam + rd * (t0 + (float(i) + jitter) * dt);
		float heat;
		float dens = flame(p, t, heat);
		if (dens > 0.004) {
			vec3 c = mix(deep_color.rgb, core_color.rgb, smoothstep(0.18, 0.55, heat));
			c = mix(c, tip_color.rgb, smoothstep(0.62, 0.95, heat));
			c *= 1.0 + heat * heat * heat * 4.5; // (HDR: the hot core glows; the rest stays coloured)
			float hot = smoothstep(0.02, 0.2, heat);
			c = mix(smoke_color.rgb, c, hot);
			float a = 1.0 - exp(-dens * dt * 5.0);
			col += c * a * trans;
			// Nearer flames mostly hide the ones behind them (the fire reads as shapes, not a
			// white-hot blur); smoke hides it all.
			trans *= 1.0 - a * mix(0.72, 0.8, hot);
			if (trans < 0.03) {
				break;
			}
		}
	}
	float alpha = 1.0 - trans;
	if (alpha < 0.004) {
		discard;
	}
	ALBEDO = col;
	ALPHA = alpha;
}
