@tool
class_name Seesaw
extends PuzzleNode
## The Yeetapult: a plank on a pivot, along its local X. It tips toward the heavier side
## (props and players weigh what they weigh), takes a kick from things landing on it, and
## when an end slams down hard, whatever stands on the other end is launched up and away:
## drop an anvil on the red end, fly off the yellow one. Launch Boost scales the yeet.
## The server simulates it and streams the angle; the node is the pivot.

@export_range(2.0, 16.0, 0.1) var length := 7.0:
	set(v):
		length = v
		_rebuild()
@export_range(0.6, 6.0, 0.1) var width := 1.6:
	set(v):
		width = v
		_rebuild()
## Height of the pivot above the floor (the node sits at the pivot).
@export_range(0.3, 3.0, 0.05) var pivot_height := 0.8:
	set(v):
		pivot_height = v
		_rebuild()
@export_range(5.0, 40.0, 0.5) var max_angle := 18.0
@export_range(0.5, 4.0, 0.05) var launch_boost := 1.6
@export var color := Color(0.85, 0.62, 0.35):
	set(v):
		color = v
		_rebuild()

## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
## A child named "Plank" tips with the plank (the rest stays put).
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

const PLANK_MASS := 40.0
const THICK := 0.3
const G := 24.0 # the game's gravity
const PLAYER_MASS := 70.0

var angle := 0.0 # radians, positive: the +X (red) end down
var omega := 0.0
var _target := 0.0
var _impulse := 0.0
var _on_plank := {} # Player -> true (server: standing on it last check)
var _launches: Array = [] # [Player, velocity]: sent the tick after the slam, once the plank has stopped
var _body: AnimatableBody3D
var _parts: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	# The fulcrum: a wedge under the pivot.
	var wedge := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.0, pivot_height, width * 0.8)
	wedge.mesh = pm
	wedge.position.y = -pivot_height * 0.5
	wedge.material_override = Mats.world(Color(0.4, 0.43, 0.55), 0.5, 0.4)
	_parts.add_child(wedge)
	var base := StaticBody3D.new()
	base.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	base.collision_mask = 0
	var bcs := CollisionShape3D.new()
	var bbs := BoxShape3D.new()
	bbs.size = Vector3(0.5, pivot_height - 0.2, width * 0.8)
	bcs.shape = bbs
	bcs.position.y = -pivot_height * 0.5 - 0.1
	base.add_child(bcs)
	_parts.add_child(base)
	# The plank.
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = true
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta("seesaw", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, THICK, width)
	cs.shape = bs
	_body.add_child(cs)
	_body.add_child(PuzzleNode.box_mesh(Vector3(length, THICK, width), Mats.world(color, 0.6, 0.1)))
	# The ends: red where you drop the heavy thing, yellow where you stand to fly.
	var drop_end := Mats.world(Color(0.95, 0.25, 0.2), 0.5, 0.1, 0.4)
	var fly_end := Mats.world(Color(1.0, 0.85, 0.2), 0.5, 0.1, 0.4)
	_body.add_child(PuzzleNode.box_mesh(Vector3(1.4, 0.04, width - 0.1), drop_end, Vector3(length * 0.5 - 0.8, THICK * 0.5 + 0.01, 0)))
	_body.add_child(PuzzleNode.box_mesh(Vector3(1.4, 0.04, width - 0.1), fly_end, Vector3(-length * 0.5 + 0.8, THICK * 0.5 + 0.01, 0)))
	_parts.add_child(_body)
	Looks.attach(Looks.apply(_parts, MapTheme.pick(self, "seesaw", model)), "Plank", _body)
	_pose()


func _pose() -> void:
	if _body:
		_body.rotation.z = -angle # +angle tips the +X end down


func is_machine() -> bool:
	return true


func machine_state() -> PackedFloat32Array:
	return PackedFloat32Array([angle, omega])


func apply_machine_state(s: PackedFloat32Array) -> void:
	if s.size() >= 2:
		_target = s[0]
		omega = s[1]


## Server: a prop hit the plank: its fall kicks that side down.
func server_landed(p: Prop) -> void:
	var l := _local(p.global_position)
	var down := maxf(0.0, -p._prev_velocity.y)
	if absf(l.x) <= length * 0.5 + 0.3:
		_impulse += p.mass * down * l.x * 0.9


## A point in the plank's (unrotated) frame: x along it from the pivot, y above its top.
func _local(world_pos: Vector3) -> Vector3:
	var l := global_transform.affine_inverse() * world_pos
	var top := THICK * 0.5 - l.x * tan(angle)
	return Vector3(l.x, l.y - top, l.z)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null or world == null:
		return
	if world.is_server:
		_simulate(delta)
	else:
		angle = lerpf(angle, _target, 1.0 - exp(-15.0 * delta))
	_pose()


func _simulate(dt: float) -> void:
	for e in _launches:
		if is_instance_valid(e[0]):
			world.server_launch_player(e[0], e[1], true, 0.0, 0)
	_launches.clear()
	var inertia := PLANK_MASS * length * length / 12.0
	var torque := 0.0
	var half := length * 0.5
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0:
			continue
		var l := _local(p.global_position)
		if absf(l.x) <= half and absf(l.z) <= width * 0.5 + 0.2 and l.y > -0.3 and l.y < p.size.y + 0.6:
			torque += p.mass * G * l.x
			inertia += p.mass * l.x * l.x
	var standing := {}
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var l := _local(pl.global_position)
		if absf(l.x) <= half and absf(l.z) <= width * 0.5 + 0.3 and l.y > -0.3 and l.y < 0.7:
			standing[pl] = l.x
			torque += PLAYER_MASS * G * l.x
			inertia += PLAYER_MASS * l.x * l.x
			if not _on_plank.has(pl) and pl.velocity.y < -3.0:
				_impulse += PLAYER_MASS * -pl.velocity.y * l.x * 0.9 # jumped onto it
	_on_plank = standing
	omega += torque / inertia * dt + _impulse / inertia
	_impulse = 0.0
	omega *= exp(-0.8 * dt)
	angle += omega * dt
	var lim := deg_to_rad(max_angle)
	if angle > lim or angle < -lim:
		var side := signf(angle)
		angle = clampf(angle, -lim, lim)
		if signf(omega) == side:
			_slam(-side, absf(omega))
			omega = -omega * 0.15


## An end slammed down: launch what stands on the rising end (side -1: the -X end).
func _slam(side: float, w: float) -> void:
	if w < 1.0:
		return
	var out := global_transform.basis.x.normalized() * side
	var dir := (Vector3.UP + out * 0.35).normalized()
	var flew := false
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var l := _local(pl.global_position)
		if signf(l.x) == side and absf(l.x) > 0.6 and absf(l.x) <= length * 0.5 and absf(l.z) <= width * 0.5 + 0.3 and l.y > -0.3 and l.y < 1.0:
			# (Next tick: in this one the plank is still rising into them, which would
			# count as standing on it and eat the launch.)
			_launches.append([pl, dir * w * absf(l.x) * launch_boost])
			flew = true
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0:
			continue
		var l := _local(p.global_position)
		if signf(l.x) == side and absf(l.x) > 0.6 and absf(l.x) <= length * 0.5 and absf(l.z) <= width * 0.5 + 0.2 and l.y > -0.3 and l.y < p.size.y + 0.6:
			p.linear_velocity = dir * w * absf(l.x) * launch_boost
			p.sleeping = false
			flew = true
	world.server_fx("impact:wood", global_transform * Vector3(-side * length * 0.5, 0, 0), Vector3.DOWN, clampf(w * 0.4, 0.3, 2.0), Vector3.UP)
	if flew:
		world.server_fx("punt", global_transform * Vector3(side * length * 0.5, 0.3, 0), Vector3.UP, 1.0)
