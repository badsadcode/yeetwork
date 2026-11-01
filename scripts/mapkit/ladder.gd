@tool
class_name Ladder
extends Node3D
## A ladder up a wall (a building, a ship's side, out of a pool or the sea): walk up to it
## facing the wall and hold forward (or Jump) to climb, back (or Crouch) to go down, let go and
## you hang on; at the top it lifts you up and over the edge. Put the node at the ladder's foot
## against the wall, its blue arrow (+Z) pointing away from the wall, toward the climber.
## Bots in the sea swim to the ladders whose foot is in the water (MapSettings' ocean).
## Model: your own ladder (its origin at the foot, up along +Y, the wall behind it at -Z);
## climbing works the same whatever it looks like.

@export_range(1.0, 40.0, 0.1) var height := 4.0:
	set(v):
		height = v
		_rebuild()
## How hard the top throws you on over the edge (m/s; 0: just up). A rail or a wide ledge at
## the top wants more.
@export_range(0.0, 12.0, 0.5) var over_the_top := 6.0
## Instead of that, exactly how the top throws you (m/s, the ladder's own frame: x along the
## wall, y up, z out from it; zero: Over The Top). For a ladder that lets you off sideways.
@export var top_throw := Vector3.ZERO
## Your own model for it (instead of the built-in yellow rails, and the map theme's).
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

const WIDTH := 0.5
const RUNG_GAP := 0.35

var _parts: Node3D
var _foot: Node3D


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	var t := TriggerVolume.new()
	t.position = Vector3(0, height * 0.5, 0.5)
	add_child(t)
	t.setup(TriggerVolume.Kind.LADDER, Vector3(1.5, height, 1.0), top_throw if top_throw != Vector3.ZERO else Vector3(0, 3.0, -over_the_top))
	# Where a swimming bot heads for (just off its foot), how tall it is, which way to face.
	_foot = Node3D.new()
	_foot.position = Vector3(0, 0, 0.8)
	_foot.set_meta("height", height)
	_foot.set_meta("into", Vector3.FORWARD) # (in its own frame: toward the wall)
	add_child(_foot)


## (Arena) the spot off its foot bots swim to.
func foot() -> Node3D:
	return _foot


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var yellow := Mats.plastic(Color(0.95, 0.75, 0.15), 0.4)
	for s in [-1, 1]:
		_parts.add_child(PuzzleNode.box_mesh(Vector3(0.07, height, 0.07), yellow, Vector3(s * WIDTH * 0.5, height * 0.5, 0.1)))
	var rungs := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rung := BoxMesh.new()
	rung.size = Vector3(WIDTH, 0.05, 0.05)
	mm.mesh = rung
	mm.instance_count = maxi(int(height / RUNG_GAP), 1)
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.25 + i * RUNG_GAP, 0.1)))
	rungs.multimesh = mm
	rungs.material_override = yellow
	_parts.add_child(rungs)
	Looks.apply(_parts, MapTheme.pick(self, "ladder", model))
