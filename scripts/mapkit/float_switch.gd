@tool
class_name FloatSwitch
extends PuzzleNode
## A float on a post: on while the water in its FloodZone stands at least Level above the
## node (the float rides up the post and its lamp turns green). Fill the room to open the
## hatch; use a PuzzleLogic with Invert for "until the water's drained".

@export_range(0.1, 10.0, 0.1) var level := 1.0:
	set(v):
		level = v
		_rebuild()

## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
## A child named "Float" rides up and down on the water.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var _zone: FloodZone
var _parts: Node3D
var _ball: Node3D
var _lamp_mat: StandardMaterial3D
var _ride := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var post_h := level + 0.6
	var metal := Mats.plastic(Color(0.55, 0.58, 0.65), 0.35)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.1, post_h, 0.1), metal, Vector3(0, post_h * 0.5, 0)))
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.5, 0.06, 0.5), metal, Vector3(0, 0.03, 0)))
	# A ring at the trigger height.
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	var mark := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.17
	mark.mesh = tm
	mark.material_override = _lamp_mat
	mark.position.y = level
	_parts.add_child(mark)
	_ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	_ball.mesh = sm
	_ball.material_override = Mats.plastic(Color(1.0, 0.55, 0.15), 0.4)
	_ball.position.y = 0.25
	_parts.add_child(_ball)
	_tint()
	var look := Looks.apply(_parts, MapTheme.pick(self, "float_switch", model))
	if Looks.part(look, "Float"):
		_ball = Looks.part(look, "Float")


func _tint() -> void:
	if _lamp_mat == null:
		return
	var c := Color(0.35, 1.0, 0.45) if active else Color(1.0, 0.7, 0.2)
	_lamp_mat.albedo_color = c
	_lamp_mat.emission = c
	_lamp_mat.emission_energy_multiplier = 2.5 if active else 1.0


func link() -> void:
	_zone = FloodZone.at(world, global_position)


func evaluate() -> bool:
	return _zone != null and _zone.surface_at(global_position) >= global_position.y + level


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx:
		Sfx.play3d("zap" if active else "hit", global_position + Vector3.UP * level, -4.0, 1.4 if active else 0.8)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ball == null or _zone == null:
		return
	var s := _zone.surface_at(global_position) - global_position.y
	var target := clampf(s - 0.05, 0.25, level + 0.4)
	_ride = move_toward(_ride, target, delta * 2.5)
	_ball.position.y = _ride


func problems() -> Array[String]:
	var out := super.problems()
	if FloodZone.at(world, global_position) == null and world != null:
		out.append("%s: the float switch isn't inside a FloodZone." % name)
	return out
