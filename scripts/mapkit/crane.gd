@tool
class_name Crane
extends Node3D
## A crane (a dock, a building site, a ship's deck): it slews to and fro on its own, a load
## hanging from its jib on a cable. The load is solid: ride it, or get swept off a roof when it
## comes round. Every player sees the same crane with nothing sent (it runs off the match
## clock). Put the node on the ground (or a deck) where its pedestal stands.
## - Heading: where the jib points in the middle of its sweep (degrees round from the node's
##   +X), Sweep: how far either side it goes, Period: seconds there and back.
## - Model: your own crane: a part named "Turret" slews (its jib along the Turret's +X) and an
##   empty "Hook" on it is where the cable hangs. Load Model: what hangs (in a Load Size box,
##   its origin in the middle). The pedestal's collision is a Pedestal Size box either way.

## How high its jib is, metres.
@export_range(2.0, 60.0, 0.5) var height := 12.0:
	set(v):
		height = v
		_rebuild()
## How long its jib is, metres (the cable hangs from its end).
@export_range(3.0, 60.0, 0.5) var jib := 14.0:
	set(v):
		jib = v
		_rebuild()
## How far the load hangs below the jib, metres.
@export_range(0.5, 30.0, 0.5) var cable := 3.0
## Where the jib points in the middle of its sweep: degrees round from the node's +X.
@export_range(-180.0, 180.0, 1.0) var heading := 180.0:
	set(v):
		heading = v
		_rebuild()
## How far it slews either side of Heading, degrees.
@export_range(0.0, 180.0, 1.0) var sweep := 69.0
## Seconds to slew there and back.
@export_range(4.0, 300.0, 1.0) var period := 48.0
## The load's box, metres (it's solid: ride it).
@export var load_size := Vector3(6.1, 2.6, 2.44):
	set(v):
		load_size = v
		_rebuild()
## The built-in load's colour.
@export var load_color := Color(0.95, 0.55, 0.1)
## The pedestal's box, metres (its collision; height 0: up to Height).
@export var pedestal_size := Vector3(2.0, 0.0, 2.0)
## Your own crane: a part named "Turret" slews (its jib along the Turret's +X), an empty "Hook"
## is where the cable hangs.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()
## Your own load (its origin in its middle), in a Load Size box.
@export var load_model: PackedScene:
	set(v):
		load_model = v
		_rebuild()

var _preview: Node3D
var crane: ShipCrane # (in the game)


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
		return
	crane = ShipCrane.new()
	crane.height = height
	crane.jib = jib
	crane.cable = cable
	crane.slew_center = deg_to_rad(heading)
	crane.slew_amp = deg_to_rad(sweep)
	crane.period = period
	crane.load_size = load_size
	crane.load_color = load_color
	crane.model = MapTheme.pick(self, "crane", model)
	crane.load_model = load_model
	add_child(crane)
	var ped_h := pedestal_size.y if pedestal_size.y > 0.0 else height
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(pedestal_size.x, ped_h, pedestal_size.z)
	cs.shape = box
	cs.position.y = ped_h * 0.5
	body.add_child(cs)
	add_child(body)


## (World, on every peer once the match is up) the clock it runs off.
func set_world(w: Node) -> void:
	if crane:
		crane.world = w


## The editor: the crane at the middle of its sweep and its load's box.
func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
	_preview = Node3D.new()
	add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var yellow := Mats.plastic(ShipCrane.YELLOW, 0.5)
	var dir := Basis(Vector3.UP, deg_to_rad(heading))
	var look := MapTheme.pick(self, "crane", model)
	if look:
		_preview.add_child(look.instantiate())
	else:
		_preview.add_child(PuzzleNode.box_mesh(Vector3(1.8, height, 1.8), yellow, Vector3(0, height * 0.5, 0)))
		var arm := PuzzleNode.box_mesh(Vector3(jib, 0.3, 0.7), yellow, Vector3(0, height + 2.1, 0) + dir * Vector3(jib * 0.5, 0, 0))
		arm.basis = dir
		_preview.add_child(arm)
	var tip := Vector3(0, height + 1.6, 0) + dir * Vector3(jib, 0, 0)
	var hang := tip + Vector3.DOWN * (cable + load_size.y * 0.5)
	var l: Node3D = load_model.instantiate() if load_model else PuzzleNode.box_mesh(load_size, Mats.plastic(load_color, 0.6), Vector3.ZERO)
	l.position = hang
	l.basis = dir * Basis(Vector3.UP, PI * 0.5)
	_preview.add_child(l)
