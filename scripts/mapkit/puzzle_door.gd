@tool
class_name PuzzleDoor
extends PuzzleNode
## A heavy door (or gate, or bridge, or platform) that slides by Open Offset while its Inputs
## are on, and back when they go off. It can't be broken: the puzzle is the way through
## (add a BreakableSlab next to it if you want a messy alternative). Lights above it show
## red (shut) and green (open).

@export var size := Vector3(4, 4, 0.5):
	set(v):
		size = v
		_rebuild()
## Where the door goes when open, relative to where it stands (default: up into the ceiling).
@export var open_offset := Vector3(0, 3.8, 0):
	set(v):
		open_offset = v
		_rebuild()
@export_range(0.5, 20.0, 0.1) var speed := 3.0
@export var color := Color(0.55, 0.6, 0.72):
	set(v):
		color = v
		_rebuild()
## Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look.
## It works the same; only the look changes. It moves with the door; its collision
## stays a box of Size.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var _body: AnimatableBody3D
var _lamp_mat: StandardMaterial3D
var _open := 0.0 # metres moved toward open_offset
var _ghost: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body:
		_body.queue_free()
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	_body.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	_body.add_child(cs)
	var look := MapTheme.pick(self, "door", model)
	var custom: Node = look.instantiate() if look else null
	if custom:
		_body.add_child(custom)
		add_child(_body, false, Node.INTERNAL_MODE_FRONT)
		return
	_body.add_child(PuzzleNode.box_mesh(size, Mats.world(color, 0.45, 0.35)))
	# Hazard stripes across the middle, and a frame.
	var stripe := Mats.world(Color(1.0, 0.75, 0.15), 0.5, 0.1)
	for i in 3:
		var y := (float(i) - 1.0) * size.y * 0.28
		_body.add_child(PuzzleNode.box_mesh(Vector3(size.x * 0.92, 0.18, size.z + 0.04), stripe, Vector3(0, y, 0)))
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	for sx in [-1, 1]:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		lamp.mesh = sm
		lamp.material_override = _lamp_mat
		lamp.position = Vector3(sx * (size.x * 0.5 - 0.35), size.y * 0.5 - 0.3, size.z * 0.5 + 0.1)
		_body.add_child(lamp)
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	_tint()
	if Engine.is_editor_hint():
		# Show where it goes when open.
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.4, 1.0, 0.5, 0.18)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost = PuzzleNode.box_mesh(size, gm, open_offset)
		add_child(_ghost, false, Node.INTERNAL_MODE_FRONT)


func _tint() -> void:
	if _lamp_mat == null:
		return
	var c := Color(0.3, 1.0, 0.4) if active else Color(1.0, 0.2, 0.15)
	_lamp_mat.albedo_color = c
	_lamp_mat.emission = c
	_lamp_mat.emission_energy_multiplier = 3.0


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx:
		Sfx.play3d("creak", global_position, 2.0, 0.7 if active else 0.6)


func _physics_process(delta: float) -> void:
	if _body == null or Engine.is_editor_hint():
		return
	var full := open_offset.length()
	_open = move_toward(_open, full if active else 0.0, speed * delta)
	_body.position = open_offset.normalized() * _open if full > 0.0 else Vector3.ZERO
