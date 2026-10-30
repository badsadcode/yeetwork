@tool
extends EditorPlugin
## The Map Kit in the editor. Its pieces (blocks, slabs, spawn points, props, puzzle pieces...)
## draw themselves with internal meshes that aren't saved in the map, and Godot only picks
## nodes of the scene when you click in the 3D view: so clicking a block selected nothing.
## This adds a pick shape to every Map Kit piece: click it, and it's selected. The shape
## follows the piece when you change it in the Inspector (a block's Size).

var _gizmos: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_gizmos = preload("res://addons/yeetwork_mapkit/pick_gizmos.gd").new()
	add_node_3d_gizmo_plugin(_gizmos)
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmos)
	if EditorInterface.get_inspector().property_edited.is_connected(_on_property_edited):
		EditorInterface.get_inspector().property_edited.disconnect(_on_property_edited)


func _on_property_edited(_property: String) -> void:
	var n := EditorInterface.get_inspector().get_edited_object() as Node3D
	if n:
		# After the piece has rebuilt its look.
		n.update_gizmos.call_deferred()
