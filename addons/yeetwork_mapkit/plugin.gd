@tool
extends EditorPlugin
## The Map Kit in the editor:
## - Click a piece in the 3D view to select it. Its look is drawn with internal meshes that
##   aren't saved in the map, which Godot doesn't pick by itself: the gizmo adds a click shape.
## - Resize boxes (blocks, hazard volumes, doors, lifts) with the handles on their faces.
## - Or with the Scale tool (R): when you let go, the scale becomes the piece's Size (a scaled
##   physics body misbehaves; Godot warns about it) and the scale goes back to 1.
## - A block draws a world-wrapped copy of its Custom Material, and materials don't say when
##   they're edited: the materials being edited are watched, and blocks using one are
##   rebuilt when it changes.

const MATERIAL_CHECK := 0.25 # seconds

var _gizmos: EditorNode3DGizmoPlugin
var _baking := false
var _material_seen := {} # material -> hash of its settings when last checked
var _material_clock := 0.0


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


func _process(delta: float) -> void:
	_material_clock += delta
	if _material_clock < MATERIAL_CHECK:
		return
	_material_clock = 0.0
	# The materials being edited: in the Inspector, or in the slot of a selected block.
	var watched := {}
	var edited := EditorInterface.get_inspector().get_edited_object()
	if edited is BaseMaterial3D:
		watched[edited] = true
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n.get("custom_material") is BaseMaterial3D and _is_mapkit(n):
			watched[n.get("custom_material")] = true
	var changed := []
	for m in watched:
		var h := _material_hash(m)
		if _material_seen.has(m) and _material_seen[m] != h:
			changed.append(m)
		_material_seen[m] = h
	for m in _material_seen.keys():
		if not watched.has(m):
			_material_seen.erase(m)
	if not changed.is_empty():
		_rebuild_users(EditorInterface.get_edited_scene_root(), changed)


func _material_hash(m: Material) -> int:
	var values := []
	for p in m.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			values.append(m.get(p.name))
	return hash(values)


func _rebuild_users(n: Node, materials: Array) -> void:
	if n == null:
		return
	if n.get("custom_material") in materials and _is_mapkit(n):
		n.call("_rebuild")
	for c in n.get_children():
		_rebuild_users(c, materials)


func _is_mapkit(n: Node) -> bool:
	var s: Script = n.get_script()
	return s != null and s.resource_path.begins_with("res://scripts/mapkit/")
