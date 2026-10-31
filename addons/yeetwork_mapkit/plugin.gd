@tool
extends EditorPlugin
## The Map Kit in the editor:
## - Click a piece in the 3D view to select it. Its look is drawn with internal meshes that
##   aren't saved in the map, which Godot doesn't pick by itself: the gizmo adds a click shape.
## - Resize boxes (blocks, hazard volumes, doors, lifts) with the handles on their faces.
## - Or with the Scale tool (R): when you let go, the scale becomes the piece's Size (a scaled
##   physics body misbehaves; Godot warns about it) and the scale goes back to 1.
## - Edits to the open map's MapTheme show on its pieces straight away.

var _gizmos: EditorNode3DGizmoPlugin
var _baking := false
var _theme_seen := 0 # the open map's theme, hashed (edits to it re-skin the map)
var _theme_clock := 0.0


func _enter_tree() -> void:
	_gizmos = preload("res://addons/yeetwork_mapkit/pick_gizmos.gd").new()
	_gizmos.undo = get_undo_redo()
	add_node_3d_gizmo_plugin(_gizmos)
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)
	get_undo_redo().history_changed.connect(_on_history_changed)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmos)
	if EditorInterface.get_inspector().property_edited.is_connected(_on_property_edited):
		EditorInterface.get_inspector().property_edited.disconnect(_on_property_edited)
	if get_undo_redo().history_changed.is_connected(_on_history_changed):
		get_undo_redo().history_changed.disconnect(_on_history_changed)


func _on_property_edited(_property: String) -> void:
	var n := EditorInterface.get_inspector().get_edited_object() as Node3D
	if n:
		# After the piece has rebuilt its look.
		n.update_gizmos.call_deferred()


## A new action was made (a scale, or anything else; undo and redo don't count): scaled
## Map Kit boxes among the selection get their scale folded into Size.
func _on_history_changed() -> void:
	if not _baking:
		_bake_scales.call_deferred()


func _bake_scales() -> void:
	var scaled: Array[Node3D] = []
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is Node3D and n.get("size") is Vector3 and _is_mapkit(n) and not (n as Node3D).scale.is_equal_approx(Vector3.ONE):
			scaled.append(n)
	if scaled.is_empty():
		return
	_baking = true
	var ur := get_undo_redo()
	ur.create_action("Scale into Size")
	for n in scaled:
		var new_size: Vector3 = (n.get("size") as Vector3) * n.scale.abs()
		ur.add_do_property(n, "size", new_size)
		ur.add_do_property(n, "scale", Vector3.ONE)
		ur.add_undo_property(n, "size", n.get("size"))
		ur.add_undo_property(n, "scale", n.scale)
		ur.add_do_method(n, "update_gizmos")
		ur.add_undo_method(n, "update_gizmos")
	ur.commit_action()
	_baking = false


## Edits to the open map's MapTheme (a model dropped on a slot) show at once: resources don't
## say when they change, so the theme is checked twice a second.
func _process(delta: float) -> void:
	_theme_clock += delta
	if _theme_clock < 0.5:
		return
	_theme_clock = 0.0
	var root := EditorInterface.get_edited_scene_root()
	var settings := MapTheme._find_settings(root) if root else null
	var theme: MapTheme = settings.theme if settings else null
	var h := 0
	if theme:
		var values := []
		for p in theme.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE:
				values.append(theme.get(p.name))
		h = hash(values)
	if h != _theme_seen and _theme_seen != 0 and settings:
		settings.retheme()
	_theme_seen = h


func _is_mapkit(n: Node) -> bool:
	var s: Script = n.get_script()
	return s != null and s.resource_path.begins_with("res://scripts/mapkit/")
