@tool
class_name Looks
extends RefCounted
## Puts a model (a piece's own, or its map theme's) in place of a Map Kit piece's built-in
## look: the built-in meshes under the piece's parts node are hidden (collision, lights and
## the effects in `keep` stay), the model is added there. The piece then takes any moving
## parts it needs from the model by name (part()).


## Shows `scene` instead of the built-in look under `parts`. Returns the model, or null when
## there's no scene (the built-in look stays).
static func apply(parts: Node3D, scene: PackedScene, keep: Array = []) -> Node3D:
	if scene == null or parts == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	var kept := {}
	for k in keep:
		if k:
			kept[k] = true
	_hide(parts, kept)
	parts.add_child(model)
	return model


static func _hide(n: Node, kept: Dictionary) -> void:
	for c in n.get_children(true):
		if kept.has(c):
			continue
		if c is MeshInstance3D or c is CSGShape3D or c is Label3D:
			(c as Node3D).visible = false
		_hide(c, kept)


## A named part of the model (a button's "Cap"...), or null.
static func part(model: Node3D, part_name: String) -> Node3D:
	return model.find_child(part_name, true, false) as Node3D if model else null


## Moves a named part of the model under `moving` (keeping where it is), so it moves with a
## piece's moving body (a seesaw's plank, a volley net). Returns it, or null.
static func attach(model: Node3D, part_name: String, moving: Node3D) -> Node3D:
	var p := part(model, part_name)
	if p == null or moving == null:
		return null
	var xf := p.global_transform if p.is_inside_tree() and moving.is_inside_tree() else Transform3D.IDENTITY
	p.get_parent().remove_child(p)
	moving.add_child(p)
	if p.is_inside_tree():
		p.global_transform = xf
	return p
