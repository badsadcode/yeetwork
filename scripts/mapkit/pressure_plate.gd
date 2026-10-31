@tool
class_name PressurePlate
extends PuzzleNode
## A plate in the floor, on while enough weight stands on it: crates, anvils, barrels, a
## friend (a player counts as 70). The rim glows amber, then green when pressed.
## Masses: crate 25, barrel 40, couch 60, big crate 70, anvil 300, player 70.

@export var size := Vector2(2.4, 2.4):
	set(v):
		size = v
		_rebuild()
@export_range(1.0, 400.0, 1.0) var required_mass := 40.0
@export var color := Color(0.5, 0.55, 0.68):
	set(v):
		color = v
		_rebuild()
## Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look.
## It works the same; only the look changes. A child named "Plate" sinks when it's
## pressed. The plate's collision stays a slab of Size.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

const PLAYER_MASS := 70.0
const HEIGHT := 0.16

var weight := 0.0 # server: what's on it now
var _plate: Node3D
var _custom: Node3D
var _plate_rest := 0.0
var _rim: MeshInstance3D
var _body: StaticBody3D
var _rim_mat: StandardMaterial3D
var _press := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for n in [_plate, _rim, _body, _custom]:
		if n:
			n.queue_free()
	_plate = null
	_rim = null
	_custom = null
	_body = StaticBody3D.new()
	_body.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, HEIGHT, size.y)
	cs.shape = bs
	cs.position.y = HEIGHT * 0.5
	_body.add_child(cs)
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var look := MapTheme.pick(self, "pressure_plate", model)
	_custom = look.instantiate() as Node3D if look else null
	if _custom:
		# The map's own look: a child named "Plate" (if any) sinks when pressed.
		add_child(_custom, false, Node.INTERNAL_MODE_FRONT)
		_plate = _custom.find_child("Plate", true, false) as Node3D
		if _plate:
			_plate_rest = _plate.position.y
		return
	_plate = PuzzleNode.box_mesh(Vector3(size.x - 0.3, HEIGHT, size.y - 0.3), Mats.world(color, 0.5, 0.2), Vector3(0, HEIGHT * 0.5, 0))
	_plate_rest = _plate.position.y
	add_child(_plate, false, Node.INTERNAL_MODE_FRONT)
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.emission_enabled = true
	_rim = PuzzleNode.box_mesh(Vector3(size.x, HEIGHT * 0.6, size.y), _rim_mat, Vector3(0, HEIGHT * 0.3, 0))
	add_child(_rim, false, Node.INTERNAL_MODE_FRONT)
	_tint()


func _tint() -> void:
	if _rim_mat == null:
		return
	var c := Color(0.35, 1.0, 0.45) if active else Color(1.0, 0.7, 0.2)
	_rim_mat.albedo_color = c
	_rim_mat.emission = c
	_rim_mat.emission_energy_multiplier = 2.5 if active else 1.2


func evaluate() -> bool:
	weight = 0.0
	var inv := global_transform.affine_inverse()
	var half := Vector2(size.x * 0.5 + 0.1, size.y * 0.5 + 0.1)
	var on_top := func(p: Vector3, reach: float) -> bool:
		var l: Vector3 = inv * p
		return absf(l.x) < half.x and absf(l.z) < half.y and l.y > -0.2 and l.y < reach
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.held_by == 0 and on_top.call(p.global_position, 1.6 + p.size.y):
			weight += p.mass
	for pl: Player in world.players.values():
		if pl.is_alive() and on_top.call(pl.global_position, 0.6):
			weight += PLAYER_MASS
	return weight >= required_mass


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx:
		Sfx.play3d("zap" if active else "hit", global_position, -4.0, 1.4 if active else 0.8)


func _process(delta: float) -> void:
	if _plate == null:
		return
	_press = move_toward(_press, 1.0 if active else 0.0, delta * 6.0)
	_plate.position.y = _plate_rest - _press * 0.07
