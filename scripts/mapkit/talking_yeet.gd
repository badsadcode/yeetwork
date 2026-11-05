@tool
class_name TalkingYeet
extends PuzzleNode
## A Yeet who stands there and talks: walk up and press Use, and they say their next line as a
## subtitle for everyone, with Yeetish babble as the voice; at the last one they keep repeating
## it. They look at whoever's nearest. On once they've said everything, so talking to them can
## open a door or set a StoryFlag. With Inputs, they only talk once those are on.

## Their name: the Use prompt ("Talk to <Name>") and the subtitle.
@export var display_name := "Yeet":
	set(v):
		display_name = v
		_rebuild()
## What they say, in turn, a line per press.
@export var lines: PackedStringArray = []
## How it's babbled: talk, excited, scared, tired; none for silence.
@export_enum("talk", "excited", "scared", "tired", "none") var voice := "talk"
## Their shirt.
@export var shirt := Color(0.3, 0.6, 0.9)
## Their hat, by number (0: the first built-in hat; the Character menu's order).
@export var hat := 0
## Their head extra, by number (0: nothing; the Character menu's order).
@export var face := 0
## Which Yeet: a Classic Yeet, or Noor.
@export_enum("Classic Yeet", "Noor") var character := 0

const REACH_LOOK := 12.0

var _said := 0 # (server)
var _busy_until := 0.0 # (server: not while they're still saying the last one)
var _model: CharacterModel
var _yaw := 0.0
var _parts: Node3D


func _ready() -> void:
	_yaw = rotation.y + PI
	_rebuild()


func evaluate() -> bool:
	return _said >= lines.size() and not lines.is_empty()


func usable() -> bool:
	return not lines.is_empty() and (inputs.is_empty() or inputs_on())


func use_label() -> String:
	return "Talk to %s" % display_name


func use_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func server_used(_pl: Player) -> void:
	var now: float = world.now()
	if now < _busy_until or lines.is_empty():
		return
	var i := mini(_said, lines.size() - 1)
	_busy_until = now + StoryLine.seconds_for(lines[i]) * 0.6
	world.server_story_speak(puzzle_index, i)
	_said = mini(_said + 1, lines.size())


## Every peer: say this line.
func speak(i: int) -> void:
	if i < 0 or i >= lines.size():
		return
	world.hud.show_story_line(display_name, lines[i], voice, global_position + Vector3.UP * 1.4)
	if _model:
		_model.react("happy", 1.2)


func problems() -> Array[String]:
	var out := super.problems()
	if lines.is_empty():
		out.append("%s: they have nothing to say." % name)
	return out


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		var m := StandardMaterial3D.new()
		m.albedo_color = shirt
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.45
		capsule.height = 1.9
		body.mesh = capsule
		body.material_override = m
		body.position.y = 0.95
		_parts.add_child(body)
		var tag := Label3D.new()
		tag.text = display_name
		tag.position.y = 2.3
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_parts.add_child(tag)
		return
	_model = CharacterModel.new()
	_model.expressive = Game.expressive_faces
	_parts.add_child(_model)
	_model.setup(shirt, hat, display_name.hash() & 0xffff, face, -1, 0, character)
	var solid := StaticBody3D.new()
	solid.collision_layer = Game.L_WORLD
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	solid.add_child(shape)
	_parts.add_child(solid)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _model == null or world == null:
		return
	var best := REACH_LOOK
	for pl: Player in world.players.values():
		var to: Vector3 = pl.global_position - global_position
		if pl.is_alive() and to.length() < best:
			best = to.length()
			_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-4.0 * delta))
	_model.global_rotation = Vector3.ZERO
	_model.animate(delta, Vector3.ZERO, Player.F_GROUNDED, _yaw, false)
