class_name Arena
extends Node3D
## Arena geometry built in code so every peer produces identical geometry (destructible
## ids must match across the network). Maps:
##   0 "Yeetwork Prime": walled, vertical 90s arena around an acid pit.
##   1 "Facing Yeets":   two towers facing each other on an asteroid strip in space.
##
## Architectural language:
##   slate floors / lavender walls  = solid structure
##   cream panels                   = breakable (walls, bridges, tunnel roofs)
##   green glow                     = movement aids (jump pads, lifts)
##   acid green pit                 = hazard
##   red (west) / blue (east)       = team bases

const C_FLOOR := Color(0.42, 0.47, 0.62)
const C_WALL := Color(0.78, 0.7, 0.86)
const C_STEEL := Color(0.5, 0.62, 0.8)
const C_BREAK := Color(0.95, 0.86, 0.66)
const C_TOWER := Color(1.0, 0.74, 0.25)
const C_PIT := Color(0.26, 0.28, 0.36)
const C_PAD := Color(0.35, 1.0, 0.55)
const C_ACID := Color(0.45, 1.0, 0.2)

var world: Node
var destructibles: Array[Destructible] = []
var spawn_points := {0: [], 1: [], 2: []}
var flag_stands := {} # team -> Vector3 (base of the flag)
var initial_props: Array = [] # [kind, Transform3D]
var kill_y := -45.0
var avoid_rects: Array[Rect2] = [] # XZ areas bots should route around
var _spinners: Array[Node3D] = []


func build(p_world: Node, map_id: int) -> void:
	world = p_world
	name = "Arena"
	if map_id == 1:
		MapFacing.build(self)
		return
	avoid_rects.append(Rect2(-15.5, -15.5, 31, 31))
	_environment()
	_floor_and_pit()
	_outer_walls()
	_tower()
	_bridges()
	for s in [-1, 1]:
		_base(s)
	for sz in [-1, 1]:
		_side_lane(sz)
	_landmarks()
	_props()


func _process(delta: float) -> void:
	for n in _spinners:
		n.rotate_object_local(Vector3.UP, delta * 0.4)


# --- Builders -------------------------------------------------------------------

func box(center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY, emission := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, center)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.world(color, 0.7, 0.0, emission)
	body.add_child(mi)
	add_child(body)
	return body


## A slab whose top surface runs from `from` to `to` (both on the top centerline).
func ramp(from: Vector3, to: Vector3, width: float, thickness: float, color: Color) -> StaticBody3D:
	var dir := (to - from)
	var x := dir.normalized()
	var side := x.cross(Vector3.UP).normalized()
	var y := side.cross(x).normalized()
	var z := x.cross(y)
	var basis := Basis(x, y, z)
	var center := (from + to) * 0.5 - y * thickness * 0.5
	return box(center, Vector3(dir.length(), thickness, width), color, basis)


func glow_strip(center: Vector3, size: Vector3, color: Color, energy := 2.5) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = center
	mi.material_override = Mats.glow(color, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func light(pos: Vector3, color: Color, range_m: float, energy := 2.0, shadows := false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_m
	l.light_energy = energy
	l.shadow_enabled = shadows
	add_child(l)


func breakable(center: Vector3, basis: Basis, nx: int, ny: int, cell: Vector2, thickness: float, anchors: Array, color := C_BREAK, hp := 100.0) -> Destructible:
	var d := Destructible.new()
	d.transform = Transform3D(basis, center)
	add_child(d)
	d.setup(destructibles.size(), nx, ny, cell, thickness, color, anchors, hp)
	destructibles.append(d)
	return d


func jump_pad(pos: Vector3, velocity: Vector3) -> void:
	var t := TriggerVolume.new()
	t.position = pos + Vector3(0, 0.6, 0)
	add_child(t)
	t.setup(TriggerVolume.Kind.JUMP_PAD, Vector3(2.4, 1.2, 2.4), velocity)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.3
	cm.height = 0.2
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.1, 0)
	mi.material_override = Mats.glow(C_PAD, 2.5)
	add_child(mi)
	var arrow := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = 0.5
	am.height = 0.6
	arrow.mesh = am
	arrow.position = pos + Vector3(0, 0.6, 0)
	arrow.material_override = Mats.glow(C_PAD.lightened(0.4), 3.0)
	add_child(arrow)
	light(pos + Vector3(0, 1.5, 0), C_PAD, 6.0, 1.5)


func lift(a: Vector3, b: Vector3, period: float, phase: float) -> void:
	var l := Lift.new()
	add_child(l)
	l.setup(world, a, b, Vector3(3, 0.5, 3), period, phase, C_STEEL)


func breakable_basis_floor_x() -> Basis:
	# Grid X -> world X, grid Y -> world -Z, thickness -> world Y.
	return Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))


func breakable_basis_floor_z() -> Basis:
	# Grid X -> world Z, grid Y -> world X, thickness -> world Y.
	return Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


func breakable_basis_wall_x() -> Basis:
	# A wall facing along X: grid X -> world Z.
	return Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))


# --- Layout ---------------------------------------------------------------------

func _environment(space := false) -> void:
	# Cinematic stylized lighting: warm key sun, cool sky fill, soft GI bounce.
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.92)
	sky_mat.sky_horizon_color = Color(1.0, 0.74, 0.55)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.95, 0.72, 0.62)
	sky_mat.ground_bottom_color = Color(0.25, 0.28, 0.45)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	sky_mat.sky_energy_multiplier = 1.0
	sky.sky_material = sky_mat
	if space:
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://scripts/world/space_sky.gdshader")
		sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
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
	if space:
		# Space is dark: rely on a tinted ambient so shadows stay readable and cool.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.45, 0.42, 0.75)
		env.ambient_light_energy = 0.7
		env.fog_enabled = false
		env.volumetric_fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.light_energy = 2.4
	sun.light_angular_distance = 2.0 # soft penumbras
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	# Cool bounce/fill from the opposite side so shadows read blue rather than grey.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 38 + 180, 0)
	fill.light_color = Color(0.55, 0.7, 1.0)
	fill.light_energy = 0.25
	fill.light_specular = 0.2
	fill.shadow_enabled = false
	add_child(fill)


func _floor_and_pit() -> void:
	box(Vector3(-39, -1, 0), Vector3(50, 2, 80), C_FLOOR)
	box(Vector3(39, -1, 0), Vector3(50, 2, 80), C_FLOOR)
	box(Vector3(0, -1, 27), Vector3(28, 2, 26), C_FLOOR)
	box(Vector3(0, -1, -27), Vector3(28, 2, 26), C_FLOOR)
	# Pit: 28x28, 8 m deep, filled with bouncy acid.
	box(Vector3(0, -9, 0), Vector3(28, 2, 28), C_PIT)
	box(Vector3(-15, -5, 0), Vector3(2, 6, 28), C_PIT)
	box(Vector3(15, -5, 0), Vector3(2, 6, 28), C_PIT)
	box(Vector3(0, -5, -15), Vector3(32, 6, 2), C_PIT)
	box(Vector3(0, -5, 15), Vector3(32, 6, 2), C_PIT)
	# Glowing pit rim.
	for s in [-1, 1]:
		glow_strip(Vector3(s * 14.0, 0.03, 0), Vector3(0.3, 0.06, 28.3), C_ACID, 2.0)
		glow_strip(Vector3(0, 0.03, s * 14.0), Vector3(28.3, 0.06, 0.3), C_ACID, 2.0)
	var acid := TriggerVolume.new()
	acid.position = Vector3(0, -7.0, 0)
	add_child(acid)
	acid.setup(TriggerVolume.Kind.ACID, Vector3(28, 2.2, 28), Vector3.ZERO, 22.0)
	var surface := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(28, 28)
	surface.mesh = pm
	surface.position = Vector3(0, -6.4, 0)
	var acid_mat := StandardMaterial3D.new()
	acid_mat.albedo_color = Color(0.4, 1.0, 0.2, 0.75)
	acid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	acid_mat.emission_enabled = true
	acid_mat.emission = C_ACID
	acid_mat.emission_energy_multiplier = 1.4
	acid_mat.roughness = 0.05
	acid_mat.albedo_texture = Mats.grid_texture()
	acid_mat.uv1_scale = Vector3(7, 7, 7)
	surface.material_override = acid_mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	light(Vector3(0, -3, 0), C_ACID, 22.0, 3.0)


func _outer_walls() -> void:
	box(Vector3(-65, 14, 0), Vector3(2, 32, 84), C_WALL)
	box(Vector3(65, 14, 0), Vector3(2, 32, 84), C_WALL)
	box(Vector3(0, 14, -41), Vector3(132, 32, 2), C_WALL)
	box(Vector3(0, 14, 41), Vector3(132, 32, 2), C_WALL)
	# Horizontal neon bands give a sense of height and speed.
	for y in [4.0, 14.0, 24.0]:
		for s in [-1, 1]:
			glow_strip(Vector3(s * 63.95, y, 0), Vector3(0.1, 0.25, 80), Color(1.0, 0.62, 0.8), 1.0)
			glow_strip(Vector3(0, y, s * 39.95), Vector3(128, 0.25, 0.1), Color(1.0, 0.62, 0.8), 1.0)


func _tower() -> void:
	box(Vector3(0, 4, 0), Vector3(6, 24, 6), C_TOWER)
	box(Vector3(0, 15.75, 0), Vector3(9, 0.5, 9), C_TOWER.darkened(0.15))
	# Ring platform around the tower at y = 6.
	box(Vector3(0, 5.5, 5.5), Vector3(16, 1, 5), C_STEEL)
	box(Vector3(0, 5.5, -5.5), Vector3(16, 1, 5), C_STEEL)
	box(Vector3(5.5, 5.5, 0), Vector3(5, 1, 6), C_STEEL)
	box(Vector3(-5.5, 5.5, 0), Vector3(5, 1, 6), C_STEEL)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(Vector3(sx * 7.0, -1.0, sz * 7.0), Vector3(1, 14, 1), C_STEEL.darkened(0.2))
			jump_pad(Vector3(sx * 5.5, 6.0, sz * 5.5), Vector3(-sx * 3.5, 24.0, -sz * 3.5))
	light(Vector3(0, 19, 0), C_TOWER, 18.0, 2.5, true)
	for i in 4:
		var a := i * PI * 0.5
		glow_strip(Vector3(cos(a) * 3.02, 4.0, sin(a) * 3.02), Vector3(0.12, 23.8, 0.12), Color(1, 0.9, 0.5), 3.0)
		spawn_points[0].append(Vector3(cos(a) * 3.0, 16.3, sin(a) * 3.0))


func _bridges() -> void:
	# East/west bridges link the ring to each base; north/south link it to the balconies.
	for s in [-1, 1]:
		breakable(Vector3(s * 22.0, 5.75, 0), breakable_basis_floor_x(), 28, 4, Vector2(1, 1), 0.5, ["left", "right"], Color(0.35, 0.85, 0.8), 70.0)
		breakable(Vector3(0, 5.75, s * 17.0), breakable_basis_floor_z(), 18, 4, Vector2(1, 1), 0.5, ["left", "right"], Color(0.35, 0.85, 0.8), 70.0)


func _base(s: int) -> void:
	var team := Game.TEAM_RED if s < 0 else Game.TEAM_BLUE
	var tc := Game.team_color(team)
	# Deck over a hall.
	box(Vector3(s * 50.0, 5.5, 0), Vector3(28, 1, 24), tc.lerp(C_FLOOR, 0.55))
	# Breakable hall walls: shortcuts from the ramps straight into the hall.
	for sz in [-1, 1]:
		breakable(Vector3(s * 51.0, 2.5, sz * 11.5), Basis.IDENTITY, 13, 5, Vector2(2, 1), 1.0, ["bottom", "top"])
	glow_strip(Vector3(s * 36.02, 5.5, 0), Vector3(0.1, 0.3, 24), tc, 3.0)
	# Breakable window wall at the deck front with low parapets either side.
	breakable(Vector3(s * 37.0, 7.5, 0), breakable_basis_wall_x(), 12, 3, Vector2(1, 1), 0.5, ["bottom"])
	box(Vector3(s * 37.0, 6.5, 9), Vector3(1, 1, 6), C_WALL)
	box(Vector3(s * 37.0, 6.5, -9), Vector3(1, 1, 6), C_WALL)
	# Ramps up to the deck on both flanks.
	for sz in [-1, 1]:
		ramp(Vector3(s * 34.0, 0, sz * 15.0), Vector3(s * 56.0, 6, sz * 15.0), 6, 0.6, C_STEEL)
		box(Vector3(s * 60.0, 5.5, sz * 15.0), Vector3(8, 1, 6), C_STEEL)
		box(Vector3(s * 60.0, 12, sz * 10.0), Vector3(3, 12, 3), C_WALL)
		glow_strip(Vector3(s * 60.0, 12, sz * 8.48), Vector3(0.4, 11, 0.06), tc, 3.5)
		light(Vector3(s * 58.0, 14, sz * 8.0), tc, 16.0, 2.0)
	# Hall lighting.
	light(Vector3(s * 44.0, 3.8, 0), tc.lerp(Color.WHITE, 0.5), 14.0, 2.2)
	light(Vector3(s * 56.0, 3.8, 0), Color(1, 0.9, 0.8), 12.0, 1.6)
	glow_strip(Vector3(s * 50.0, 4.98, 0), Vector3(20, 0.04, 0.3), tc.lerp(Color.WHITE, 0.6), 3.0)
	# Flag stand.
	var stand := Vector3(s * 52.0, 6.0, 0)
	flag_stands[team] = stand + Vector3(0, 0.4, 0)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.6
	cm.height = 0.4
	ped.mesh = cm
	ped.position = stand + Vector3(0, 0.2, 0)
	ped.material_override = Mats.glow(tc, 2.0)
	add_child(ped)
	light(stand + Vector3(0, 3, 0), tc, 10.0, 2.5)
	# Spawns on the deck and in the hall.
	for i in 6:
		var z := -8.0 + i * 3.2
		spawn_points[team].append(Vector3(s * 46.0, 6.2, z))
		spawn_points[team].append(Vector3(s * 50.0, 0.2, z))
		if i % 2 == 0:
			spawn_points[0].append(Vector3(s * 48.0, 0.2, z))
	# A jump pad that fires you straight through the deck's window wall.
	for sz in [-1, 1]:
		jump_pad(Vector3(s * 30.0, 0, sz * 4.5), Vector3(s * 10.0, 17.0, 0))


func _side_lane(sz: int) -> void:
	# Balcony with breakable bridge to the ring and ramps down to the floor.
	box(Vector3(0, 5.5, sz * 29.0), Vector3(20, 1, 6), C_STEEL)
	for sx in [-1, 1]:
		ramp(Vector3(sx * 10.0, 6, sz * 29.0), Vector3(sx * 22.0, 0, sz * 29.0), 6, 0.6, C_STEEL)
		box(Vector3(sx * 9.5, 2.5, sz * 31.5), Vector3(1, 5, 1), C_STEEL.darkened(0.2))
	# Quarter pipe against the outer wall for slope boosting.
	var pts := []
	for i in 4:
		var phi := deg_to_rad(i * 30.0)
		pts.append(Vector3(0, 8.0 - 8.0 * cos(phi), sz * (32.0 + 8.0 * sin(phi))))
	for i in 3:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		ramp(a + Vector3(0, 0, 0), b, 24, 0.8, C_WALL.lightened(0.1))
	spawn_points[0].append(Vector3(0, 6.2, sz * 29.0))
	# Breakable lane walls (also good for wall running).
	for sx in [-1, 1]:
		breakable(Vector3(sx * 25.0, 4, sz * 20.0), Basis.IDENTITY, 9, 4, Vector2(2, 2), 0.8, ["bottom"])
		# Solid wall-run panels near the pit.
		box(Vector3(sx * 25.0, 2.5, sz * 8.0), Vector3(14, 5, 0.8), C_STEEL)
		glow_strip(Vector3(sx * 25.0, 5.02, sz * 8.0), Vector3(14, 0.06, 0.82), Color(0.5, 0.8, 1.0), 2.0)
		# Tunnels with breakable roofs.
		box(Vector3(sx * 30.0, 2, sz * 27.5), Vector3(12, 4, 1), C_WALL)
		box(Vector3(sx * 30.0, 2, sz * 32.5), Vector3(12, 4, 1), C_WALL)
		breakable(Vector3(sx * 30.0, 4.25, sz * 30.0), breakable_basis_floor_x(), 6, 3, Vector2(2, 2), 0.5, ["left", "right"])
		light(Vector3(sx * 30.0, 2.5, sz * 30.0), Color(1.0, 0.75, 0.5), 9.0, 1.8)
		# Catwalk along the outer wall, served by a lift.
		box(Vector3(sx * 27.0, 9.5, sz * 38.0), Vector3(26, 1, 4), C_STEEL)
		glow_strip(Vector3(sx * 27.0, 10.02, sz * 36.0), Vector3(26, 0.06, 0.1), Color(0.5, 0.8, 1.0), 2.0)
		lift(Vector3(sx * 42.0, 0.25, sz * 37.0), Vector3(sx * 42.0, 9.75, sz * 37.0), 9.0, 0.25 if sx * sz > 0 else 0.75)
		spawn_points[0].append(Vector3(sx * 27.0, 10.2, sz * 38.0))
		spawn_points[0].append(Vector3(sx * 30.0, 0.2, sz * 30.0))
		# Cover blocks.
		box(Vector3(sx * 22.0, 1.25, sz * 2.0 + sz * 12.0), Vector3(2.5, 2.5, 2.5), C_TOWER.lerp(C_WALL, 0.5))


func _landmarks() -> void:
	# The Yeet Orb floating above the tower.
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.5
	sm.height = 7.0
	orb.mesh = sm
	orb.position = Vector3(0, 30, 0)
	orb.material_override = Mats.glow(Color(1.0, 0.35, 0.75), 2.2)
	add_child(orb)
	var ring_pivot := Node3D.new()
	ring_pivot.position = orb.position
	ring_pivot.rotation_degrees = Vector3(20, 0, 15)
	add_child(ring_pivot)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 6.0
	tm.outer_radius = 6.6
	ring.mesh = tm
	ring.material_override = Mats.glow(Color(0.4, 0.9, 1.0), 2.5)
	ring_pivot.add_child(ring)
	_spinners.append(ring_pivot)
	light(orb.position, Color(1.0, 0.4, 0.8), 40.0, 4.0)
	# Corner obelisks.
	var cols := [Color(1, 0.5, 0.2), Color(0.5, 1, 0.4), Color(0.3, 0.8, 1), Color(0.9, 0.4, 1)]
	var i := 0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(Vector3(sx * 58.0, 9, sz * 36.0), Vector3(4, 18, 4), C_WALL.darkened(0.1))
			var cube := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.5, 2.5, 2.5)
			cube.mesh = bm
			cube.position = Vector3(sx * 58.0, 20.5, sz * 36.0)
			cube.rotation_degrees = Vector3(45, 45, 0)
			cube.material_override = Mats.glow(cols[i], 3.0)
			add_child(cube)
			light(cube.position, cols[i], 20.0, 2.0)
			i += 1


func _props() -> void:
	var p := initial_props
	for s in [-1, 1]:
		# Crate pyramid in the hall mouth.
		for x in 3:
			for z in 3 - x:
				p.append(["crate", Transform3D(Basis.IDENTITY, Vector3(s * (40.0 + z * 1.05), 0.5 + x * 1.0, -6.0 + x * 0.5))])
		for i in 3:
			p.append(["boom_barrel", Transform3D(Basis.IDENTITY, Vector3(s * 40.0, 0.6, 5.0 + i * 1.0))])
		p.append(["barrel", Transform3D(Basis.IDENTITY, Vector3(s * 44.0, 6.6, 9.0))])
		p.append(["barrel", Transform3D(Basis.IDENTITY, Vector3(s * 45.0, 6.6, 9.5))])
		p.append(["crate_big", Transform3D(Basis.IDENTITY, Vector3(s * 46.0, 6.9, -8.0))])
		p.append(["couch", Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(s * 55.0, 0.5, 0))])
		p.append(["tire", Transform3D(Basis.IDENTITY, Vector3(s * 30.0, 0.3, -12.0))])
		p.append(["tire", Transform3D(Basis.IDENTITY, Vector3(s * 30.0, 0.7, -12.0))])
		for sz in [-1, 1]:
			p.append(["anvil", Transform3D(Basis.IDENTITY, Vector3(s * 24.0, 10.3, sz * 38.0))])
			p.append(["plank", Transform3D(Basis.IDENTITY, Vector3(s * 30.0, 0.1, sz * 30.0))])
			p.append(["cone", Transform3D(Basis.IDENTITY, Vector3(s * 18.0, 0.4, sz * 12.0))])
			p.append(["cone", Transform3D(Basis.IDENTITY, Vector3(s * 19.0, 0.4, sz * 13.0))])
			p.append(["crate", Transform3D(Basis.IDENTITY, Vector3(s * 27.0, 0.5, sz * 17.0))])
			p.append(["crate", Transform3D(Basis.IDENTITY, Vector3(s * 28.2, 0.5, sz * 17.0))])
			p.append(["crate", Transform3D(Basis.IDENTITY, Vector3(s * 27.6, 1.5, sz * 17.0))])
	# Dodgeballs on the ring, beach balls on the balconies.
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		p.append(["ball", Transform3D(Basis.IDENTITY, Vector3(cos(a) * 6.5, 6.5, sin(a) * 6.5))])
	for sz in [-1, 1]:
		p.append(["beachball", Transform3D(Basis.IDENTITY, Vector3(4, 7.2, sz * 29.0))])
		p.append(["boom_barrel", Transform3D(Basis.IDENTITY, Vector3(-4, 6.6, sz * 29.0))])
		p.append(["crate", Transform3D(Basis.IDENTITY, Vector3(0, 0.5, sz * 22.0))])
		p.append(["crate_big", Transform3D(Basis.IDENTITY, Vector3(-6, 0.9, sz * 22.0))])
	p.append(["crate", Transform3D(Basis.IDENTITY, Vector3(0, 16.5, 0))])


func random_spawn(team: int, rng: RandomNumberGenerator) -> Vector3:
	var list: Array = spawn_points.get(team, [])
	if list.is_empty():
		list = spawn_points[0]
	return list[rng.randi() % list.size()]
