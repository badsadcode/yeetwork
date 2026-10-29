class_name Weather
extends Node3D
## Storm weather around the local camera (visual and audio only, every peer on its own):
## wisps of wind streaking past, spray bursting off the ship's hull, and lightning that
## lights up everything for a moment, followed by thunder.

const WIND := Vector3(0.96, 0.0, 0.3) # matches the storm's wind (Liquid wind_angle 0.3)

var _wisps: CPUParticles3D
var _flash: DirectionalLight3D
var _env: Environment
var _next_bolt := 4.0
var _spray_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Weather"
	_rng.randomize()
	top_level = true
	_wisps = CPUParticles3D.new()
	_wisps.amount = 90 if Game.graphics != 0 else 40
	_wisps.lifetime = 1.4
	_wisps.local_coords = false
	_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wisps.emission_box_extents = Vector3(28, 9, 28)
	_wisps.direction = WIND
	_wisps.spread = 6.0
	_wisps.initial_velocity_min = 16.0
	_wisps.initial_velocity_max = 26.0
	_wisps.gravity = Vector3(0, -1.0, 0)
	_wisps.particle_flag_align_y = true # streaks lie along their motion
	var m := BoxMesh.new()
	m.size = Vector3(0.025, 2.6, 0.025)
	_wisps.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.88, 0.92, 1.0)
	_wisps.material_override = mat
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.3, Color(1, 1, 1, 0.22))
	g.add_point(0.7, Color(1, 1, 1, 0.16))
	_wisps.color_ramp = g
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wisps)
	_wisps.emitting = true
	_flash = DirectionalLight3D.new()
	_flash.rotation_degrees = Vector3(-70, 20, 0)
	_flash.light_color = Color(0.82, 0.88, 1.0)
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		# Upwind of the camera, so the streaks blow past and through the view.
		_wisps.global_position = cam.global_position - WIND * 10.0
	if _env == null:
		var we := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if we == null:
			for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				we = n
				break
		if we:
			_env = we.environment
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = _rng.randf_range(7.0, 16.0)
		_lightning()
	_hull_spray(delta)


## A double flash of cold light over everything, thunder a moment later.
func _lightning() -> void:
	var tw := create_tween()
	for k in [[2.6, 0.06], [0.3, 0.09], [3.4, 0.05], [0.0, 0.35]]:
		tw.tween_property(_flash, "light_energy", k[0], k[1])
	if _env:
		var base := _env.background_energy_multiplier
		var tw2 := create_tween()
		tw2.tween_property(_env, "background_energy_multiplier", base * 2.6, 0.06)
		tw2.tween_property(_env, "background_energy_multiplier", base, 0.4)
	var delay := _rng.randf_range(0.6, 2.2)
	get_tree().create_timer(delay).timeout.connect(func():
		Sfx.play_ui("boom", -10.0 - delay * 2.0, _rng.randf_range(0.28, 0.4))
		Sfx.play_ui("boom", -14.0, _rng.randf_range(0.2, 0.26)))


## Waves slamming into the ship's hull throw spray up over the side, mostly at the bow and
## on the windward side.
func _hull_spray(delta: float) -> void:
	var world := get_node_or_null("/root/Main/World")
	if world == null or world.arena == null or world.arena.carrier == null or world.fx == null:
		return
	_spray_t -= delta
	if _spray_t > 0.0:
		return
	_spray_t = _rng.randf_range(0.25, 0.7) if Game.graphics != 0 else _rng.randf_range(0.6, 1.4)
	var ship: Node3D = world.arena.carrier
	var bow := _rng.randf() < 0.45
	var local := Vector3(_rng.randf_range(62.0, 76.0), 1.5, _rng.randf_range(-12.0, 12.0)) if bow \
		else Vector3(_rng.randf_range(-60.0, 55.0), 1.2, -16.5) # windward (port) side
	var pos: Vector3 = ship.global_transform * local
	world.fx.spray(pos, WIND * 2.2 + Vector3.UP * 0.6, _rng.randf_range(1.4, 2.4))
