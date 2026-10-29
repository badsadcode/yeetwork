extends Node
## Developer tool: exports the procedural characters to glTF for Blender: the base body,
## every hat and every head extra (each sitting where it belongs on the head).
## tools/glb_to_blend.py turns the file into art/characters/characters.blend.
## Usage: godot -- --host --map prime --bots 0 --tour <dir> --tour-mode characters

var world: Node
var out_dir := ""


func _ready() -> void:
	var root := Node3D.new()
	root.name = "YeetworkCharacters"
	var shirt: Color = Game.FFA_COLORS[0]

	var body := CharacterModel.new()
	body.setup(shirt, 0, 1, 0, 0)
	body.name = "Body"
	for n in body.hat_nodes: # the hair tuft is exported as a hat of its own
		n.get_parent().remove_child(n)
		n.free()
	root.add_child(body)
	var head_xf: Transform3D = body.body.transform * (body.parts.head as Node3D).transform

	var hats := Node3D.new()
	hats.name = "Hats"
	root.add_child(hats)
	for i in CharacterModel.HAT_COUNT:
		var m := CharacterModel.new()
		m.setup(shirt, i, 1, 0, 0)
		_move_parts(m.hat_nodes, hats, "Hat-" + CharacterModel.HAT_NAMES[i], head_xf)
		m.free()
	var extras := Node3D.new()
	extras.name = "HeadExtras"
	root.add_child(extras)
	for i in range(1, CharacterModel.FACE_NAMES.size()):
		var m := CharacterModel.new()
		m.setup(shirt, 0, 1, i, 0)
		_move_parts(m.face_nodes, extras, "Extra-" + CharacterModel.FACE_NAMES[i], head_xf)
		m.free()

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, out_dir.path_join("characters.glb"))
	print("Exported characters.glb: ", error_string(err))
	root.free()
	get_tree().quit(0 if err == OK else 1)


func _move_parts(nodes: Array[Node3D], parent: Node3D, group_name: String, head_xf: Transform3D) -> void:
	var g := Node3D.new()
	g.name = group_name.replace(" ", "_").replace("'", "")
	g.transform = head_xf
	parent.add_child(g)
	for n in nodes:
		n.get_parent().remove_child(n)
		g.add_child(n)
