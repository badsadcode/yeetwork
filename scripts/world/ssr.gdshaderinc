// Screen-space reflections shared by the liquid and glass shaders. Include it after
// declaring `screen_tex` (hint_screen_texture) and `depth_tex` (hint_depth_texture).

// Samples per pixel (0 = no screen-space reflections, the sky reflection only) and reach (m).
uniform int ssr_steps = 16;
uniform float ssr_distance = 40.0;

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

