@tool
extends EditorNode3DGizmoPlugin
## The Map Kit's gizmo:
## - a pick shape for each piece: the triangles of its internal meshes (and of a Model it
##   shows), so a click on what you see selects the piece;
## - resize handles on boxes (blocks, hazard volumes, doors, lifts): one on each face. Drag
##   it and that face moves while the opposite one stays put. Hold Ctrl to snap to whole
##   metres (otherwise 0.1 m). Undo with Ctrl+Z.

const MIN_SIZE := 0.1

var undo: EditorUndoRedoManager
var _drag_start := {} # node -> [transform, size] when a handle drag began


func _init() -> void:
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "MapKit"


func _has_gizmo(node: Node3D) -> bool:
	var s: Script = node.get_script()
	return s != null and s.resource_path.begins_with("res://scripts/mapkit/")


func _resizable(node: Node3D) -> bool:
	return node is ArenaBlock or node is HazardVolume or node is PuzzleDoor or node is LiftPlatform


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	if node == null or not node.is_inside_tree():
		return
	var faces := PackedVector3Array()
	_collect(node, node.global_transform.affine_inverse(), faces, EditorInterface.get_edited_scene_root())
	if faces.size() >= 3:
		var tm := TriangleMesh.new()
		if tm.create_from_faces(faces):
			gizmo.add_collision_triangles(tm)
	if _resizable(node):
		var half: Vector3 = node.get("size") * 0.5
		var handles := PackedVector3Array()
		for axis in 3:
			for sign in [1.0, -1.0]:
				var p := Vector3.ZERO
				p[axis] = half[axis] * sign
				handles.append(p)
		gizmo.add_handles(handles, get_material("handles", gizmo), [])


## The meshes under the piece that aren't nodes of the map (those have their own picking).
func _collect(n: Node, inv: Transform3D, faces: PackedVector3Array, scene_root: Node) -> void:
	for c in n.get_children(true):
		if c.owner == scene_root and scene_root != null:
			continue # a node of the map: picked on its own
		if c is MeshInstance3D and (c as MeshInstance3D).mesh and (c as MeshInstance3D).visible and not (c as MeshInstance3D).top_level:
			var xf := inv * (c as MeshInstance3D).global_transform
			for v in (c as MeshInstance3D).mesh.get_faces():
				faces.append(xf * v)
		_collect(c, inv, faces, scene_root)


# --- Resize handles (ids: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z) ---------------------------

func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return "Size %s" % ["X", "Y", "Z"][handle_id / 2]


func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var node := gizmo.get_node_3d()
	return [node.get("size"), node.position]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node := gizmo.get_node_3d()
	if not _drag_start.has(node):
		_drag_start[node] = [node.global_transform, node.get("size")]
	var start_xf: Transform3D = _drag_start[node][0]
	var start_size: Vector3 = _drag_start[node][1]
	var axis := handle_id / 2
	var sign := 1.0 if handle_id % 2 == 0 else -1.0
	# Where the mouse ray passes the handle's axis, in the block's space at the drag start.
	var inv := start_xf.affine_inverse()
	var from := inv * camera.project_ray_origin(screen_pos)
	var to := inv * (camera.project_ray_origin(screen_pos) + camera.project_ray_normal(screen_pos) * 4096.0)
	var a := Vector3.ZERO
	a[axis] = 4096.0
	var closest := Geometry3D.get_closest_points_between_segments(-a, a, from, to)
	var face: float = closest[0][axis]
	var step := 1.0 if Input.is_key_pressed(KEY_CTRL) else 0.1
	var other := -sign * start_size[axis] * 0.5 # the opposite face stays where it was
	face = other + sign * maxf(snappedf(absf(face - other), step), MIN_SIZE)
	var new_size := start_size
	new_size[axis] = absf(face - other)
	var center := Vector3.ZERO
	center[axis] = (face + other) * 0.5
	node.set("size", new_size)
	node.global_position = start_xf * center
	node.update_gizmos()


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d()
	_drag_start.erase(node)
	var old_size: Vector3 = restore[0]
	var old_pos: Vector3 = restore[1]
	if cancel or undo == null:
		if cancel:
			node.set("size", old_size)
			node.position = old_pos
		return
	undo.create_action("Resize %s" % node.name)
	undo.add_do_property(node, "size", node.get("size"))
	undo.add_do_property(node, "position", node.position)
	undo.add_undo_property(node, "size", old_size)
	undo.add_undo_property(node, "position", old_pos)
	undo.add_do_method(node, "update_gizmos")
	undo.add_undo_method(node, "update_gizmos")
	undo.commit_action(false)
