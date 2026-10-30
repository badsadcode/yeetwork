@tool
class_name Pulley
extends PuzzleNode
## Two wheels (Width apart along local X) and one rope over them, a lift platform hanging on
## each end: Drop A (the -X side) and Drop B below the wheels. The rope's length is fixed,
## so what goes down on one side comes up on the other: the heavier side sinks. Yeets
## standing on a platform weigh 70 kg each; an anvil 300. The counterweight lift: stand on
## one platform, load the other until you rise to the ledge. Platforms stay level and
## under their wheels.

@export_range(1.0, 20.0, 0.1) var width := 5.0:
	set(v):
		width = v
		_rebuild()
@export_range(1.0, 30.0, 0.1) var drop_a := 8.0:
	set(v):
		drop_a = v
		_rebuild()
@export_range(1.0, 30.0, 0.1) var drop_b := 3.0:
	set(v):
		drop_b = v
		_rebuild()

const MIN_DROP := 1.2 # a platform can't come closer to its wheel than this
const PLAYER_MASS := 70.0
const MAX_SPEED := 4.0

var _ids := [-1, -1]
var _ropes: Array[RopeLine] = []
var _wheels: Array[MeshInstance3D] = []
var _parts: Node3D
var _spin := 0.0
var _last_a := -1.0
var _v := 0.0 # server: how fast the rope runs (m/s; + = side A goes up)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_wheels.clear()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var steel := Mats.plastic(Color(0.4, 0.42, 0.48), 0.35)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(width + 0.6, 0.2, 0.3), steel, Vector3(0, 0.45, 0)))
	for sx in [-1, 1]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.35
		cm.bottom_radius = 0.35
		cm.height = 0.15
		w.mesh = cm
		w.rotation_degrees = Vector3(90, 0, 0)
		w.position = Vector3(sx * width * 0.5, 0, 0)
		w.material_override = Mats.plastic(Color(0.9, 0.7, 0.2), 0.4)
		_parts.add_child(w)
		_wheels.append(w)
	if Engine.is_editor_hint():
		var s: Vector3 = Prop.DEFS.lift.size
		for side in 2:
			var drop := drop_a if side == 0 else drop_b
			var x := (-0.5 if side == 0 else 0.5) * width
			_parts.add_child(PuzzleNode.box_mesh(Vector3(0.04, drop, 0.04), steel, Vector3(x, -drop * 0.5, 0)))
			_parts.add_child(PuzzleNode.box_mesh(s, Mats.plastic(Prop.DEFS.lift.color, 0.4), Vector3(x, -drop - s.y * 0.5, 0)))
	else:
		for k in 2:
			var r := RopeLine.new()
			r.width = 0.05
			r.set_color(Color(0.3, 0.3, 0.33))
			_parts.add_child(r)
			_ropes.append(r)


func wheel(side: int) -> Vector3:
	return global_transform * Vector3((-0.5 if side == 0 else 0.5) * width, 0, 0)


func total_length() -> float:
	return drop_a + drop_b


func server_spawn_props() -> void:
	var s: Vector3 = Prop.DEFS.lift.size
	for side in 2:
		var drop := drop_a if side == 0 else drop_b
		var xf := Transform3D(global_transform.basis.orthonormalized(), wheel(side) - Vector3(0, drop + s.y * 0.5, 0))
		var p: Prop = world.server_spawn_prop("lift", xf, Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3.ZERO, {"pulley_piece": puzzle_index, "side": side})
		p.set_meta("map_prop", true)
		p.set_meta("key_prop", true)


func platform(side: int) -> Prop:
	var p: Prop = world.get_prop(_ids[side]) if _ids[side] >= 0 else null
	if p and is_instance_valid(p):
		return p
	for q: Prop in world.props.values():
		if is_instance_valid(q) and q.extra.get("pulley_piece", -1) == puzzle_index and q.extra.get("side", -1) == side:
			_ids[side] = q.prop_id
			return q
	return null


func _tie(p: Prop) -> Vector3:
	return p.global_transform * Vector3(0, p.size.y * 0.5, 0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not world.is_server:
		return
	var a := platform(0)
	var b := platform(1)
	if a == null or b == null or a.held_by != 0 or b.held_by != 0 or a.freeze or b.freeze:
		return
	# A counterweight: each side weighs its platform, what lies on it and the Yeets standing
	# on it. The rope runs (side A up, B down for +) with the acceleration the difference
	# gives, until a platform meets the floor or comes up to its wheel.
	var ma := a.mass + _load(a)
	var mb := b.mass + _load(b)
	_v += Player.GRAVITY * (mb - ma) / (ma + mb) * delta
	_v = clampf(_v * 0.995, -MAX_SPEED, MAX_SPEED)
	var da := wheel(0).y - _tie(a).y
	var db := wheel(1).y - _tie(b).y
	if (_v > 0.0 and (da < MIN_DROP or _blocked(b))) or (_v < 0.0 and (db < MIN_DROP or _blocked(a))):
		_v = 0.0
	# Keep the rope's length: drift (the platforms are driven, not falling) is shared.
	var drift := (da + db - total_length()) * 2.0
	var level := global_transform.basis.orthonormalized()
	for side in 2:
		var p := a if side == 0 else b
		p.gravity_scale = 0.0
		var xf := p.global_transform
		xf.basis = level
		p.global_transform = xf
		p.angular_velocity = Vector3.ZERO
		var w := wheel(side)
		p.linear_velocity = Vector3((w.x - p.global_position.x) * 6.0, (_v if side == 0 else -_v) + drift * 0.5, (w.z - p.global_position.z) * 6.0)
		p.sleeping = false


## What a platform carries: props lying on it (stacked ones too) and Yeets standing on it.
func _load(p: Prop) -> float:
	var top := _tie(p)
	var half := p.size * 0.5
	var m := 0.0
	for q: Prop in world.props.values():
		if not is_instance_valid(q) or q == p or q.held_by != 0:
			continue
		var l := q.global_position - top
		if absf(l.x) < half.x + 0.2 and absf(l.z) < half.z + 0.2 and l.y > -0.1 and l.y < 3.5:
			m += q.mass
	for pl: Player in world.players.values():
		var l := pl.global_position - top
		if pl.is_alive() and absf(l.x) < half.x + 0.2 and absf(l.z) < half.z + 0.2 and l.y > -0.1 and l.y < 0.6:
			m += PLAYER_MASS
	return m


## Something solid right under the platform (it can't go down any further).
func _blocked(p: Prop) -> bool:
	var bottom := p.global_position - Vector3(0, p.size.y * 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(bottom + Vector3.UP * 0.02, bottom + Vector3.DOWN * 0.12, Game.L_WORLD, [p.get_rid()])
	return not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or world == null or _ropes.is_empty():
		return
	for side in 2:
		var p := platform(side)
		if p == null:
			_ropes[side].hide_rope()
			continue
		_ropes[side].draw(wheel(side), _tie(p), 0.0)
	var a := platform(0)
	if a:
		var da := wheel(0).y - _tie(a).y
		if _last_a >= 0.0:
			_spin += (da - _last_a) / 0.35
		_last_a = da
		for w in _wheels:
			w.rotation = Vector3(PI * 0.5, 0, 0)
			w.rotate_object_local(Vector3.UP, _spin)
