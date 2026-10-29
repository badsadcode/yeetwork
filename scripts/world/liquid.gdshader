shader_type spatial;
// Stylized liquid surface (water, acid, lava): Gerstner waves with scrolling detail normals,
// refraction with a touch of colour dispersion, per-channel depth absorption (red fades
// first), caustics on what lies below, foam where waves fold over and along shores, sharp
// sun glints, light glowing through thin crests, and for lava a cooled crust with glowing
// cracks. Screen-space reflections mirror the world in the water (the sky where they find
// nothing). Seen from below it shows Snell's window: the world above inside a bright circle,
// a dark mirror of the depths outside it.
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

#include "res://scripts/world/liquid_waves.gdshaderinc"

uniform vec4 shallow_color : source_color = vec4(0.12, 0.62, 0.62, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.13, 0.24, 1.0);
// Light scattered inside thin wave crests (the green-teal glow).
uniform vec4 scatter_color : source_color = vec4(0.1, 0.75, 0.55, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy = 0.0;
// Metres of liquid before what lies below fades out (per channel: red goes first).
uniform float clarity = 6.0;
uniform vec3 absorption = vec3(2.4, 1.0, 0.65);
// Metres of depth until the colour is fully "deep".
uniform float depth_fade = 5.0;
uniform float refraction = 0.045;
uniform float dispersion = 0.3;
uniform float roughness_value = 0.035;
uniform float detail_strength = 0.45;
uniform float detail_scale = 1.0;
uniform float foam_amount = 1.0;
uniform float foam_width = 0.7;
uniform float bubbles = 0.0;
uniform float caustics = 1.0;
uniform float scatter_strength = 0.6;
uniform float glint = 1.0;
// The sun is a disc, not a point: glints use at least this roughness.
uniform float glint_roughness = 0.14;
// Screen-space reflections: samples per pixel (0 = sky reflection only) and reach (m).
uniform int ssr_steps = 16;
uniform float ssr_distance = 40.0;
// Lava: plates of dark cooled crust (foam_color) drifting on the glow, cracks between them.
uniform float crust = 0.0;

uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 world_pos;
varying vec3 wave_n;
varying float crest;
varying float fold;
// Passed from fragment() to light().
varying float v_thin;
varying float v_foam;
varying float v_under;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n;
	float c;
	float f;
	vec3 off = gerstner(wp.xz, n, c, f);
	crest = c;
	fold = f;
	VERTEX += off; // liquids are never rotated or scaled, so world offset == local offset
	NORMAL = n;
	wave_n = n;
	world_pos = wp + off;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Animated Voronoi edges: bright wobbly lines like light focused by waves (also lava cracks).
float caustic(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.42 * sin(t * 0.9 + 6.2831 * o);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return 1.0 - smoothstep(0.0, 0.16, f2 - f1);
}

// Interleaved gradient noise: per-pixel jitter that hides the banding of few samples.
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Screen-space reflection: march the reflected ray (view space) against the depth buffer.
// Returns the reflected colour and how sure the hit is (0 = nothing found, use the sky).
vec4 ssr(vec3 vpos, vec3 vnorm, vec3 view, mat4 proj, mat4 inv_proj, float jitter) {
	vec3 rd = reflect(-view, vnorm);
	if (rd.z > 0.7) {
		return vec4(0.0); // bouncing back toward the camera: nothing on screen to show
	}
	vec3 prev = vpos;
	for (int i = 0; i < ssr_steps; i++) {
		float s = (float(i) + jitter) / float(ssr_steps);
		float tt = 0.2 + s * s * ssr_distance; // fine steps close by
		vec3 p = vpos + rd * tt;
		if (p.z > -0.05) {
			break;
		}
		vec4 clip = proj * vec4(p, 1.0);
		vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			break;
		}
		float d = texture(depth_tex, uv).r;
		if (d > 0.000001) {
			vec4 sv = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
			float behind = sv.z / sv.w - p.z; // > 0: the ray passed behind the scene
			if (behind > 0.0 && behind < max(0.5, tt * 0.12)) {
				// Binary search between the last two samples for the exact crossing.
				vec3 a = prev;
				vec3 b = p;
				for (int j = 0; j < 4; j++) {
					vec3 m = (a + b) * 0.5;
					vec4 mc = proj * vec4(m, 1.0);
					vec2 muv = mc.xy / mc.w * 0.5 + 0.5;
					vec4 ms = inv_proj * vec4(muv * 2.0 - 1.0, texture(depth_tex, muv).r, 1.0);
					if (ms.z / ms.w - m.z > 0.0) {
						b = m;
					} else {
						a = m;
					}
				}
				vec4 bc = proj * vec4(b, 1.0);
				vec2 buv = bc.xy / bc.w * 0.5 + 0.5;
				vec2 edge = smoothstep(vec2(0.0), vec2(0.07), buv) * smoothstep(vec2(1.0), vec2(0.93), buv);
				float conf = edge.x * edge.y * (1.0 - s * s);
				return vec4(textureLod(screen_tex, buv, 0.0).rgb, conf);
			}
		}
		prev = p;
	}
	return vec4(0.0);
}

// View-space position of the opaque scene behind this pixel.
vec3 scene_view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, max(d, 0.000001), 1.0);
	return v.xyz / v.w;
}

void fragment() {
	float t = wave_time;
	float dist = length(VERTEX);
	bool under = !FRONT_FACING;
	v_under = under ? 1.0 : 0.0;

	// Detail ripples from two scrolling normal maps, calmer with distance (no shimmer).
	vec2 uv1 = world_pos.xz * 0.045 * detail_scale + vec2(t * 0.019, t * 0.011) * wave_speed;
	vec2 uv2 = world_pos.xz * 0.12 * detail_scale - vec2(t * 0.015, -t * 0.022) * wave_speed;
	vec2 detail = (texture(normal_a, uv1).rg + texture(normal_b, uv2).rg - 1.0) * detail_strength;
	// Fine, sharp chop close to the camera: what makes the surface look crisp.
	vec2 uv3 = world_pos.xz * 0.31 * detail_scale + vec2(-t * 0.041, t * 0.033) * wave_speed;
	detail += (texture(normal_a, uv3).rg - 0.5) * 1.6 * detail_strength / (1.0 + dist * 0.08);
	detail /= 1.0 + dist * 0.012;
	vec3 nw = normalize(wave_n + vec3(detail.x, 0.0, detail.y));
	vec3 nv = normalize((VIEW_MATRIX * vec4(under ? -nw : nw, 0.0)).xyz);
	vec3 flat_v = normalize((VIEW_MATRIX * vec4(0.0, under ? -1.0 : 1.0, 0.0, 0.0)).xyz);
	NORMAL = nv;
	float ndv = clamp(dot(nv, VIEW), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);

	// How much liquid the view ray crosses before it hits the scene (sky behind = endless).
	bool sky = texture(depth_tex, SCREEN_UV).r < 0.000001;
	vec3 behind = scene_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	float thick = sky ? 1000.0 : max(length(behind) - dist, 0.0);

	// Refraction: bend the lookup by how far the normal tilts away from flat; red, green and
	// blue bend by slightly different amounts. Offsets that would sample things in front of
	// the surface are dropped.
	vec2 ofs = (nv.xy - flat_v.xy) * refraction * (under ? 2.5 : clamp(thick * 0.5, 0.0, 1.0));
	ofs /= max(dist * 0.06, 1.0);
	vec2 suv = SCREEN_UV + ofs;
	bool sky_r = texture(depth_tex, suv).r < 0.000001;
	vec3 behind_r = scene_view_pos(suv, INV_PROJECTION_MATRIX);
	if (!sky_r && length(behind_r) < dist) {
		ofs = vec2(0.0);
		sky_r = sky;
		behind_r = behind;
	}
	float thick_r = sky_r ? 1000.0 : max(length(behind_r) - dist, 0.0);
	vec3 refr = vec3(
		textureLod(screen_tex, SCREEN_UV + ofs * (1.0 - dispersion), 0.0).r,
		textureLod(screen_tex, SCREEN_UV + ofs, 0.0).g,
		textureLod(screen_tex, SCREEN_UV + ofs * (1.0 + dispersion), 0.0).b);

	// Depth of the floor below the surface (colour, caustics) and right behind it (shore foam).
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(behind_r, 1.0)).xyz;
	float floor_depth = sky_r ? 1000.0 : max(world_pos.y - floor_world.y, 0.0);
	float shore_depth = sky ? 1000.0 : max(world_pos.y - (INV_VIEW_MATRIX * vec4(behind, 1.0)).y, 0.0);

	float cst = 0.0;
	if (caustics > 0.0 && floor_depth < 25.0 && !under) {
		vec2 cp = floor_world.xz * 0.42 + detail * 0.4;
		cst = caustic(cp, t) * 0.6 + caustic(cp * 1.6 + 3.1, t * 1.3) * 0.4;
		cst *= caustics * exp(-floor_depth * 0.15) * smoothstep(0.0, 0.5, floor_depth);
	}
	vec3 transmit = under ? vec3(1.0) : exp(-thick_r / max(clarity, 0.01) * absorption);
	float transmit_avg = (transmit.r + transmit.g + transmit.b) / 3.0;
	refr *= transmit * (1.0 + cst * 1.4);

	float n1 = texture(foam_noise, world_pos.xz * 0.11 + vec2(t * 0.011, 0.0)).r;
	float n2 = texture(foam_noise, world_pos.xz * 0.37 - vec2(0.0, t * 0.016)).r;

	// Water colour: shallow to deep, and lit from inside where crests are thin.
	float deep = 1.0 - exp(-floor_depth / max(depth_fade, 0.01));
	vec3 body = mix(shallow_color.rgb, deep_color.rgb, deep);
	// Far out, where the waves fade flat, use the average so the sea keeps one colour.
	float thin = mix(0.3, pow(crest, 2.0), wave_fade(world_pos.xz)) * clamp(wave_height * 1.5, 0.0, 1.0);
	body = mix(body, scatter_color.rgb, clamp(thin * scatter_strength * 0.45, 0.0, 1.0));
	v_thin = thin;

	// Foam: lacy patches where the waves fold over, and bands lapping at shores.
	float shore = under ? 0.0 : 1.0 - smoothstep(0.0, foam_width, shore_depth);
	shore *= 0.6 + 0.4 * sin(shore_depth * 10.0 - t * 2.4 + n1 * 5.0);
	float breaking = smoothstep(0.06, 0.36, fold) * smoothstep(0.48, 0.85, crest);
	float foam_src = clamp(max(shore * 1.3, breaking) * foam_amount, 0.0, 1.0);
	// Lace: webs of bubbles that thin out toward the edge of a patch.
	float lace = clamp(n1 * 0.55 + n2 * 0.6, 0.0, 1.0);
	float foam = smoothstep(1.0 - foam_src, 1.0 - foam_src + 0.12, lace) * (0.35 + 0.55 * foam_src);
	if (bubbles > 0.0) {
		float b = texture(foam_noise, world_pos.xz * 0.7 + vec2(0.0, t * 0.13)).r;
		float pop = smoothstep(0.78, 0.84, b) * (0.5 + 0.5 * sin(t * 6.0 + b * 40.0));
		foam = max(foam, pop * bubbles);
	}

	// Lava crust: dark plates drift slowly; the cracks between them glow.
	float heat = 1.0;
	if (crust > 0.0) {
		vec2 lp = world_pos.xz * 0.42 + vec2(t * 0.035, t * 0.02);
		float cracks = caustic(lp, t * 0.2) * 0.7 + caustic(lp * 2.3 + 1.7, t * 0.3) * 0.3;
		float plates = smoothstep(0.25, 0.6, texture(foam_noise, world_pos.xz * 0.06 + vec2(t * 0.004, t * 0.003)).r + n2 * 0.25);
		float crusted = plates * crust;
		body = mix(body, foam_color.rgb, crusted * (1.0 - cracks));
		heat = mix(1.0, 0.04 + cracks * 1.1, crusted);
	}

	float glow = glow_energy * heat * (0.65 + 0.35 * n1 + cst * 0.4);
	vec4 refl = vec4(0.0);
	if (!under && ssr_steps > 0 && roughness_value < 0.3) {
		refl = ssr(VERTEX, nv, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, 0.25 + 0.5 * ign(FRAGCOORD.xy));
	}
	if (!under) {
		ALBEDO = body * (1.0 - transmit_avg) * (1.0 - fres);
		// A little glossier than real water (F0 0.07 instead of 0.02), for a stylized sheen.
		EMISSION = refr * (1.0 - fres) + glow_color.rgb * glow + refl.rgb * mix(0.07, 1.0, fres) * refl.a;
		ALPHA = clamp(thick * 3.0, 0.0, 1.0);
	} else {
		// From below. Inside Snell's window (about 49 degrees around straight up) the world
		// above shows through; outside it the surface mirrors the dark water below.
		float window = smoothstep(0.62, 0.7, ndv);
		float rim = window * (1.0 - window) * 4.0;
		vec3 mirror = deep_color.rgb * 0.35 + scatter_color.rgb * 0.04;
		ALBEDO = vec3(0.0);
		EMISSION = mix(mirror, refr * 0.95, window) + scatter_color.rgb * rim * 0.25 + glow_color.rgb * glow * 0.5;
		ALPHA = 1.0;
	}
	v_foam = foam;
	ALBEDO = mix(ALBEDO, foam_color.rgb * (under ? 0.15 : 1.0), foam);
	EMISSION *= 1.0 - foam * 0.9;
	ALPHA = max(ALPHA, foam);
	ROUGHNESS = mix(roughness_value, 0.85, foam);
	// Where the screen-space reflection found something, it replaces the sky reflection.
	SPECULAR = under ? 0.0 : 0.65 * (1.0 - foam) * (1.0 - refl.a);
	METALLIC = 0.0;
}

void light() {
	// From below, all the light comes through the window (fragment).
	if (v_under < 0.5) {
		float ndl = dot(NORMAL, LIGHT);
		// Soft wrapped diffuse for the water body and foam.
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * mix(0.55, 1.0, v_foam) / PI;
		// Sun glints: sharp GGX on the rippled normal.
		vec3 h = normalize(VIEW + LIGHT);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float a = max(ROUGHNESS, glint_roughness);
		a *= a;
		float a2 = a * a;
		float dd = ndh * ndh * (a2 - 1.0) + 1.0;
		float spec_d = a2 / (PI * dd * dd);
		float spec_f = 0.02 + 0.98 * pow(1.0 - clamp(dot(h, VIEW), 0.0, 1.0), 5.0);
		float spec = min(spec_d * spec_f / (4.0 * max(dot(NORMAL, VIEW), 0.1)), 40.0);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(ndl, 0.0, 1.0) * spec * glint * (1.0 - v_foam) / PI;
		// Light shining through thin crests: the glow when you look toward the light.
		vec3 hs = normalize(LIGHT + NORMAL * 0.6);
		float back = pow(clamp(dot(VIEW, -hs), 0.0, 1.0), 4.0);
		float sss = (back * 1.5 + 0.2) * v_thin * scatter_strength * (1.0 - v_foam);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * scatter_color.rgb * sss / PI;
	}
}
