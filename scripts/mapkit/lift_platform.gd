@tool
class_name LiftPlatform
extends Node3D
## A platform moving between this position and `travel` (relative), on a clock shared by
## every player. Pauses briefly at each end.

@export var size := Vector3(3, 0.5, 3):
	set(v):
		size = v
		_rebuild()
@export var travel := Vector3(0, 6, 0):
	set(v):
		travel = v
		_rebuild()
@export_range(1.0, 60.0, 0.5) var period := 8.0
@export_range(0.0, 1.0, 0.05) var phase := 0.0
## Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look.
## It works the same; only the look changes. (Its collision stays a box of Size.)
@export var model: PackedScene

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var bm := BoxMesh.new()
	bm.size = size
	_preview.mesh = bm
	_preview.material_override = Mats.world(Color(0.5, 0.62, 0.8), 0.4, 0.3)
	var ghost: MeshInstance3D = _preview.get_child(0, true) if _preview.get_child_count(true) > 0 else null
	if ghost == null:
		ghost = MeshInstance3D.new()
		_preview.add_child(ghost, false, Node.INTERNAL_MODE_FRONT)
	ghost.mesh = bm
	ghost.position = travel
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 1, 0.6, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = m
