@tool
class_name Hoop
extends GoalZone
## A basketball hoop for YeetHoops: a pole, a backboard to bank shots off, a solid rim and a
## see-through net, the rim facing local +Z (turn it toward the court). Put the node on the
## floor at the end of the court. Team: the team that defends it (the other team scores
## here). A basket counts when the ball drops down through the rim. Shots from beyond the
## glowing arc on the floor (Three Range from the rim) are worth 3.

const RIM_HEIGHT := 3.6
const RIM_RADIUS := 0.62 # (the basketball is 0.32: a little room for gravity-gun chaos)
const BOARD := Vector3(2.2, 1.4, 0.1)

@export var three_range := 8.5:
	set(v):
		three_range = v
		_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var tc := Color(1.0, 0.32, 0.26) if team == 1 else Color(0.3, 0.55, 1.0) # (no autoloads in the editor)
	var white := Mats.plastic(Color(0.95, 0.95, 0.97), 0.3)
	var steel := Mats.plastic(Color(0.35, 0.37, 0.42), 0.35)
	var orange := Mats.plastic(Color(1.0, 0.45, 0.1), 0.3)
	var board_z := -RIM_RADIUS - 0.18
	var pole_z := board_z - 1.1
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Game.L_WORLD
	body.collision_mask = 0
	_parts.add_child(body)
	# Pole and the arm out to the board.
	var pole_h := RIM_HEIGHT + 0.5
	_parts.add_child(_cyl(0.12, pole_h, steel, Vector3(0, pole_h * 0.5, pole_z)))
	_shape(body, BoxShape3D.new(), Vector3(0.24, pole_h, 0.24), Vector3(0, pole_h * 0.5, pole_z))
	var arm_len := absf(board_z - pole_z)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.14, 0.14, arm_len), steel, Vector3(0, RIM_HEIGHT + 0.25, (board_z + pole_z) * 0.5)))
	# The backboard: white, a team-coloured frame and the target square over the rim.
	var board_c := Vector3(0, RIM_HEIGHT + BOARD.y * 0.5 - 0.25, board_z - BOARD.z * 0.5)
	_parts.add_child(PuzzleNode.box_mesh(BOARD, white, board_c))
	_shape(body, BoxShape3D.new(), BOARD, board_c)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = tc
	trim.emission_enabled = true
	trim.emission = tc
	trim.emission_energy_multiplier = 1.2
	for e in [[Vector3(BOARD.x, 0.07, 0.02), Vector3(0, BOARD.y * 0.5 - 0.035, 0)], [Vector3(BOARD.x, 0.07, 0.02), Vector3(0, -BOARD.y * 0.5 + 0.035, 0)],
			[Vector3(0.07, BOARD.y, 0.02), Vector3(BOARD.x * 0.5 - 0.035, 0, 0)], [Vector3(0.07, BOARD.y, 0.02), Vector3(-BOARD.x * 0.5 + 0.035, 0, 0)],
			[Vector3(0.62, 0.05, 0.02), Vector3(0, -0.02, 0)], [Vector3(0.62, 0.05, 0.02), Vector3(0, 0.42, 0)],
			[Vector3(0.05, 0.44, 0.02), Vector3(0.285, 0.2, 0)], [Vector3(0.05, 0.44, 0.02), Vector3(-0.285, 0.2, 0)]]:
		_parts.add_child(PuzzleNode.box_mesh(e[0], trim, board_c + e[1] + Vector3(0, 0, BOARD.z * 0.5 + 0.01)))
	# The rim: orange, solid (a ring of little colliders the ball bounces off).
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RIM_RADIUS - 0.03
	tm.outer_radius = RIM_RADIUS + 0.03
	tm.rings = 32
	tm.ring_segments = 8
	rim.mesh = tm
	rim.material_override = orange
	rim.position = Vector3(0, RIM_HEIGHT, 0)
	_parts.add_child(rim)
	for i in 16:
		var a := i * TAU / 16.0
		var s := SphereShape3D.new()
		s.radius = 0.045
		var cs := CollisionShape3D.new()
		cs.shape = s
		cs.position = Vector3(cos(a) * RIM_RADIUS, RIM_HEIGHT, sin(a) * RIM_RADIUS)
		body.add_child(cs)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.1, 0.05, absf(board_z) - RIM_RADIUS + 0.04), orange, Vector3(0, RIM_HEIGHT, board_z * 0.5 - RIM_RADIUS * 0.5)))
	# The net: a see-through tapering sock (no collision: the ball drops through).
	var net := StandardMaterial3D.new()
	net.albedo_color = Color(1, 1, 1, 0.35)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sock := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = RIM_RADIUS
	cm.bottom_radius = RIM_RADIUS * 0.6
	cm.height = 0.6
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 16
	cm.rings = 2
	sock.mesh = cm
	sock.material_override = net
	sock.position = Vector3(0, RIM_HEIGHT - 0.3, 0)
	sock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts.add_child(sock)
	Looks.apply(_parts, MapTheme.pick(self, "hoop", model)) # (the arc below stays)
	# The three-point arc on the floor (a half circle out toward the court).
	var arc := StandardMaterial3D.new()
	arc.albedo_color = Color(tc.r, tc.g, tc.b, 0.75)
	arc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var segs := 28
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var p0 := Vector3(cos(a0), 0, sin(a0)) * three_range
		var p1 := Vector3(cos(a1), 0, sin(a1)) * three_range
		var seg := PuzzleNode.box_mesh(Vector3(0.14, 0.02, p0.distance_to(p1) + 0.02), arc, (p0 + p1) * 0.5 + Vector3(0, 0.012, 0))
		seg.rotation.y = atan2(p1.x - p0.x, p1.z - p0.z)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_parts.add_child(seg)


func _cyl(r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	return mi


func _shape(body: StaticBody3D, shape: BoxShape3D, size_v: Vector3, pos: Vector3) -> void:
	shape.size = size_v
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


## (A hoop scores by the ball dropping through its rim: see through_rim.)
func contains_ball(_p: Vector3, _r: float) -> bool:
	return false


## The middle of the rim (aim here).
func mouth() -> Vector3:
	return global_transform * Vector3(0, RIM_HEIGHT, 0)


## Did a ball of radius r drop down through the rim between these two positions?
func through_rim(before: Vector3, after: Vector3, r: float) -> bool:
	var inv := global_transform.affine_inverse()
	var a := inv * before - Vector3(0, RIM_HEIGHT, 0)
	var b := inv * after - Vector3(0, RIM_HEIGHT, 0)
	if not (a.y > 0.0 and b.y <= 0.0):
		return false
	var t := a.y / (a.y - b.y)
	var at := a.lerp(b, t)
	return Vector2(at.x, at.z).length() < RIM_RADIUS - r * 0.35
