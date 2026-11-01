@tool
class_name CargoContainer
extends Node3D
## A 40 ft shipping container (12.2 x 2.6 x 2.44 m: its bottom on the node, its length along
## X), in its company's paint:
## - closed: solid; stack them.
## - Lashed (on a Vessel: High Seas' top containers): its lashings can give (blasts, pushes,
##   lightning, a storm's rolling wear them down; it creaks, then breaks loose as a heavy prop
##   that slides about the deck). Yellow rods brace its ends.
## - Open: hollow, its doors swung wide at one end (Doors Aft: the -X end, else +X), a lamp
##   inside; Pickup: a pickup waits in it (a random power-up). A hideout.

const SIZE := Vector3(12.2, 2.6, 2.44)

@export var color := Color(0.12, 0.38, 0.75):
	set(v):
		color = v
		_rebuild()
@export var lashed := false:
	set(v):
		lashed = v
		_rebuild()
@export var open := false:
	set(v):
		open = v
		_rebuild()
@export var doors_aft := false:
	set(v):
		doors_aft = v
		_rebuild()
@export var pickup := false

var mesh: MeshInstance3D # (closed: the box; World hides it when it breaks loose)
var shape: CollisionShape3D # (its collision: on a ship, the ship's)
var rods: Node3D
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
	mesh = null
	shape = null
	rods = null
	if open:
		_build_open()
	else:
		_build_closed()


func _build_closed() -> void:
	mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	mesh.mesh = bm
	mesh.position.y = SIZE.y * 0.5
	mesh.material_override = MapHighSeas.container_material(color)
	_parts.add_child(mesh)
	var body := _body()
	shape = _shape(body, SIZE, Vector3(0, SIZE.y * 0.5, 0))
	if lashed:
		rods = Node3D.new()
		rods.position.y = SIZE.y * 0.5
		_parts.add_child(rods)
		var yellow := Mats.plastic(Color(0.95, 0.75, 0.15), 0.4)
		for ex in [-1, 1]:
			for d in [-1, 1]:
				var rod := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.05, 3.3, 0.05)
				rod.mesh = rm
				rod.material_override = yellow
				rod.position = Vector3(ex * (SIZE.x * 0.5 + 0.06), -0.4, 0)
				rod.rotation.x = d * 0.6
				rods.add_child(rod)


## Hollow: roof, two long sides, the closed end, a floor; the doors swung flat against the
## next stacks' ends, a lamp inside, maybe a pickup.
func _build_open() -> void:
	var paint := Mats.world(color, 0.6)
	var inner := Mats.world(color.darkened(0.2), 0.8)
	var hx := SIZE.x * 0.5
	var hz := SIZE.z * 0.5
	var y := SIZE.y * 0.5
	var dir := -1.0 if doors_aft else 1.0 # (which end is open)
	var body := _body()
	_box(body, Vector3(0, SIZE.y - 0.05, 0), Vector3(SIZE.x, 0.1, SIZE.z), paint, true)
	for s in [-1, 1]:
		_box(body, Vector3(0, y, s * (hz - 0.05)), Vector3(SIZE.x, SIZE.y, 0.1), paint, true)
		_box(body, Vector3(0, y, s * (hz - 0.12)), Vector3(SIZE.x - 0.2, SIZE.y - 0.2, 0.02), inner, false)
	_box(body, Vector3(-dir * (hx - 0.05), y, 0), Vector3(0.1, SIZE.y, SIZE.z), paint, true)
	_box(body, Vector3(0, 0.03, 0), Vector3(SIZE.x - 0.2, 0.06, SIZE.z - 0.2), Mats.world(Color(0.3, 0.26, 0.22), 0.9), false)
	for s in [-1, 1]:
		var hinge := Vector3(dir * hx, y, s * hz)
		var door := PuzzleNode.box_mesh(Vector3(0.08, SIZE.y - 0.1, 1.2), paint, hinge + Vector3(dir * 0.1, 0, s * 0.62))
		door.basis = Basis(Vector3.UP, s * dir * 1.75)
		_parts.add_child(door)
	if not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.position = Vector3(-dir * 2.0, SIZE.y - 0.4, 0)
		l.light_color = Color(1.0, 0.82, 0.6)
		l.omni_range = 10.0
		l.light_energy = 1.8
		_parts.add_child(l)
		if pickup:
			var ps := PickupSpawn.new()
			ps.kind = "random"
			ps.position = Vector3(-dir * 4.0, 0, 0)
			ps.name = "Pickup"
			add_child(ps) # (a child Arena finds like any PickupSpawn)


## Where its open end is (its own frame): bots go in that way to its pickup.
func doorway() -> Vector3:
	return Vector3((-1.0 if doors_aft else 1.0) * SIZE.x * 0.5, 0, 0)


func _body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 # (the world's layer)
	body.collision_mask = 0
	_parts.add_child(body)
	return body


func _shape(body: StaticBody3D, size: Vector3, at: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = at
	body.add_child(cs)
	return cs


func _box(body: StaticBody3D, at: Vector3, size: Vector3, mat: Material, solid: bool) -> void:
	_parts.add_child(PuzzleNode.box_mesh(size, mat, at))
	if solid:
		_shape(body, size, at)
