@tool
class_name Looks
extends RefCounted
## Puts a model (a piece's own, or its map theme's) in place of a Map Kit piece's built-in
## look: the built-in meshes under the piece's parts node are hidden (collision, lights and
## the effects in `keep` stay), the model is added there. The piece then takes any moving
## parts it needs from the model by name (part()), and the places where things happen
## (markers: empties in Blender, any node in Godot), the same names in every piece:
## - Spout: a pipe's water comes out here, the way the marker points (its Y axis: the arrow
##   of a Blender "Single Arrow" empty). Intake: a drain takes water in here.
## - Emitter: steam, smoke, sparks come from here. Light: the glow is here.
## - Collision: a mesh that is what things bump into (a prop's shape; hidden in the game).
## Moving parts: Spin, Wheel, Cap, Plate, Float, Plank, Net, Rotor (see docs/MAPPING.md).
## A missing marker: the piece's own spot (its origin) is used.

const SPOUT := "Spout"
const INTAKE := "Intake"
const EMITTER := "Emitter"
const LIGHT := "Light"
const COLLISION := "Collision"
## Every marker and moving part's name (the map check spots a near miss: "spout").
const NAMES := ["Spout", "Intake", "Emitter", "Light", "Collision", "Spin", "Wheel", "Cap", "Plate", "Float", "Plank", "Net", "Rotor"]
## What each piece looks for in your model, and what happens without it.
const WANTS := {
	"FloodValve": [["Spout", "the water falls straight down from the piece's origin"]],
	"FloodDrain": [["Intake", "the water goes in at the piece's origin"]],
	"PuzzleButton": [["Cap", "nothing moves when it's pressed"]],
	"PressurePlate": [["Plate", "nothing sinks when it's weighed down"]],
	"FloatSwitch": [["Float", "nothing rides on the water"]],
	"Seesaw": [["Plank", "the whole model stays put while the plank tips"]],
	"VolleyNet": [["Net", "nothing rises with the net"]],
	"PuzzleFan": [["Rotor", "nothing spins"]],
}


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
		if c is MeshInstance3D or c is MultiMeshInstance3D or c is CSGShape3D or c is Label3D:
			(c as Node3D).visible = false
		_hide(c, kept)


## The map check's notes on a model: the markers its piece looks for that aren't there (and
## what happens without them), and names that are nearly a marker's ("spout": it must be
## "Spout" exactly). `who`: the piece, for the note; `piece_class`: its class (WANTS).
static func notes(who: String, scene: PackedScene, piece_class: String) -> Array[String]:
	var out: Array[String] = []
	if scene == null:
		return out
	var root := scene.instantiate()
	if root == null:
		return out
	var names := {}
	_names(root, names)
	root.free()
	for w: Array in WANTS.get(piece_class, []):
		if not names.has(w[0]):
			out.append("%s: its model has no \"%s\" (%s)." % [who, w[0], w[1]])
	for n: String in names:
		for m: String in NAMES:
			if n != m and n.to_lower() == m.to_lower():
				out.append("%s: its model has \"%s\"; a marker's name must be \"%s\" exactly." % [who, n, m])
	return out


static func _names(n: Node, out: Dictionary) -> void:
	out[String(n.name)] = true
	for c in n.get_children():
		_names(c, out)


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
