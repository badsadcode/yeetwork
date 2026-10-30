class_name Rain
extends Node3D
## Reusable rain around the local camera (visual and audio only, every peer on its own):
## falling streaks slanted by the wind, little splashes where the drops hit the ground,
## ripples on water, and the patter of rain. Add one to any map:
##   arena.add_child(Rain.create(intensity, wind))     (MapSettings.weather does this)
## intensity 0..1 (drizzle .. downpour), wind in m/s.

var intensity := 0.7
var wind := Vector3(4.0, 0.0, 1.2)
var _streaks: CPUParticles3D
var _splashes: CPUParticles3D
var _sound: AudioStreamPlayer
var _refresh := 0.0
var _rng := RandomNumberGenerator.new()


static func create(p_intensity := 0.7, p_wind := Vector3(4.0, 0.0, 1.2)) -> Rain:
	var r := Rain.new()
	r.name = "Rain"
	r.intensity = clampf(p_intensity, 0.05, 1.0)
	r.wind = p_wind
	return r


func _ready() -> void:
	top_level = true
	_rng.randomize()
	var low := Game.graphics == 0
	_streaks = CPUParticles3D.new()
	_streaks.amount = int((1100 if not low else 420) * intensity)
	_streaks.lifetime = 0.9
	_streaks.local_coords = false
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(22, 1, 22)
	var fall := Vector3(0, -24.0, 0) + wind
	_streaks.direction = fall.normalized()
	_streaks.spread = 2.0
	_streaks.initial_velocity_min = fall.length() * 0.9
	_streaks.initial_velocity_max = fall.length() * 1.1
	_streaks.gravity = Vector3.ZERO
	_streaks.particle_flag_align_y = true
	var m := BoxMesh.new()
	m.size = Vector3(0.016, 0.9, 0.016)
	_streaks.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.84, 0.95, 0.32)
	_streaks.material_override = mat
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streaks)
	_streaks.emitting = true
	# Splashes: tiny droplets bouncing up from points on the ground found by raycasts.
	_splashes = CPUParticles3D.new()
	_splashes.amount = int((160 if not low else 60) * intensity)
	_splashes.lifetime = 0.28
	_splashes.local_coords = false
	_splashes.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_splashes.direction = Vector3.UP
	_splashes.spread = 40.0
	_splashes.initial_velocity_min = 1.0
	_splashes.initial_velocity_max = 2.6
	_splashes.gravity = Vector3(0, -12, 0)
	var dm := SphereMesh.new()
	dm.radius = 0.025
	dm.height = 0.05
	dm.radial_segments = 4
	dm.rings = 2
	_splashes.mesh = dm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.85, 0.9, 1.0, 0.55)
	_splashes.material_override = smat
	_splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_splashes)
	_sound = AudioStreamPlayer.new()
	_sound.bus = "SFX"
	_sound.stream = Sfx.stream("rain")
	_sound.volume_db = lerpf(-22.0, -10.0, intensity)
	add_child(_sound)
	_sound.play()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Streaks spawn above and upwind of the camera so they fall through the view.
	_streaks.global_position = cam.global_position + Vector3(0, 12, 0) - wind * 0.5
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.4
	# Where drops land near the camera (first thing below a point high up): splash spots.
	var space := cam.get_world_3d().direct_space_state
	var pts := PackedVector3Array()
	for i in 48:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 14.0
		var top := cam.global_position + Vector3(cos(a) * r, 25.0, sin(a) * r)
		var q := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 60.0, Game.L_WORLD)
		var hit := space.intersect_ray(q)
		var p: Vector3
		if not hit.is_empty():
			p = hit.position
		else:
			var liq := Liquid.at(top - Vector3(0, 25, 0), 30.0)
			if liq == null:
				continue
			p = Vector3(top.x, liq.height_at(top.x, top.z), top.z)
		pts.append(p + Vector3.UP * 0.03)
	if pts.is_empty():
		_splashes.emitting = false
		return
	_splashes.global_transform = Transform3D.IDENTITY
	_splashes.emission_points = pts
	_splashes.emitting = true
