@tool
class_name MapEnvironment
extends RefCounted
## Lighting presets shared by built-in and custom maps: a cinematic stylized look with a
## warm key sun, cool fill, soft GI bounce (SDFGI + SSIL), soft AO and AgX tonemapping.
##   sunset - warm golden hour (default)      day   - bright, saturated, blue sky
##   night  - cool moonlight, deep blue sky   space - starfield, nebula and a planet
##   halloween - purple dusk, orange horizon, big moon, thick fog (spooky mode)
##   tropical  - deep blue sky, turquoise horizon, islands and big white clouds
##   desert    - warm haze, high sun, mesas and dunes, few clouds
##   snow      - cool bright light, snowy peaks and pine forests
##   volcano   - smoky red sky, ash clouds, a glowing volcano on the horizon
##   storm     - dark slate sky, low heavy clouds, grey haze, dim cool light (High Seas: Storm)

## Every environment a map can pick (MapSettings.sky), in menu order.
const PRESETS := ["sunset", "day", "tropical", "desert", "snow", "volcano", "storm", "night", "space"]

## Clouds per environment: [count at full quality, altitude, lit colour, shaded colour,
## optional size].
const CLOUDS := {
	"day": [26, 110.0, Color(1.0, 1.0, 1.0), Color(0.62, 0.7, 0.88)],
	"sunset": [22, 100.0, Color(1.0, 0.82, 0.7), Color(0.55, 0.45, 0.7)],
	"tropical": [30, 120.0, Color(1.0, 1.0, 1.0), Color(0.6, 0.74, 0.92)],
	"desert": [8, 170.0, Color(1.0, 0.94, 0.86), Color(0.82, 0.72, 0.66)],
	"snow": [30, 90.0, Color(0.96, 0.97, 1.0), Color(0.6, 0.65, 0.78)],
	"volcano": [26, 90.0, Color(0.42, 0.3, 0.28), Color(0.12, 0.08, 0.09)],
	"storm": [46, 62.0, Color(0.5, 0.53, 0.6), Color(0.13, 0.15, 0.2), 1.9],
	"night": [16, 110.0, Color(0.36, 0.4, 0.6), Color(0.12, 0.14, 0.26)],
	"halloween": [18, 100.0, Color(0.48, 0.36, 0.62), Color(0.15, 0.1, 0.22)],
}


## Quality options (Game.gfx) on top of a preset. Without full GI the ambient light gets a
## little boost so the look stays bright; without volumetric fog, spooky maps keep a haze.
static func apply_quality(env: Environment, preset: String) -> void:
	var g: Dictionary = Game.gfx if not Game.gfx.is_empty() else Game.GFX_PRESETS[2]
	env.sdfgi_enabled = g.gi >= 2
	env.ssil_enabled = g.gi >= 1
	env.ssao_enabled = g.ssao
	env.ssao_detail = 0.3 if g.gi >= 2 else 0.0
	env.glow_enabled = g.glow
	# Brightness (Options → Display): an exposure multiplier.
	env.tonemap_exposure = float(env.get_meta("exposure", env.tonemap_exposure)) * Game.brightness
	if not env.has_meta("exposure"):
		env.set_meta("exposure", env.tonemap_exposure / Game.brightness)
	var fog_d: float = env.get_meta("vol_fog", env.volumetric_fog_density)
	env.set_meta("vol_fog", fog_d)
	env.volumetric_fog_enabled = g.fog and fog_d > 0.0
	var amb: float = env.get_meta("ambient", env.ambient_light_energy)
	env.set_meta("ambient", amb)
	env.ambient_light_energy = amb * (1.0 if g.gi >= 2 else 1.25)
	var depth_fog: float = env.get_meta("depth_fog", env.fog_density)
	env.set_meta("depth_fog", depth_fog)
	env.fog_density = depth_fog
	if not g.fog and preset in ["halloween", "night"]:
		env.fog_density = maxf(depth_fog, 0.012) # keep the spooky haze without volumetrics


## Sun shadow quality from Game.gfx (shadows: 0 off, 1 low, 2 high).
static func apply_sun(sun: DirectionalLight3D) -> void:
	var s: int = Game.gfx.get("shadows", 2)
	sun.shadow_enabled = s > 0
	sun.directional_shadow_max_distance = 160.0 if s >= 2 else 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if s >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


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
		"halloween":
			# Purple dusk, orange glow on the horizon and a huge pale moon (the sky's sun disc).
			sky_mat.sky_top_color = Color(0.08, 0.03, 0.16)
			sky_mat.sky_horizon_color = Color(0.85, 0.35, 0.15)
			sky_mat.ground_horizon_color = Color(0.4, 0.15, 0.2)
			sky_mat.ground_bottom_color = Color(0.03, 0.02, 0.05)
			sky_mat.sky_curve = 0.2
			sky_mat.sun_angle_max = 4.0
			sky_mat.sun_curve = 0.02
			sun_color = Color(1.0, 0.72, 0.45)
			sun_energy = 1.1
			fill_color = Color(0.5, 0.3, 0.9)
			fill_energy = 0.35
		"tropical":
			sky_mat.sky_top_color = Color(0.08, 0.38, 0.92)
			sky_mat.sky_horizon_color = Color(0.62, 0.9, 1.0)
			sky_mat.ground_horizon_color = Color(0.55, 0.85, 0.92)
			sky_mat.ground_bottom_color = Color(0.1, 0.35, 0.5)
			sun_color = Color(1.0, 0.96, 0.86)
			sun_energy = 2.8
			fill_color = Color(0.45, 0.8, 1.0)
		"desert":
			sky_mat.sky_top_color = Color(0.3, 0.52, 0.88)
			sky_mat.sky_horizon_color = Color(1.0, 0.86, 0.62)
			sky_mat.ground_horizon_color = Color(0.98, 0.78, 0.52)
			sky_mat.ground_bottom_color = Color(0.62, 0.45, 0.3)
			sun_color = Color(1.0, 0.86, 0.66)
			sun_energy = 3.0
			fill_color = Color(0.7, 0.75, 1.0)
		"snow":
			sky_mat.sky_top_color = Color(0.42, 0.58, 0.86)
			sky_mat.sky_horizon_color = Color(0.86, 0.91, 0.98)
			sky_mat.ground_horizon_color = Color(0.9, 0.93, 1.0)
			sky_mat.ground_bottom_color = Color(0.7, 0.75, 0.85)
			sun_color = Color(1.0, 0.95, 0.9)
			sun_energy = 2.2
			fill_color = Color(0.6, 0.72, 1.0)
			fill_energy = 0.4
		"volcano":
			sky_mat.sky_top_color = Color(0.2, 0.1, 0.14)
			sky_mat.sky_horizon_color = Color(0.85, 0.4, 0.22)
			sky_mat.ground_horizon_color = Color(0.4, 0.14, 0.08)
			sky_mat.ground_bottom_color = Color(0.08, 0.04, 0.04)
			sky_mat.sun_angle_max = 8.0
			sun_color = Color(1.0, 0.68, 0.45)
			sun_energy = 2.0
			fill_color = Color(1.0, 0.35, 0.2)
			fill_energy = 0.45
		"storm":
			sky_mat.sky_top_color = Color(0.15, 0.18, 0.24)
			sky_mat.sky_horizon_color = Color(0.4, 0.45, 0.52)
			sky_mat.ground_horizon_color = Color(0.32, 0.37, 0.43)
			sky_mat.ground_bottom_color = Color(0.1, 0.12, 0.16)
			sky_mat.sky_curve = 0.25
			sky_mat.sun_angle_max = 2.0
			sun_color = Color(0.78, 0.84, 0.95)
			sun_energy = 0.8
			fill_color = Color(0.5, 0.6, 0.8)
			fill_energy = 0.45
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
		"halloween":
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.42, 0.3, 0.6)
			env.ambient_light_energy = 0.6 * amb_scale
			env.fog_light_color = Color(0.35, 0.2, 0.4)
			env.fog_density = 0.006
			env.volumetric_fog_density = 0.018
			env.volumetric_fog_albedo = Color(0.85, 0.7, 1.0)
			env.volumetric_fog_emission = Color(0.06, 0.02, 0.08)
			env.glow_intensity = 0.9
			env.adjustment_saturation = 1.3
		"day":
			env.volumetric_fog_density = 0.001
			env.adjustment_saturation = 1.15
		"tropical":
			env.volumetric_fog_density = 0.0008
			env.fog_light_color = Color(0.7, 0.88, 1.0)
			env.adjustment_saturation = 1.25
		"desert":
			env.fog_light_color = Color(1.0, 0.85, 0.65)
			env.fog_density = 0.0016
			env.volumetric_fog_density = 0.003
			env.volumetric_fog_albedo = Color(1.0, 0.85, 0.7)
			env.adjustment_saturation = 1.15
		"snow":
			env.ambient_light_energy = 0.75 * amb_scale
			env.fog_light_color = Color(0.85, 0.9, 1.0)
			env.fog_density = 0.0008
			env.volumetric_fog_density = 0.0018
			env.volumetric_fog_albedo = Color(0.9, 0.94, 1.0)
		"storm":
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.5, 0.56, 0.66)
			env.ambient_light_energy = 0.75 * amb_scale
			env.fog_light_color = Color(0.36, 0.41, 0.48)
			env.fog_density = 0.0055
			env.fog_sky_affect = 0.35
			env.volumetric_fog_density = 0.008
			env.volumetric_fog_albedo = Color(0.7, 0.75, 0.82)
			env.adjustment_saturation = 0.95
			env.adjustment_contrast = 1.15
		"volcano":
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.62, 0.46, 0.46)
			env.ambient_light_energy = 0.7 * amb_scale
			env.fog_light_color = Color(0.5, 0.28, 0.22)
			env.fog_density = 0.0018
			env.volumetric_fog_density = 0.005
			env.volumetric_fog_albedo = Color(0.75, 0.55, 0.5)
			env.volumetric_fog_emission = Color(0.04, 0.01, 0.0)
			env.glow_intensity = 0.8
	apply_quality(env, preset)
	var we := WorldEnvironment.new()
	we.environment = env

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_color
	sun.light_energy = sun_energy * sun_scale
	sun.light_angular_distance = 2.0 # soft penumbras
	sun.shadow_blur = 1.8
	apply_sun(sun)
	# Cool bounce/fill from the opposite side so shadows read blue rather than grey.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, sun_rot.y + 180.0, 0)
	fill.light_color = fill_color
	fill.light_energy = fill_energy
	fill.light_specular = 0.2
	fill.shadow_enabled = false
	return [we, sun, fill]
