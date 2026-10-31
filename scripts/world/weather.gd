class_name Weather
extends Node3D
## Storm weather around the local camera (visual and audio only, every peer on its own):
## wisps of wind streaking past, spray bursting off the ship's hull, lightning (branching
## bolts striking in view, sheet lightning in the clouds) with thunder as late as sound
## would be, and heavy rain (Rain).

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
	add_child(Rain.create(0.9, WIND * 7.0))


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


## Lightning: now and then a bolt strikes somewhere in view (a branching channel from the
## clouds to the ground, flickering through a few re-strikes and lighting up the land around
## it), otherwise a sheet of light inside the clouds. The thunder arrives as late as sound
## would: distance / 343 m/s, a crack first when it's close, then the long rumble.
func _lightning() -> void:
	var cam := get_viewport().get_camera_3d()
	var bolt := cam != null and _rng.randf() < 0.65
	var dist := _rng.randf_range(250.0, 900.0) # sheet lightning: far off in the clouds
	var power := 0.45
	if bolt:
		dist = _rng.randf_range(70.0, 340.0)
		power = clampf(1.7 - dist / 260.0, 0.45, 1.5)
		_strike(cam, dist, power)
	var tw := create_tween()
	for k in [[2.4 * power, 0.05], [0.3, 0.08], [3.2 * power, 0.04], [0.8 * power, 0.07], [2.0 * power, 0.04], [0.0, 0.4]]:
		tw.tween_property(_flash, "light_energy", k[0], k[1])
	if _env:
		var base := _env.background_energy_multiplier
		var tw2 := create_tween()
		tw2.tween_property(_env, "background_energy_multiplier", base * (1.0 + 2.0 * power), 0.05)
		tw2.tween_property(_env, "background_energy_multiplier", base, 0.5)
	var delay := dist / 343.0
	get_tree().create_timer(delay).timeout.connect(func():
		if dist < 160.0:
			Sfx.play_ui("thunder_crack", -1.0 - dist / 40.0, _rng.randf_range(0.9, 1.1))
		Sfx.play_ui("thunder", clampf(-2.0 - dist / 70.0, -18.0, -2.0), _rng.randf_range(0.85, 1.1)))


## A bolt `dist` metres away around the camera (at angle `a` on the ground, radians;
## random when INF).
func _strike(cam: Camera3D, dist: float, power: float, a := INF) -> void:
	if a == INF:
		a = _rng.randf() * TAU
	var c := cam.global_position
	var at := Vector3(c.x + cos(a) * dist, 0.0, c.z + sin(a) * dist)
	var top := Vector3(at.x + _rng.randf_range(-25, 25), c.y + _rng.randf_range(70.0, 100.0), at.z + _rng.randf_range(-25, 25))
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, top.y, at.z), Vector3(at.x, c.y - 200.0, at.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	at.y = hit.position.y if not hit.is_empty() else c.y - 15.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main := _bolt_path(top, at, top.distance_to(at) * 0.11, 6)
	_ribbon(st, main, 1.1, c, 1.0)
	_ribbon(st, main, 7.0, c, 0.12) # the glow around it
	for b in _rng.randi_range(3, 7):
		var i := _rng.randi_range(4, int(main.size() * 0.7))
		var from: Vector3 = main[i]
		var down := (at - from).normalized()
		var out := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		var to := from + (down * 0.6 + out * 0.8).normalized() * top.distance_to(at) * _rng.randf_range(0.12, 0.32)
		var branch := _bolt_path(from, to, from.distance_to(to) * 0.15, 4)
		_ribbon(st, branch, 0.45, c, 0.75)
		_ribbon(st, branch, 3.0, c, 0.07)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _bolt_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	# The land around the strike lights up with it.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.78, 0.84, 1.0)
	glow.omni_range = 140.0
	glow.omni_attenuation = 1.4
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	add_child(glow)
	glow.global_position = at + Vector3.UP * 12.0
	# Flicker through re-strikes, then gone.
	var tw := create_tween()
	for k in [[true, 7.0 * power, 0.05], [false, 0.0, 0.07], [true, 9.0 * power, 0.04], [false, 1.0, 0.06], [true, 6.0 * power, 0.05], [false, 0.0, 0.12]]:
		tw.tween_callback(func():
			mi.visible = k[0]
			glow.light_energy = k[1])
		tw.tween_interval(k[2])
	tw.tween_callback(func():
		mi.queue_free()
		glow.queue_free())


## A jagged channel from a to b: midpoint displacement, `depth` times, halving the jag.
func _bolt_path(a: Vector3, b: Vector3, jag: float, depth: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	for d in depth:
		var np := PackedVector3Array([pts[0]])
		for j in pts.size() - 1:
			var p := pts[j]
			var q := pts[j + 1]
			var along := (q - p).normalized()
			var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
			var side2 := along.cross(side)
			np.append((p + q) * 0.5 + (side * _rng.randf_range(-1, 1) + side2 * _rng.randf_range(-1, 1)) * jag)
			np.append(q)
		pts = np
		jag *= 0.52
	return pts


## A strip of quads along the path, turned toward the camera; it thins toward its end.
func _ribbon(st: SurfaceTool, pts: PackedVector3Array, width: float, cam: Vector3, alpha: float) -> void:
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var view := (cam - (p + q) * 0.5).normalized()
		var taper := 1.0 - float(i) / pts.size() * 0.6
		var side := (q - p).cross(view).normalized() * width * 0.5 * taper
		var col := Color(0.85, 0.9, 1.0, alpha)
		for v in [p - side, p + side, q + side, p - side, q + side, q - side]:
			st.set_color(col)
			st.add_vertex(v)


func _bolt_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.7, 2.0) # (over 1: blooms)
	m.disable_fog = true # (it's seen through the storm's haze)
	return m


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
