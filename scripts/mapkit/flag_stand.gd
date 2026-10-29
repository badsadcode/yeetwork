@tool
class_name FlagStand
extends Node3D
## Team flag base for Capture the Flag (needs one Red and one Blue). Place at floor level.

@export_enum("Red", "Blue") var team := 0:
	set(v):
		team = v
		_rebuild()

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func team_id() -> int:
	return 1 if team == 0 else 2


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.6
	cm.height = 0.4
	_preview.mesh = cm
	_preview.position.y = 0.2
	_preview.material_override = Mats.glow(Color(1, 0.3, 0.35) if team == 0 else Color(0.3, 0.55, 1), 2.0)
