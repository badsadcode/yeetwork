@tool
class_name Wire
extends PuzzleNode
## A power cable through Points (this node's space, starting here), live while its inputs
## are on: it glows and passes the power on (other pieces can take it as an input, like a
## relay). Show where the power goes: from a battery socket to a magnet, from contacts to a
## door. Zap Water: a live wire whose end lies in water shocks the Yeets swimming near it.

@export var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -4)]):
	set(v):
		points = v
		_rebuild()
@export var zap_water := false

const OFF_COLOR := Color(0.12, 0.13, 0.16)
const ON_COLOR := Color(0.35, 0.85, 1.0)

var _lines: Array[RopeLine] = []
var _preview: Node3D
var _zap_t := 0.0
var _pulse := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
		_preview = null
	if Engine.is_editor_hint():
		_preview = Node3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
		for k in points.size() - 1:
			var a := points[k]
			var b := points[k + 1]
			var mi := PuzzleNode.box_mesh(Vector3(0.06, 0.06, a.distance_to(b)), Mats.plastic(ON_COLOR, 0.4), (a + b) * 0.5)
			if a.distance_to(b) > 0.01:
				mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
			_preview.add_child(mi)


func evaluate() -> bool:
	return inputs_on()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _lines.size() != points.size() - 1:
		for l in _lines:
			l.queue_free()
		_lines.clear()
		for k in points.size() - 1:
			var l := RopeLine.new()
			l.width = 0.07
			add_child(l)
			_lines.append(l)
	_pulse += delta * 5.0
	for k in _lines.size():
		_lines[k].draw(global_transform * points[k], global_transform * points[k + 1], 0.0)
		if active:
			_lines[k].set_color(ON_COLOR, 1.5 + sin(_pulse - k * 1.3) * 0.8)
		else:
			_lines[k].set_color(OFF_COLOR, 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not zap_water or not active or not world.is_server:
		return
	_zap_t -= delta
	if _zap_t > 0.0:
		return
	_zap_t = 0.6
	var end := global_transform * points[points.size() - 1]
	if not world.in_water(end + Vector3.UP * 0.05):
		return
	world.server_fx("zap", end, Vector3.UP, 1.0)
	for pl: Player in world.players.values():
		if pl.is_alive() and pl.global_position.distance_to(end) < 6.0 and (world.in_water(pl.global_position + Vector3.UP * 0.3)):
			world.server_zap(pl, 8.0)
