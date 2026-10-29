@tool
class_name HazardVolume
extends Node3D
## Acid (bouncy, damaging, glowing surface), Kill (instant death, e.g. under a void) or
## Wind (constant push, e.g. an updraft).

@export_enum("acid", "kill", "wind") var kind := "acid":
	set(v):
		kind = v
		_rebuild()
@export var size := Vector3(8, 2, 8):
	set(v):
		size = v
		_rebuild()
## Acid: damage per touch. Wind: ignored.
@export var damage := 22.0
## Wind: acceleration in m/s^2 (world space).
@export var wind := Vector3(0, 30, 0)

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
	var cols := {"acid": Color(0.45, 1, 0.2, 0.35), "kill": Color(1, 0.1, 0.1, 0.25), "wind": Color(0.6, 0.9, 1, 0.2)}
	var m := StandardMaterial3D.new()
	m.albedo_color = cols[kind]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview.material_override = m
