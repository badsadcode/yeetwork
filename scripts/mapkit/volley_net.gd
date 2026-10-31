@tool
class_name VolleyNet
extends Node3D
## A YeetVolley court: the net across the middle (posts, a solid net the ball and players
## bounce off) and the court lines on the floor. Put the node on the floor in the middle of
## the court: the net runs along local X; Red plays on the local -Z side, Blue on +Z.
## Court: width (X) and length (Z, both halves together). The ball landing inside a half is
## a point for the other team; landing outside the lines is "out".

@export var court := Vector2(12, 22):
	set(v):
		court = v
		_rebuild()
@export_range(1.5, 5.0, 0.1) var net_height := 2.5:
	set(v):
		net_height = v
		_rebuild()

## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
## A child named "Net" rises with the net (TOTAL YEET). The court lines stay.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var raise := 0.0 # TOTAL YEET: the net climbs a little with every point
var _parts: Node3D
var _net: Node3D
var _halves: Array[VolleyHalf] = []


func _ready() -> void:
	_rebuild()


## The two halves of the court (as GoalZones: the team that defends each), for the arena.
func halves() -> Array[VolleyHalf]:
	if _halves.is_empty():
		for team in [1, 2]:
			var h := VolleyHalf.new()
			h.net = self
			h.team = team
			h.position = Vector3(0, 0, court.y * 0.25 * (-1.0 if team == 1 else 1.0))
			if team == 2:
				h.rotation.y = PI # (its +Z faces the net, like a goal's mouth faces the pitch)
			add_child(h)
			_halves.append(h)
	return _halves


## Which side a world point is on: 1 Red, 2 Blue (0: on the line).
func side_of(p: Vector3) -> int:
	var z := (global_transform.affine_inverse() * p).z
	return 1 if z < 0.0 else (2 if z > 0.0 else 0)


## Inside the court lines?
func inside(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= court.x * 0.5 + 0.05 and absf(l.z) <= court.y * 0.5 + 0.05


func top() -> float:
	return net_height + raise


func set_raise(r: float) -> void:
	if is_equal_approx(r, raise):
		return
	raise = r
	if _net:
		_net.position.y = r


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var white := Mats.plastic(Color(0.95, 0.95, 0.97), 0.3)
	var post_mat := Mats.plastic(Color(0.3, 0.32, 0.38), 0.35)
	var w := court.x + 1.2
	# Posts, tall enough for a raised net.
	for sx in [-1, 1]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.08
		cm.height = net_height + 2.5
		cm.radial_segments = 10
		post.mesh = cm
		post.material_override = post_mat
		post.position = Vector3(sx * w * 0.5, cm.height * 0.5, 0)
		_parts.add_child(post)
	# The net (moves up as a whole when raised): see-through mesh over a solid wall, the
	# white band on top.
	_net = Node3D.new()
	_net.position.y = raise
	_parts.add_child(_net)
	var mesh := StandardMaterial3D.new()
	mesh.albedo_color = Color(0.1, 0.1, 0.12, 0.55)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	_net.add_child(PuzzleNode.box_mesh(Vector3(w, net_height, 0.04), mesh, Vector3(0, net_height * 0.5, 0)))
	_net.add_child(PuzzleNode.box_mesh(Vector3(w, 0.1, 0.07), white, Vector3(0, net_height - 0.05, 0)))
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Game.L_WORLD
	body.collision_mask = 0
	_net.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, net_height, 0.1)
	cs.shape = bs
	cs.position = Vector3(0, net_height * 0.5, 0)
	body.add_child(cs)
	var look := Looks.apply(_parts, MapTheme.pick(self, "volley_net", model))
	Looks.attach(look, "Net", _net)
	# Court lines, and each half faintly tinted in its team's colour.
	var line := Mats.plastic(Color(1.0, 1.0, 1.0), 0.5, 0.35)
	var hx := court.x * 0.5
	var hz := court.y * 0.5
	for e in [[Vector3(court.x, 0.02, 0.16), Vector3(0, 0.011, -hz)], [Vector3(court.x, 0.02, 0.16), Vector3(0, 0.011, hz)],
			[Vector3(0.16, 0.02, court.y), Vector3(-hx, 0.011, 0)], [Vector3(0.16, 0.02, court.y), Vector3(hx, 0.011, 0)],
			[Vector3(court.x, 0.02, 0.16), Vector3(0, 0.011, 0)]]:
		var m := PuzzleNode.box_mesh(e[0], line, e[1])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_parts.add_child(m)
	for team in [1, 2]:
		var tc := Color(1.0, 0.32, 0.26, 0.24) if team == 1 else Color(0.3, 0.55, 1.0, 0.24) # (no autoloads in the editor)
		var tint := StandardMaterial3D.new()
		tint.albedo_color = tc
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var m := PuzzleNode.box_mesh(Vector3(court.x, 0.01, hz), tint, Vector3(0, 0.006, hz * 0.5 * (-1.0 if team == 1 else 1.0)))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_parts.add_child(m)
