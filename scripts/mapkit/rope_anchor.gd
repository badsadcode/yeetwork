@tool
class_name RopeAnchor
extends PuzzleNode
## A rope from this point (a ceiling, a beam) holding a prop, which it spawns hanging Length
## below. The prop swings on the rope, and Yeets can push it, punt it, even grab it, but it
## won't come off. The rope can be cut: fire burns through it in a second, and its Inputs
## (a lever, a plate) let go of it. It's on once cut: drop the anvil on the plate, the cage
## on the beacon, the crate into the water. Cut is cut (for good).

@export_enum("crate", "crate_big", "barrel", "boom_barrel", "anvil", "couch", "tire", "battery", "boulder", "lost_yeet") var kind := "anvil":
	set(v):
		kind = v
		_rebuild()
@export_range(0.5, 20.0, 0.1) var length := 3.0:
	set(v):
		length = v
		_rebuild()
@export var burnable := true

const BURN_TIME := 1.0

var cut := false
var _burn := 0.0
var _prop_id := -1
var _rope: RopeLine
var _preview: Node3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		_rope = RopeLine.new()
		add_child(_rope)
	var mount := PuzzleNode.box_mesh(Vector3(0.4, 0.15, 0.4), Mats.plastic(Color(0.35, 0.37, 0.42), 0.4))
	add_child(mount, false, Node.INTERNAL_MODE_FRONT)


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
	_preview = Node3D.new()
	add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var line := PuzzleNode.box_mesh(Vector3(0.05, length, 0.05), Mats.plastic(Color(0.55, 0.42, 0.28), 0.9), Vector3(0, -length * 0.5, 0))
	_preview.add_child(line)
	var s: Vector3 = Prop.DEFS[kind].size
	_preview.add_child(PuzzleNode.box_mesh(s if Prop.DEFS[kind].shape == "box" else Vector3(s.x * 2, s.y, s.x * 2), Mats.plastic(Prop.DEFS[kind].color, 0.4), Vector3(0, -length - s.y * 0.5, 0)))


func server_spawn_props() -> void:
	var s: Vector3 = Prop.DEFS[kind].size
	var xf := Transform3D(Basis.IDENTITY, global_position - Vector3(0, length + s.y * 0.5, 0))
	var p: Prop = world.server_spawn_prop(kind, xf, Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3.ZERO, {"rope_piece": puzzle_index})
	p.set_meta("map_prop", true)
	p.set_meta("key_prop", true)


## The hanging prop (found by its link back to this piece: it can come back after it's lost).
func hung_prop() -> Prop:
	var p: Prop = world.get_prop(_prop_id) if _prop_id >= 0 else null
	if p and is_instance_valid(p):
		return p
	for q: Prop in world.props.values():
		if is_instance_valid(q) and q.extra.get("rope_piece", -1) == puzzle_index:
			_prop_id = q.prop_id
			return q
	return null


## Where the rope ties on: the top of the prop.
func _tie(p: Prop) -> Vector3:
	return p.global_transform * Vector3(0, p.size.y * 0.5, 0)


func evaluate() -> bool:
	return cut


func server_switched(on: bool) -> void:
	if on:
		world.server_fx("crack", global_position, Vector3.DOWN, 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null:
		return
	if not world.is_server or cut:
		return
	var p := hung_prop()
	if p == null:
		return
	var tie := _tie(p)
	# Cut: by its inputs, or burnt through.
	if not inputs.is_empty() and inputs_on():
		cut = true
		return
	if burnable:
		var on_fire := false
		for k in 4:
			if world.fire_near(global_position.lerp(tie, (k + 0.5) / 4.0), 0.3, p):
				on_fire = true
		_burn = _burn + delta if on_fire else maxf(_burn - delta * 0.5, 0.0)
		if _burn >= BURN_TIME:
			cut = true
			world.server_fx("steam", global_position.lerp(tie, 0.5), Vector3.UP, 0.5)
			return
	if p.held_by != 0 or p.freeze:
		return
	# The rope pulls when it's taut: no moving away from the anchor, and back to its length.
	var to := global_position - tie
	var d := to.length()
	if d <= length or d < 0.01:
		return
	var n := to / d
	var out := maxf(p.linear_velocity.dot(-n), 0.0)
	p.apply_impulse(n * p.mass * (out + minf((d - length) * 10.0, 6.0)), tie - p.global_position)
	p.sleeping = false


func is_machine() -> bool:
	return true


func machine_state() -> PackedFloat32Array:
	return PackedFloat32Array([1.0 if cut else 0.0, _burn])


func apply_machine_state(s: PackedFloat32Array) -> void:
	if s.size() >= 2:
		cut = s[0] > 0.5
		_burn = s[1]


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _rope == null or world == null:
		return
	var p := hung_prop() if not cut else null
	if p == null:
		_rope.hide_rope()
		return
	var tie := _tie(p)
	_rope.draw(global_position, tie, maxf(length - global_position.distance_to(tie), 0.0))
	# Smouldering: the rope glows as it burns.
	_rope.set_color(Color(0.55, 0.42, 0.28).lerp(Color(1.0, 0.45, 0.1), clampf(_burn / BURN_TIME, 0.0, 1.0)), _burn * 3.0)
