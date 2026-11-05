@tool
class_name StoryNote
extends PuzzleNode
## A thing to read: a note, a diary, a sign, a clue. Walk up and press Use: your text opens on
## the reader's screen (and a picture, if it has one). It's on once someone's read it, so it can
## open a door, count as a clue found, or set off what comes next. With Inputs, it can only be
## read once they're on (it isn't there until then). The built-in look is a page on a stand.

## Its name: the Use prompt ("Read <Title>") and the top of the page.
@export var title := "Note":
	set(v):
		title = v
		_rebuild()
## What it says.
@export_multiline var text := ""
## A picture on the page (a drawing, a photo, a map), if any.
@export var picture: Texture2D
## Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map
## theme's `story_note`. Its origin is on the ground.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var _read := false # (server)
var _parts: Node3D
var _page: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _there() -> bool:
	return inputs.is_empty() or inputs_on() or active


func evaluate() -> bool:
	return _read


func usable() -> bool:
	return _there()


func use_label() -> String:
	return "Read %s" % title


func use_point() -> Vector3:
	return global_position + Vector3.UP * 1.0


func server_used(pl: Player) -> void:
	_read = true
	world.server_show_note(pl, puzzle_index)


func problems() -> Array[String]:
	var out := super.problems()
	if text.strip_edges() == "":
		out.append("%s: it has no text." % name)
	return out


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_page = StandardMaterial3D.new()
	_page.albedo_color = Color(0.98, 0.94, 0.78)
	_page.emission_enabled = true
	_page.emission = Color(1.0, 0.92, 0.6)
	_tint()
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.12, 0.85, 0.12), Mats.world(Color(0.35, 0.27, 0.2), 0.8, 0.0), Vector3(0, 0.425, 0)))
	var page := PuzzleNode.box_mesh(Vector3(0.55, 0.03, 0.42), _page, Vector3(0, 0.9, 0))
	page.rotation.x = 0.5
	_parts.add_child(page)
	Looks.apply(_parts, MapTheme.pick(self, "story_note", model))


func _tint() -> void:
	if _page:
		_page.emission_energy_multiplier = 0.15 if active else 1.2 # (not read yet: it catches the eye)


func _state_changed(_play_fx: bool) -> void:
	_tint()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and _parts and not inputs.is_empty():
		_parts.visible = _there()
