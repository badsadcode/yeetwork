@tool
class_name GoalZone
extends Node3D
## A football goal for Yeetball: posts, a crossbar and a net, its mouth facing local +Z (turn
## it toward the pitch). Team: the team that defends it (the other team scores here). A goal
## counts once the whole ball is past the line (inside Size: width, height, depth behind
## the line). The frame and net are solid: the ball stays in.

@export_enum("Red:1", "Blue:2") var team := 1:
	set(v):
		team = v
		_rebuild()
@export var size := Vector3(7, 3.5, 2.5):
	set(v):
		size = v
		_rebuild()

## Your own model for the frame (a scene: an imported .glb...), instead of the built-in look
## and the map theme's. The net stays solid where it is.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

const POST := 0.16

var _parts: Node3D


func _ready() -> void:
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
	var w := size.x
	var h := size.y
	var d := size.z
	# Posts and crossbar (round, white), the goal line glowing in the team colour.
	for sx in [-1, 1]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = POST
		cm.bottom_radius = POST
		cm.height = h
		post.mesh = cm
		post.material_override = white
		post.position = Vector3(sx * w * 0.5, h * 0.5, 0)
		_parts.add_child(post)
	var bar := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = POST
	bm.bottom_radius = POST
	bm.height = w + POST * 2.0
	bar.mesh = bm
	bar.material_override = white
	bar.rotation_degrees = Vector3(0, 0, 90)
	bar.position = Vector3(0, h, 0)
	_parts.add_child(bar)
	var line := StandardMaterial3D.new()
	line.albedo_color = tc
	line.emission_enabled = true
	line.emission = tc
	line.emission_energy_multiplier = 1.5
	_parts.add_child(PuzzleNode.box_mesh(Vector3(w, 0.03, 0.18), line, Vector3(0, 0.015, -0.09)))
	# The net: see-through, tinted, solid for the ball.
	var net := StandardMaterial3D.new()
	net.albedo_color = Color(tc.r, tc.g, tc.b, 0.22)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.roughness = 0.9
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Game.L_WORLD
	body.collision_mask = 0
	_parts.add_child(body)
	var panels := [
		[Vector3(w, h, 0.06), Vector3(0, h * 0.5, -d)],                  # back
		[Vector3(0.06, h, d), Vector3(-w * 0.5, h * 0.5, -d * 0.5)],      # sides
		[Vector3(0.06, h, d), Vector3(w * 0.5, h * 0.5, -d * 0.5)],
		[Vector3(w, 0.06, d), Vector3(0, h, -d * 0.5)],                   # roof
	]
	for p in panels:
		_parts.add_child(PuzzleNode.box_mesh(p[0], net, p[1]))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = p[0]
		cs.shape = bs
		cs.position = p[1]
		body.add_child(cs)
	for sx in [-1, 1]:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = POST
		cyl.height = h
		cs.shape = cyl
		cs.position = Vector3(sx * w * 0.5, h * 0.5, 0)
		body.add_child(cs)
	Looks.apply(_parts, MapTheme.pick(self, "goal", model))


## Is a ball of radius r at p all the way in?
func contains_ball(p: Vector3, r: float) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) < size.x * 0.5 and l.y > -0.5 and l.y < size.y and l.z < -r and l.z > -size.z - 0.5


## The middle of the goal's mouth (aim here).
func mouth() -> Vector3:
	return global_transform * Vector3(0, size.y * 0.45, 0)
