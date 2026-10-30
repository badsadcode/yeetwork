@tool
extends EditorNode3DGizmoPlugin
## A pick shape for each Map Kit piece: the triangles of its internal meshes (and of a Model
## it shows), so a click on what you see selects the piece. Nothing is drawn.


func _get_gizmo_name() -> String:
	return "MapKitPick"


func _has_gizmo(node: Node3D) -> bool:
	var s: Script = node.get_script()
	return s != null and s.resource_path.begins_with("res://scripts/mapkit/")


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
