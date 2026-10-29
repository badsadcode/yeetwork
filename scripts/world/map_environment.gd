@tool
class_name MapEnvironment
extends RefCounted
## Lighting presets shared by built-in and custom maps: a cinematic stylized look with a
## warm key sun, cool fill, soft GI bounce (SDFGI + SSIL), soft AO and AgX tonemapping.
##   sunset - warm golden hour (default)      day   - bright, saturated, blue sky
##   night  - cool moonlight, deep blue sky   space - starfield, nebula and a planet


## Returns [WorldEnvironment, sun, fill] ready to add to the scene. `settings` may be a
## MapSettings node (or null) to tweak sun direction and energies.
static func build(preset: String, settings: Node = null) -> Array[Node]:
	var sun_rot := Vector3(-42, 38, 0)
	var sun_scale := 1.0
	var amb_scale := 1.0
	if settings:
		sun_rot = settings.get("sun_rotation_degrees")
		sun_scale = settings.get("sun_energy_scale")
		amb_scale = settings.get("ambient_scale")

	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sun_color := Color(1.0, 0.82, 0.6)
	var sun_energy := 2.4
	var fill_color := Color(0.55, 0.7, 1.0)
	var fill_energy := 0.25
	match preset:
		"day":
			sky_mat.sky_top_color = Color(0.2, 0.45, 0.95)
			sky_mat.sky_horizon_color = Color(0.7, 0.85, 1.0)
			sky_mat.ground_horizon_color = Color(0.75, 0.82, 0.95)
			sky_mat.ground_bottom_color = Color(0.3, 0.35, 0.45)
			sun_color = Color(1.0, 0.95, 0.85)
			sun_energy = 2.6
		"night":
			sky_mat.sky_top_color = Color(0.03, 0.04, 0.12)
			sky_mat.sky_horizon_color = Color(0.2, 0.18, 0.38)
			sky_mat.ground_horizon_color = Color(0.15, 0.12, 0.25)
			sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.06)
			sky_mat.sun_angle_max = 6.0
			sun_color = Color(0.65, 0.75, 1.0)
			sun_energy = 0.9
			fill_color = Color(0.5, 0.35, 0.8)
			fill_energy = 0.2
		_:
			sky_mat.sky_top_color = Color(0.22, 0.42, 0.92)
			sky_mat.sky_horizon_color = Color(1.0, 0.74, 0.55)
			sky_mat.ground_horizon_color = Color(0.95, 0.72, 0.62)
			sky_mat.ground_bottom_color = Color(0.25, 0.28, 0.45)
	sky.sky_material = sky_mat
	if preset == "space":
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://scripts/world/space_sky.gdshader")
		sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55 * amb_scale
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.ssao_enabled = true
	env.ssao_radius = 2.2
	env.ssao_intensity = 1.1
	env.ssao_power = 1.3
	env.ssao_detail = 0.3
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_energy = 1.1
	env.sdfgi_cascades = 4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.82, 0.95)
	env.fog_density = 0.0006
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0022
	env.volumetric_fog_albedo = Color(1.0, 0.9, 0.82)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_sky_affect = 0.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.1
	match preset:
		"space":
			# Space is dark: rely on a tinted ambient so shadows stay readable and cool.
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.45, 0.42, 0.75)
			env.ambient_light_energy = 0.7 * amb_scale
			env.fog_enabled = false
			env.volumetric_fog_density = 0.0012
		"night":
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.3, 0.32, 0.6)
			env.ambient_light_energy = 0.6 * amb_scale
			env.fog_light_color = Color(0.25, 0.25, 0.45)
			env.fog_density = 0.004
			env.volumetric_fog_density = 0.01
			env.volumetric_fog_albedo = Color(0.7, 0.75, 1.0)
			env.glow_intensity = 0.8
		"day":
			env.volumetric_fog_density = 0.001
			env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_color
	sun.light_energy = sun_energy * sun_scale
	sun.light_angular_distance = 2.0 # soft penumbras
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.directional_shadow_max_distance = 160.0
	# Cool bounce/fill from the opposite side so shadows read blue rather than grey.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, sun_rot.y + 180.0, 0)
	fill.light_color = fill_color
	fill.light_energy = fill_energy
	fill.light_specular = 0.2
	fill.shadow_enabled = false
	return [we, sun, fill]
