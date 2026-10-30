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
var fire_areas: Array = [] # [Transform3D, size]: burning places (World sets things alight in them)
## A moving body the whole map rides on (High Seas' ship), or null. When set, spawn points,
## flag stands, initial props and props' home transforms are in its local space; use
## to_world() / xf_world() / flag_pos() to read them.
var carrier: Node3D
var _spinners: Array[Node3D] = []


func build(p_world: Node, map_key: String) -> void:
	world = p_world
	name = "Arena"
	if map_key == "facing":
		MapFacing.build(self)
		return
	if map_key.begins_with("highseas"):
		MapHighSeas.build(self, map_key)
		return
	if map_key.ends_with(".tscn") or map_key.ends_with(".scn"):
		_build_scene_map(map_key)
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


## A breakable slab of `size` meters (local X by local Y) and `thickness` along local Z.
func breakable(center: Vector3, basis: Basis, slab_size: Vector2, thickness: float, anchors: Array, material := "plaster", color := C_BREAK, hp_scale := 1.0) -> Destructible:
	var d := Destructible.new()
	d.transform = Transform3D(basis, center)
	add_child(d)
	d.setup(destructibles.size(), slab_size, thickness, color, anchors, material, hp_scale)
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


func lift(a: Vector3, b: Vector3, period: float, phase: float, size := Vector3(3, 0.5, 3)) -> void:
	var l := Lift.new()
	add_child(l)
	l.setup(world, a, b, size, period, phase, C_STEEL)


## Glowing team pedestal + flag base registration for Capture the Flag.
func flag_stand(team: int, stand: Vector3) -> void:
	var tc := Game.team_color(team)
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


## Liquid pool (acid, lava or water), kill volume, wind volume or a burning place (fire).
func hazard(kind: String, xf: Transform3D, size: Vector3, damage := 22.0, wind := Vector3.ZERO, fire_color := "orange") -> void:
	var t := TriggerVolume.new()
	t.transform = xf
	add_child(t)
	match kind:
		"kill":
			t.setup(TriggerVolume.Kind.KILL, size)
		"wind":
			t.setup(TriggerVolume.Kind.WIND, size, wind)
		"fire":
			# A burning place: World sets alight whoever and whatever stands in it.
			t.queue_free()
			Burning.area(self, xf, size, fire_color)
			fire_areas.append([xf, size])
		_:
			# Liquids: the surface sits 30% of the way up the box; the Liquid makes its own volume.
			t.queue_free()
			add_child(Liquid.create(kind, xf.origin + Vector3(0, size.y * 0.3, 0), Vector3(size.x, size.y * 0.8, size.z), damage))


# --- Scene maps (made with the Map Kit) ---------------------------------------------

func _build_scene_map(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Could not load map %s" % path)
		environment_preset("sunset")
		box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), C_FLOOR)
		spawn_points[0].append(Vector3(0, 0.2, 0))
		return
	var root := packed.instantiate()
	add_child(root)
	var settings := _find_settings(root)
	if settings:
		kill_y = settings.kill_height
		avoid_rects.assign(settings.avoid_areas)
		if settings.ocean:
			add_child(Liquid.create_ocean(settings.ocean_level, Game.sea_override if Game.sea_override != "" else settings.ocean_preset))
	if not _has_class(root, "WorldEnvironment") and not _has_class(root, "DirectionalLight3D"):
		environment_preset(settings.sky if settings else "sunset", settings)
	if settings and settings.weather == "rain":
		add_child(Rain.create(settings.rain_intensity, settings.rain_wind))
	elif settings and settings.weather == "storm" and not get_children().any(func(c: Node) -> bool: return c is Weather):
		add_child(Weather.new())
	_collect(root)


func _find_settings(n: Node) -> MapSettings:
	if n is MapSettings:
		return n
	for c in n.get_children():
		var s := _find_settings(c)
		if s:
			return s
	return null


func _has_class(n: Node, cls: String) -> bool:
	if n.is_class(cls):
		return true
	for c in n.get_children():
		if _has_class(c, cls):
			return true
	return false


## Converts Map Kit nodes into gameplay objects. Tree order is deterministic, so every
## peer assigns the same destructible ids.
func _collect(n: Node) -> void:
	for c in n.get_children():
		_collect(c)
	if n is BreakableSlab:
		var b := n as BreakableSlab
		breakable(b.global_position, b.slab_basis(), b.size, b.thickness, b.anchors(), b.material, b.color, b.hp_scale)
		b.queue_free()
	elif n is SpawnPoint:
		spawn_points[(n as SpawnPoint).team].append((n as Node3D).global_position + Vector3.UP * 0.2)
	elif n is FlagStand:
		flag_stand((n as FlagStand).team_id(), (n as Node3D).global_position)
	elif n is PropSpawn:
		var ps := n as PropSpawn
		initial_props.append([ps.kind, Transform3D(ps.global_transform.basis.orthonormalized(), ps.global_position)])
	elif n is JumpPadNode:
		var jp := n as JumpPadNode
		jump_pad(jp.global_position, jp.launch_velocity())
	elif n is LiftPlatform:
		var lp := n as LiftPlatform
		lift(lp.global_position, lp.global_position + lp.global_transform.basis * lp.travel, lp.period, lp.phase, lp.size)
	elif n is HazardVolume:
		var hv := n as HazardVolume
		hazard(hv.kind, Transform3D(hv.global_transform.basis.orthonormalized(), hv.global_position), hv.size, hv.damage, hv.wind, hv.fire_color)
	elif n is CSGShape3D:
		var csg := n as CSGShape3D
		if csg.is_root_shape() and csg.use_collision:
			csg.collision_layer = Game.L_WORLD
			csg.collision_mask = 0


## Problems a map author should fix. Needs a physics frame to have run.
func validate() -> Array[String]:
	var out: Array[String] = []
	if spawn_points[0].size() < 4:
		out.append("Only %d 'Any' spawn points (want 4+ for free-for-all)." % spawn_points[0].size())
	for t in [1, 2]:
		if spawn_points[t].is_empty():
			out.append("No %s spawn points (team modes will use 'Any' spawns)." % Game.TEAM_NAMES[t])
	if not flag_stands.has(1) or not flag_stands.has(2):
		out.append("CTF needs one Red and one Blue FlagStand.")
	var cells := 0
	for d in destructibles:
		cells += d.cells.size()
	if cells > 4000:
		out.append("%d breakable cells in total; above ~4000 performance suffers." % cells)
	var space := get_world_3d().direct_space_state
	var lowest := INF
	for team in spawn_points:
		for lp: Vector3 in spawn_points[team]:
			var p := to_world(lp)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 4.0, Game.L_WORLD)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				out.append("Spawn at %s has no floor within 4 m." % p.snapped(Vector3.ONE * 0.1))
			else:
				lowest = minf(lowest, hit.position.y)
			var params := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = 1.6
			params.shape = cap
			params.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.0)
			params.collision_mask = Game.L_WORLD
			if not space.intersect_shape(params, 1).is_empty():
				out.append("Spawn at %s is inside geometry." % p.snapped(Vector3.ONE * 0.1))
	if lowest < INF and kill_y > lowest - 3.0:
		out.append("kill_height %.1f is too close to the floor (lowest spawn floor %.1f)." % [kill_y, lowest])
	return out


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
	environment_preset("space" if space else "sunset")


func environment_preset(preset: String, settings: Node = null) -> void:
	# A stormy map keeps its storm (wind, lightning, rain) whatever sky the host picked.
	var storm := preset == "storm"
	if Game.sky_override != "" and preset != "space":
		preset = Game.sky_override # the host's environment pick wins over the spooky look
	elif Game.spooky and preset != "space":
		preset = "halloween"
	_scenery(preset, settings)
	if storm or preset == "storm":
		add_child(Weather.new())
	for n in MapEnvironment.build(preset, settings):
		add_child(n)
		if n is WorldEnvironment:
			var we := n as WorldEnvironment
			Game.settings_changed.connect(func():
				if is_instance_valid(we):
					MapEnvironment.apply_quality(we.environment, preset))
		elif n is DirectionalLight3D and (n as DirectionalLight3D).shadow_enabled:
			var sun := n as DirectionalLight3D
			Game.settings_changed.connect(func():
				if is_instance_valid(sun):
					MapEnvironment.apply_sun(sun))
	if Game.spooky:
		_spooky_extras()


## Distant scenery and clouds for the environment (Backdrop, Clouds).
func _scenery(preset: String, settings: Node) -> void:
	var base_y := -8.0
	if settings and settings.get("ocean"):
		base_y = float(settings.get("ocean_level"))
	var bd := Backdrop.build(preset, base_y)
	if bd:
		add_child(bd)
	var q: int = Game.gfx.get("clouds", 2)
	if q > 0 and MapEnvironment.CLOUDS.has(preset):
		var c: Array = MapEnvironment.CLOUDS[preset]
		var count := int(c[0]) if q >= 2 else int(c[0]) / 2
		var size: float = c[4] if c.size() > 4 else 1.0
		add_child(Clouds.create(count, c[1], 60.0 if preset == "storm" else 120.0, 650.0, c[2], c[3], size))


## Bats circling high above the action.
func _spooky_extras() -> void:
	for k in 3:
		var bats := CPUParticles3D.new()
		bats.amount = 14
		bats.lifetime = 9.0
		bats.preprocess = 9.0
		bats.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		bats.emission_sphere_radius = 18.0
		bats.direction = Vector3(1, 0.2, 0)
		bats.spread = 180.0
		bats.gravity = Vector3.ZERO
		bats.initial_velocity_min = 2.0
		bats.initial_velocity_max = 5.0
		bats.angular_velocity_min = -90.0
		bats.angular_velocity_max = 90.0
		bats.scale_amount_min = 0.7
		bats.scale_amount_max = 1.4
		var wing := PrismMesh.new()
		wing.size = Vector3(0.9, 0.25, 0.05)
		bats.mesh = wing
		bats.material_override = Mats.plastic(Color(0.06, 0.04, 0.08), 0.9)
		bats.position = Vector3((k - 1) * 30.0, 22.0 + k * 3.0, 0)
		add_child(bats)


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
	add_child(Liquid.create("acid", Vector3(0, -6.4, 0), Vector3(28, 1.6, 28), 22.0))


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
		breakable(Vector3(s * 22.0, 5.75, 0), breakable_basis_floor_x(), Vector2(28, 4), 0.5, ["left", "right"], "concrete", Color(0.35, 0.85, 0.8), 0.6)
		breakable(Vector3(0, 5.75, s * 17.0), breakable_basis_floor_z(), Vector2(18, 4), 0.5, ["left", "right"], "concrete", Color(0.35, 0.85, 0.8), 0.6)


func _base(s: int) -> void:
	var team := Game.TEAM_RED if s < 0 else Game.TEAM_BLUE
	var tc := Game.team_color(team)
	# Deck over a hall.
	box(Vector3(s * 50.0, 5.5, 0), Vector3(28, 1, 24), tc.lerp(C_FLOOR, 0.55))
	# Breakable hall walls: shortcuts from the ramps straight into the hall.
	for sz in [-1, 1]:
		breakable(Vector3(s * 51.0, 2.5, sz * 11.5), Basis.IDENTITY, Vector2(26, 5), 1.0, ["bottom", "top"], "brick", Color(0.92, 0.58, 0.45))
	glow_strip(Vector3(s * 36.02, 5.5, 0), Vector3(0.1, 0.3, 24), tc, 3.0)
	# Breakable window wall at the deck front with low parapets either side.
	breakable(Vector3(s * 37.0, 7.5, 0), breakable_basis_wall_x(), Vector2(12, 3), 0.25, ["bottom", "left", "right"], "glass")
	box(Vector3(s * 37.0, 6.5, 9), Vector3(1, 1, 6), C_WALL)
	box(Vector3(s * 37.0, 6.5, -9), Vector3(1, 1, 6), C_WALL)
	# Ramps up to the deck on both flanks.
	for sz in [-1, 1]:
		ramp(Vector3(s * 34.0, 0, sz * 15.0), Vector3(s * 56.0, 6, sz * 15.0), 6, 0.6, C_STEEL)
		box(Vector3(s * 60.0, 5.5, sz * 15.0), Vector3(8, 1, 6), C_STEEL)
		box(Vector3(s * 60.0, 12, sz * 10.0), Vector3(3, 12, 3), C_WALL)
		glow_strip(Vector3(s * 60.0, 12, sz * 8.48), Vector3(0.4, 11, 0.06), tc, 3.5)
		light(Vector3(s * 58.0, 14, sz * 8.0), tc, 16.0, 2.0)
	# Tough metal shutter hanging over the hall mouth: dents long before it breaks.
	breakable(Vector3(s * 36.6, 4.25, 0), breakable_basis_wall_x(), Vector2(22, 1.5), 0.3, ["top"], "metal", Color(0.6, 0.64, 0.72))
	# Hall lighting.
	light(Vector3(s * 44.0, 3.8, 0), tc.lerp(Color.WHITE, 0.5), 14.0, 2.2)
	light(Vector3(s * 56.0, 3.8, 0), Color(1, 0.9, 0.8), 12.0, 1.6)
	glow_strip(Vector3(s * 50.0, 4.98, 0), Vector3(20, 0.04, 0.3), tc.lerp(Color.WHITE, 0.6), 3.0)
	# Flag stand.
	flag_stand(team, Vector3(s * 52.0, 6.0, 0))
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
		breakable(Vector3(sx * 25.0, 4, sz * 20.0), Basis.IDENTITY, Vector2(18, 8), 0.8, ["bottom"])
		# Solid wall-run panels near the pit.
		box(Vector3(sx * 25.0, 2.5, sz * 8.0), Vector3(14, 5, 0.8), C_STEEL)
		glow_strip(Vector3(sx * 25.0, 5.02, sz * 8.0), Vector3(14, 0.06, 0.82), Color(0.5, 0.8, 1.0), 2.0)
		# Tunnels with breakable roofs.
		box(Vector3(sx * 30.0, 2, sz * 27.5), Vector3(12, 4, 1), C_WALL)
		box(Vector3(sx * 30.0, 2, sz * 32.5), Vector3(12, 4, 1), C_WALL)
		breakable(Vector3(sx * 30.0, 4.25, sz * 30.0), breakable_basis_floor_x(), Vector2(12, 6), 0.5, ["left", "right"], "wood", Color(0.85, 0.62, 0.4))
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
	if list.is_empty():
		for k in spawn_points:
			if not spawn_points[k].is_empty():
				list = spawn_points[k]
				break
	if list.is_empty():
		return Vector3(0, 2, 0)
	return to_world(list[rng.randi() % list.size()])


## A map position (carrier-local on a ship) in world space, right now.
func to_world(p: Vector3) -> Vector3:
	return carrier.global_transform * p if carrier else p


func xf_world(xf: Transform3D) -> Transform3D:
	return carrier.global_transform * xf if carrier else xf


## A world transform as a map transform (carrier-local on a ship).
func xf_local(xf: Transform3D) -> Transform3D:
	return carrier.global_transform.affine_inverse() * xf if carrier else xf


## Where a team's flag stand is now (world space).
func flag_pos(team: int) -> Vector3:
	return to_world(flag_stands.get(team, Vector3.ZERO))
