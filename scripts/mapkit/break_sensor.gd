@tool
class_name BreakSensor
extends PuzzleNode
## Turns on once a BreakableSlab is broken enough: wreck the wall, the pillar, the statue
## and the door opens (destruction puzzles). Invisible in game; place it anywhere.

## The BreakableSlab to watch.
@export var slab: NodePath
## How much of it must be broken (percent of its pieces).
@export_range(1.0, 100.0, 1.0) var percent := 30.0

var _d: Destructible
var _preview: MeshInstance3D


func _ready() -> void:
	latch = true
	if Engine.is_editor_hint():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.6, 0.2)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.2)
		_preview = PuzzleNode.box_mesh(Vector3(0.5, 0.5, 0.5), m)
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)


func link() -> void:
	var n := get_node_or_null(slab)
	if n and n.has_meta("built"):
		_d = n.get_meta("built")


func evaluate() -> bool:
	if _d == null or not is_instance_valid(_d) or _d.cells.is_empty():
		return false
	return _d.broken_cells.size() * 100.0 / _d.cells.size() >= percent


func problems() -> Array[String]:
	var out := super.problems()
	if not get_node_or_null(slab) is BreakableSlab and _d == null:
		out.append("%s: Slab must point at a BreakableSlab." % name)
	return out
