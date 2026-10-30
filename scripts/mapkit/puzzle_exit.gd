@tool
class_name PuzzleExit
extends PuzzleNode
## The way out: a glowing archway over a zone of Size. On when every living player is inside
## (and its Inputs are on, if it has any: e.g. the package must be delivered first). In the
## Puzzle mode, that finishes the level.

@export var size := Vector3(4, 3, 4):
	set(v):
		size = v
		_rebuild()

var _parts: Node3D
var _glow: StandardMaterial3D


func _ready() -> void:
	latch = true
	if objective == "":
		objective = "Get everyone to the exit"
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_glow = StandardMaterial3D.new()
	_glow.emission_enabled = true
	var frame := Mats.world(Color(0.35, 0.38, 0.5), 0.4, 0.4)
	for sx in [-1, 1]:
		_parts.add_child(PuzzleNode.box_mesh(Vector3(0.4, size.y, 0.4), frame, Vector3(sx * size.x * 0.5, size.y * 0.5, 0)))
	_parts.add_child(PuzzleNode.box_mesh(Vector3(size.x + 0.4, 0.4, 0.4), frame, Vector3(0, size.y + 0.2, 0)))
	_parts.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.06, size.z), _glow, Vector3(0, 0.03, 0)))
	var sign := Label3D.new()
	sign.text = "EXIT"
	sign.font_size = 96
	sign.outline_size = 18
	sign.modulate = Color(0.4, 1.0, 0.55)
	sign.position = Vector3(0, size.y + 0.75, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_parts.add_child(sign)
	_tint()


func _tint() -> void:
	if _glow == null:
		return
	var c := Color(0.35, 1.0, 0.5)
	_glow.albedo_color = Color(c, 1.0)
	_glow.emission = c
	_glow.emission_energy_multiplier = 3.0 if active else 1.0


func evaluate() -> bool:
	if not inputs.is_empty() and not inputs_on():
		return false
	var alive := 0
	for pl: Player in world.players.values():
		if pl.is_alive():
			alive += 1
	return alive > 0 and players_in(Vector3(0, size.y * 0.5, 0), size).size() == alive


func _state_changed(_play_fx: bool) -> void:
	_tint()
