@tool
class_name StoryZone
extends PuzzleNode
## A place that notices you: on when a Yeet walks into its box (its bottom on the node). What
## sets off a StoryLine as you enter a room, a door slamming behind you, and later a fight. With
## Inputs, it only counts while they're on. Nothing to see in the game.

## Its box, metres.
@export var size := Vector3(4, 3, 4):
	set(v):
		size = v
		_rebuild()
## once: on for good from the first Yeet in. while inside: off again when they've left.
@export_enum("once", "while inside") var stays := "once"
## anyone: one Yeet is enough. everyone: every living Yeet has to be in it.
@export_enum("anyone", "everyone") var who := "anyone"

var _outline: MeshInstance3D


func _ready() -> void:
	latch = stays == "once"
	_rebuild()


func evaluate() -> bool:
	if not inputs.is_empty() and not inputs_on():
		return false
	var inside := players_in(Vector3(0, size.y * 0.5, 0), size).size()
	if inside == 0:
		return false
	if who == "anyone":
		return true
	return inside >= world.players.values().filter(func(p): return p.is_alive()).size()


## In the editor only: where it is.
func _rebuild() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint():
		return
	if _outline:
		_outline.queue_free()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.8, 1.0, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline = PuzzleNode.box_mesh(size, m, Vector3(0, size.y * 0.5, 0))
	add_child(_outline, false, Node.INTERNAL_MODE_FRONT)
