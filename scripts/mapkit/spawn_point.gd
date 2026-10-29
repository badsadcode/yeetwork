@tool
class_name SpawnPoint
extends Node3D
## Where players appear. "Any" spawns are used in free-for-all; team spawns in team modes
## (they fall back to any spawn if a team has none). Place at floor level; facing is
## chosen toward the map center.

@export_enum("Any", "Red", "Blue") var team := 0:
	set(v):
		team = v
		_rebuild()

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
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	_preview.mesh = cm
	_preview.position.y = 0.9
	var cols := [Color(1, 0.8, 0.2, 0.5), Color(1, 0.3, 0.35, 0.5), Color(0.3, 0.55, 1, 0.5)]
	var m := StandardMaterial3D.new()
	m.albedo_color = cols[team]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = m
