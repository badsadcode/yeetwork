@tool
class_name ShipHold
extends Node3D
## Below deck on a Vessel (an engine room, a cargo hold): a box (Size, standing on this node,
## lined up with the ship) the sea stays out of however far she heels, and where bots knocked
## down a hatch find their way out: up the Ladders whose foot is in it. Put it under the Vessel;
## one a ship.

## The hold's box, metres (standing on the node): the sea stays out of it however far she
## heels.
@export var size := Vector3(12, 6, 10):
	set(v):
		size = v
		_rebuild()

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


## Its box in its parent's frame (the ship's, once it's on one).
func box() -> AABB:
	return AABB(position - Vector3(size.x * 0.5, 0, size.z * 0.5), size)


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.75, 0.2, 0.1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bm := BoxMesh.new()
	bm.size = size
	_preview.mesh = bm
	_preview.position.y = size.y * 0.5
	_preview.material_override = m
