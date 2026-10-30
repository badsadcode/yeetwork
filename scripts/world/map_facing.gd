class_name MapFacing
extends RefCounted
## "Facing Yeets" — a love letter to UT's Facing Worlds: a long asteroid strip floating in
## space with two tall towers staring each other down. Falling off is death. Each tower
## has a breakable sniper window, launch shafts to the upper floor and the roof, and the
## flag on its ground floor. Breakable bridges span a chasm on each side of the center hill.

const C_GROUND := Color(0.64, 0.58, 0.74)
const C_ROCK := Color(0.42, 0.36, 0.52)
const C_STONE := Color(0.82, 0.78, 0.9)
const C_CRYSTAL := Color(0.55, 0.95, 1.0)


static func build(a: Arena) -> void:
	a.kill_y = -35.0
	a._environment(true)
	_strip(a)
	_center(a)
	for s in [-1, 1]:
		_tower(a, s)
		_approach(a, s)
	_props(a)


static func _strip(a: Arena) -> void:
	a.box(Vector3(0, -1.5, 0), Vector3(100, 3, 32), C_GROUND)
	a.box(Vector3(-71, -1.5, 0), Vector3(30, 3, 32), C_GROUND)
	a.box(Vector3(71, -1.5, 0), Vector3(30, 3, 32), C_GROUND)
	# Rocky underside so the strip reads as a floating asteroid.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var under := [
		[Vector3(0, -6, 0), Vector3(84, 6, 26)], [Vector3(0, -11, 1), Vector3(56, 6, 18)],
		[Vector3(-4, -16, -1), Vector3(26, 6, 10)], [Vector3(-71, -6, 0), Vector3(26, 6, 24)],
		[Vector3(71, -6, 0), Vector3(26, 6, 24)], [Vector3(-70, -11, 1), Vector3(14, 6, 12)],
		[Vector3(70, -11, -1), Vector3(14, 6, 12)],
	]
	for u in under:
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.08, 0.08)))
		a.box(u[0], u[1], C_ROCK, b)
	# Jagged rocks along the edges: walkable, and they make the silhouette less boxy.
	for i in 15:
		var x := -84.0 + i * 12.0 + rng.randf_range(-2, 2)
		for sz in [-1, 1]:
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3)))
			a.box(Vector3(x, -0.8, sz * 16.3), Vector3(rng.randf_range(3, 6), rng.randf_range(1.5, 2.8), rng.randf_range(2, 3.5)), C_ROCK.lightened(0.1), b)
	a.spawn_points[0].append_array([Vector3(-30, 0.2, 10), Vector3(30, 0.2, -10), Vector3(-12, 0.2, -12), Vector3(12, 0.2, 12), Vector3(0, 4.2, 0)])


static func _center(a: Arena) -> void:
	# Central hill with a plateau.
	a.ramp(Vector3(-17, 0, 0), Vector3(-4, 4, 0), 22, 1.0, C_GROUND.lightened(0.08))
	a.ramp(Vector3(17, 0, 0), Vector3(4, 4, 0), 22, 1.0, C_GROUND.lightened(0.08))
	a.box(Vector3(0, 3.5, 0), Vector3(8, 1, 22), C_GROUND.lightened(0.12))
	# Floating crystal landmark.
	var crystal := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 2.4, 2.4)
	crystal.mesh = bm
	crystal.material_override = Mats.glow(C_CRYSTAL, 2.5)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 13, 0)
	a.add_child(pivot)
	crystal.rotation = Vector3(PI * 0.25, 0, PI * 0.25)
	pivot.add_child(crystal)
	a._spinners.append(pivot)
	a.light(Vector3(0, 12, 0), C_CRYSTAL, 26.0, 3.0)
	for sz in [-1, 1]:
		a.jump_pad(Vector3(0, 4.0, sz * 8.5), Vector3(0, 20.0, -sz * 2.0))


static func _approach(a: Arena, s: int) -> void:
	# Chasm with a breakable bridge and narrow solid ledges along the edges.
	a.breakable(Vector3(s * 53.0, -0.25, 0), a.breakable_basis_floor_x(), Vector2(6, 6), 0.5, ["left", "right"], "wood", Color(0.85, 0.62, 0.4))
	for sz in [-1, 1]:
		a.box(Vector3(s * 53.0, -0.75, sz * 15.0), Vector3(6, 1.5, 2), C_ROCK.lightened(0.15))
	# Breakable cover walls in no-man's land.
	for sz in [-1, 1]:
		a.breakable(Vector3(s * 28.0, 1.5, sz * 7.0), a.breakable_basis_wall_x(), Vector2(6, 3), 0.6, ["bottom"], "brick", Color(0.92, 0.58, 0.45))
		a.box(Vector3(s * 40.0, 1.0, sz * 11.0), Vector3(3, 2, 3), C_STONE)
		# Pads near each tower fling you toward the center hill.
		a.jump_pad(Vector3(s * 45.0, 0, sz * 12.0), Vector3(-s * 13.0, 14.0, -sz * 2.0))


static func _tower(a: Arena, s: int) -> void:
	var team := Game.TEAM_RED if s < 0 else Game.TEAM_BLUE
	var tc := Game.team_color(team)
	var stone := C_STONE.lerp(tc, 0.25)
	# Shell.
	a.box(Vector3(s * 82.5, 21, 0), Vector3(1, 42, 15), stone)
	a.box(Vector3(s * 76.0, 21, 7.5), Vector3(13, 42, 1), stone)
	a.box(Vector3(s * 76.0, 21, -7.5), Vector3(13, 42, 1), stone)
	# Front wall: door, solid band, breakable sniper window, solid top.
	a.box(Vector3(s * 70.0, 3, -4.75), Vector3(1, 6, 4.5), stone)
	a.box(Vector3(s * 70.0, 3, 4.75), Vector3(1, 6, 4.5), stone)
	a.box(Vector3(s * 70.0, 5.25, 0), Vector3(1, 1.5, 5), stone)
	a.box(Vector3(s * 70.0, 10.5, 0), Vector3(1, 9, 14), stone)
	a.breakable(Vector3(s * 70.0, 17.5, 0), a.breakable_basis_wall_x(), Vector2(14, 5), 0.3, ["bottom", "top", "left", "right"], "glass")
	a.box(Vector3(s * 70.0, 31, 0), Vector3(1, 22, 14), stone)
	# Level 1 floor (top at y = 15) with a 4x4 shaft hole at (79, 4).
	a.box(Vector3(s * 76.25, 14.5, -2.5), Vector3(11.5, 1, 9), stone.darkened(0.1))
	a.box(Vector3(s * 73.75, 14.5, 4.5), Vector3(6.5, 1, 5), stone.darkened(0.1))
	a.box(Vector3(s * 81.5, 14.5, 4.5), Vector3(1, 1, 5), stone.darkened(0.1))
	a.box(Vector3(s * 79.0, 14.5, 6.5), Vector3(4, 1, 1), stone.darkened(0.1))
	# Roof (top at y = 42) with a shaft hole at (79, -4).
	a.box(Vector3(s * 76.0, 41.5, 2.5), Vector3(13, 1, 9), stone)
	a.box(Vector3(s * 73.25, 41.5, -4.75), Vector3(7.5, 1, 5.5), stone)
	a.box(Vector3(s * 81.75, 41.5, -4.75), Vector3(1.5, 1, 5.5), stone)
	a.box(Vector3(s * 79.0, 41.5, -6.75), Vector3(4, 1, 1.5), stone)
	# Battlements.
	a.box(Vector3(s * 69.8, 42.6, 0), Vector3(0.6, 1.2, 15), stone)
	a.box(Vector3(s * 76.0, 42.6, 7.7), Vector3(13, 1.2, 0.6), stone)
	a.box(Vector3(s * 76.0, 42.6, -7.7), Vector3(13, 1.2, 0.6), stone)
	# Facade ledge and rooftop corner pylons for a stronger silhouette.
	a.box(Vector3(s * 69.2, 14.5, 0), Vector3(1.0, 0.6, 15.4), stone.lightened(0.15))
	a.box(Vector3(s * 69.2, 41.5, 0), Vector3(1.0, 0.6, 15.4), stone.lightened(0.15))
	for corner in [Vector2(70.2, 7.2), Vector2(70.2, -7.2), Vector2(81.8, 7.2), Vector2(81.8, -7.2)]:
		a.box(Vector3(s * corner.x, 45.0, corner.y), Vector3(1.4, 6, 1.4), stone.lightened(0.1))
		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.6
		om.height = 1.2
		orb.mesh = om
		orb.position = Vector3(s * corner.x, 48.8, corner.y)
		orb.material_override = Mats.glow(tc, 3.0)
		a.add_child(orb)
	# Launch shafts.
	a.jump_pad(Vector3(s * 79.0, 0, 4), Vector3(-s * 2.0, 29.0, -2.0))
	a.jump_pad(Vector3(s * 79.0, 15, -4), Vector3(0, 42.0, 1.0))
	# Team trims, banner and lights.
	for sz in [-1, 1]:
		a.glow_strip(Vector3(s * 69.45, 21, sz * 7.05), Vector3(0.12, 42, 0.12), tc, 3.0)
	a.glow_strip(Vector3(s * 69.45, 24, 0), Vector3(0.1, 1.2, 12), tc, 2.5)
	a.glow_strip(Vector3(s * 69.45, 6.4, 0), Vector3(0.1, 0.3, 5.2), tc, 3.0)
	a.light(Vector3(s * 76.0, 4.5, 0), tc.lerp(Color.WHITE, 0.5), 14.0, 2.2)
	a.light(Vector3(s * 76.0, 19, 0), Color(1, 0.9, 0.8), 12.0, 1.6)
	a.light(Vector3(s * 76.0, 46, 0), tc, 22.0, 3.0)
	# Flag stand on the ground floor.
	var stand := Vector3(s * 76.0, 0.0, -3.5)
	a.flag_stands[team] = stand + Vector3(0, 0.4, 0)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.3
	cm.bottom_radius = 1.5
	cm.height = 0.4
	ped.mesh = cm
	ped.position = stand + Vector3(0, 0.2, 0)
	ped.material_override = Mats.glow(tc, 2.0)
	a.add_child(ped)
	ped.set_meta("mk_part", true) # (a Map Kit FlagStand makes its own)
	for i in 4:
		a.spawn_points[team].append(Vector3(s * (73.0 + i * 1.6), 0.2, 2.0))
		a.spawn_points[team].append(Vector3(s * (73.0 + i * 1.2), 15.2, -4.0 + i * 0.5))
		a.spawn_points[team].append(Vector3(s * 64.0, 0.2, -9.0 + i * 6.0))
	a.spawn_points[0].append(Vector3(s * 62.0, 0.2, 0))
	a.spawn_points[0].append(Vector3(s * 74.0, 15.2, -2.0))


static func _props(a: Arena) -> void:
	var p := a.initial_props
	var I := Basis.IDENTITY
	for s in [-1, 1]:
		for i in 3:
			p.append(["crate", Transform3D(I, Vector3(s * 62.0, 0.5 + i, 11.0))])
		p.append(["crate_big", Transform3D(I, Vector3(s * 60.0, 0.9, -11.0))])
		for i in 3:
			p.append(["boom_barrel", Transform3D(I, Vector3(s * 57.5, 0.6, -13.0 + i * 1.1))])
		p.append(["barrel", Transform3D(I, Vector3(s * 34.0, 0.6, 2.0))])
		p.append(["tire", Transform3D(I, Vector3(s * 22.0, 0.3, -12.0))])
		p.append(["plank", Transform3D(I, Vector3(s * 48.0, 0.1, 6.0))])
		p.append(["couch", Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(s * 77.0, 15.5, 0.0))])
		p.append(["crate", Transform3D(I, Vector3(s * 74.0, 15.5, 3.0))])
		# Anvils on the roof: for dropping on people, obviously.
		p.append(["anvil", Transform3D(I, Vector3(s * 72.0, 42.3, 3.0))])
		p.append(["anvil", Transform3D(I, Vector3(s * 72.0, 42.3, 5.0))])
		p.append(["boom_barrel", Transform3D(I, Vector3(s * 74.0, 42.6, 5.5))])
		for sz in [-1, 1]:
			p.append(["cone", Transform3D(I, Vector3(s * 50.0, 0.4, sz * 4.0))])
			p.append(["crate", Transform3D(I, Vector3(s * 30.0, 0.5, sz * 12.0))])
	for i in 6:
		p.append(["ball", Transform3D(I, Vector3(-2.5 + i, 4.5, -6.0 + (i % 2) * 12.0))])
	p.append(["beachball", Transform3D(I, Vector3(0, 5.2, 0))])
