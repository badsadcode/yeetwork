@tool
class_name PuzzleFan
extends PuzzleNode
## A big industrial fan, placed here, blowing along this node's forward direction (-Z). The
## fan itself is a prop: players can grab it with the gravity gun, carry
## it and aim it, put it on a turntable, or block its wind with crates. It blows while its
## Inputs are on (always, without inputs). Light things fly, heavy ones barely move, and the
## Yeets get pushed too (someone will fly into a wall). It comes back home if lost, and a
## PuzzleReset puts it back.

## Wind acceleration near the fan (m/s^2). Players: this times Player Push; props: more for
## light things (a beach ball ~2x), less for heavy ones (an anvil ~5%). Gravity is 24.
@export_range(1.0, 120.0, 1.0) var strength := 32.0
@export_range(1.0, 40.0, 0.5) var reach := 12.0:
	set(v):
		reach = v
		_rebuild()
@export_range(0.3, 4.0, 0.05) var radius := 1.2:
	set(v):
		radius = v
		_rebuild()
@export_range(0.0, 3.0, 0.05) var player_push := 1.0

var _prop_id := -1
var _preview: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
	_preview = Node3D.new()
	add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	_preview.add_child(PuzzleNode.box_mesh(Vector3(1.5, 1.7, 0.8), Mats.plastic(Color(0.3, 0.75, 0.95), 0.3)))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.6, 0.9, 1.0, 0.12)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stream := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = reach
	stream.mesh = cm
	stream.material_override = gm
	stream.rotation_degrees = Vector3(90, 0, 0)
	stream.position = Vector3(0, 0.2, -reach * 0.5)
	_preview.add_child(stream)
	Looks.apply(_preview, MapTheme.pick(self, "fan"), [stream])


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func server_spawn_props() -> void:
	var xf := Transform3D(global_transform.basis.orthonormalized(), global_position + Vector3(0, 0.85, 0))
	var p: Prop = world.server_spawn_prop("fan", xf, Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3.ZERO, {"fan_piece": puzzle_index})
	p.set_meta("map_prop", true)
	p.set_meta("key_prop", true)


## The fan prop (found by its link back to this piece; it can be respawned).
func fan_prop() -> Prop:
	var p: Prop = world.get_prop(_prop_id) if _prop_id >= 0 else null
	if p and is_instance_valid(p):
		return p
	for q: Prop in world.props.values():
		if is_instance_valid(q) and q.extra.get("fan_piece", -1) == puzzle_index:
			_prop_id = q.prop_id
			return q
	return null


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not active:
		return
	var fan := fan_prop()
	if fan == null:
		return
	var origin := fan.global_position + fan.global_transform.basis.y * 0.2
	var dir := -fan.global_transform.basis.z.normalized()
	# Props: the server moves them.
	if world.is_server:
		for p: Prop in world.props.values():
			if not is_instance_valid(p) or p == fan or p.held_by != 0 or p.freeze:
				continue
			var k := _strength_at(p.global_position, origin, dir, p.size.length() * 0.3)
			if k > 0.0:
				p.linear_velocity += dir * strength * clampf(15.0 / p.mass, 0.05, 2.0) * k * delta
				p.sleeping = false
	# Players: each one is pushed on the peer that controls them.
	for pl: Player in world.players.values():
		if pl.is_alive() and pl.is_controlled_here():
			var k := _strength_at(pl.body_center(), origin, dir, 0.35)
			if k > 0.0:
				pl.velocity += dir * strength * player_push * k * delta


## 0..1: how hard the wind blows at `pos` (full near the fan's axis, fading with distance).
func _strength_at(pos: Vector3, origin: Vector3, dir: Vector3, extent: float) -> float:
	var rel := pos - origin
	var along := rel.dot(dir)
	if along < -0.3 or along > reach:
		return 0.0
	var side := (rel - dir * along).length() - extent
	if side > radius:
		return 0.0
	return (1.0 - clampf(along / reach, 0.0, 1.0) * 0.6) * (1.0 - clampf(side / radius, 0.0, 1.0) * 0.5)
