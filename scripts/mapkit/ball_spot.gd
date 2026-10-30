@tool
class_name BallSpot
extends Node3D
## Where the ball is put for a kickoff in Yeetball (and after it's lost). One per map; without
## one, the middle of the map is used.


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
