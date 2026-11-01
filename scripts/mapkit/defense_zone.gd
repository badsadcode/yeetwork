@tool
class_name DefenseZone
extends Node3D
## MegaYeet: a zone of the fortress (a box, Size, its bottom on the node). Every monster inside
## drains the team's Fortress meter each second, more the deeper the zone: Level 1 the outer
## walls, 2 the courtyard, 3 the inner keep (where zones overlap, the deepest counts). The
## HUD names a zone when monsters get in (Zone Name). Shown in the editor as a tinted box; in
## the game a faint line on the ground marks its edge (Show Edge).

## How deep in the fortress it is: 1 the outer walls, 2 the courtyard, 3 the inner keep. Deeper
## zones drain the meter faster.
@export_range(1, 3) var level := 1:
	set(v):
		level = v
		_rebuild()
## The zone's box, metres (its bottom on the node).
@export var size := Vector3(40, 8, 40):
	set(v):
		size = v
		_rebuild()
## What the HUD calls it when monsters get in ("the gatehouse").
@export var zone_name := "":
	set(v):
		zone_name = v
## Meter points a monster inside drains each second (0: the level's usual: 1, 3, 6).
@export var drain := 0.0
## A faint line on the ground marks its edge in the game.
@export var show_edge := true:
	set(v):
		show_edge = v
		_rebuild()

const DRAIN := [0.0, 1.0, 3.0, 6.0]
const COLORS := [Color.WHITE, Color(1.0, 0.85, 0.2), Color(1.0, 0.5, 0.15), Color(1.0, 0.2, 0.2)]
const NAMES := ["", "the outer walls", "the courtyard", "the keep"]
const ALERTS := ["", "Monsters at the outer walls!", "Monsters in the courtyard!", "MONSTERS IN THE KEEP!"]

var _parts: Node3D


func _ready() -> void:
	_rebuild()


func drain_rate() -> float:
	return drain if drain > 0.0 else DRAIN[level]


func display_name() -> String:
	return zone_name if zone_name != "" else NAMES[level]


## What the HUD says when monsters first get in.
func alert() -> String:
	return "Monsters in %s!" % zone_name if zone_name != "" and zone_name != NAMES[level] else ALERTS[level]


## Inside this zone (a world point)?
func has_point(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 and l.y >= -0.5 and l.y <= size.y


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var c: Color = COLORS[level]
	if Engine.is_editor_hint():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c, 0.12)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_parts.add_child(PuzzleNode.box_mesh(size, m, Vector3(0, size.y * 0.5, 0)))
	if not show_edge:
		return
	# The edge: four thin glowing strips on the ground.
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(c, 0.55)
	line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.emission_enabled = true
	line.emission = c
	var w := 0.18
	for s in [-1, 1]:
		_parts.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.02, w), line, Vector3(0, 0.04, s * (size.z * 0.5 - w * 0.5))))
		_parts.add_child(PuzzleNode.box_mesh(Vector3(w, 0.02, size.z), line, Vector3(s * (size.x * 0.5 - w * 0.5), 0.04, 0)))
	for mi: MeshInstance3D in _parts.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
