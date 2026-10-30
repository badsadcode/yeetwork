@tool
class_name PuzzleLogic
extends PuzzleNode
## Combines other pieces' states: on when all (AND) or any (OR) of its Inputs are on, or the
## opposite with Invert. Hold Time keeps it on for a while after the inputs go off (a door
## that closes again 5 s after you step off the plate: race through!). Invisible in game.

@export var invert := false
@export_range(0.0, 60.0, 0.5) var hold_time := 0.0

var _held_until := -1.0
var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.4, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.6, 0.4, 1.0)
		_preview = PuzzleNode.box_mesh(Vector3(0.5, 0.5, 0.5), m)
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)


func evaluate() -> bool:
	var on := inputs_on() != invert
	var now: float = world.now()
	if on:
		_held_until = now + hold_time
		return true
	return now < _held_until
