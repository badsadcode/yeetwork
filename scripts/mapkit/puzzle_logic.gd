@tool
class_name PuzzleLogic
extends PuzzleNode
## Combines other pieces' states. Invisible in game.
##   gate:     on when all (AND) or any (OR) of its Inputs are on.
##   window:   on when every input has been on within the last Window seconds ("hit all
##             three targets within 3 s": three players at once, or one very clever throw).
##   sequence: on once the inputs have switched on in list order (a wrong one starts over).
## Invert flips the result; Hold Time keeps it on for a while after it would go off (a door
## that closes again 5 s after you step off the plate: race through!).

@export_enum("gate", "window", "sequence") var mode := "gate"
@export_range(0.5, 60.0, 0.5) var window := 3.0
@export var invert := false
@export_range(0.0, 60.0, 0.5) var hold_time := 0.0

var _held_until := -1.0
var _last_on: Array[float] = []
var _was_on: Array[bool] = []
var _seq := 0
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
	var now: float = world.now()
	var on := false
	match mode:
		"window":
			on = _window_on(now)
		"sequence":
			on = _sequence_on()
		_:
			on = inputs_on()
	on = on != invert
	if on:
		_held_until = now + hold_time
		return true
	return now < _held_until


func _input_states() -> Array[bool]:
	var out: Array[bool] = []
	for np in inputs:
		var n := get_node_or_null(np) as PuzzleNode
		out.append(n != null and n.active)
	return out


func _window_on(now: float) -> bool:
	var states := _input_states()
	_last_on.resize(states.size())
	if states.is_empty():
		return false
	for i in states.size():
		if states[i]:
			_last_on[i] = now
	for i in states.size():
		if _last_on[i] <= 0.0 or now - _last_on[i] > window:
			return false
	return true


func _sequence_on() -> bool:
	var states := _input_states()
	if states.is_empty():
		return false
	_was_on.resize(states.size())
	for i in states.size():
		if states[i] and not _was_on[i]: # just switched on
			if _seq >= states.size():
				_seq = 0 # already solved: a new press starts over (unless Latch keeps it on)
			if i == _seq:
				_seq += 1
			else:
				_seq = 1 if i == 0 else 0 # wrong order: start over
		_was_on[i] = states[i]
	return _seq >= states.size()
