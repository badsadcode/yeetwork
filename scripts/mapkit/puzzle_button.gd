@tool
class_name PuzzleButton
extends PuzzleNode
## A button on the floor or a wall (rotate it). Press:
##   touch:   on while anything touches its cap: a player, a prop leaning on it, a ball
##            rolling over it, a thrown Yeet.
##   use key: players walk up and press Use (E); props can't press it.
## Hold Time keeps it on for a while after it's released (use key: after the press; 0 makes
## each press switch it on or off).

@export var size := Vector2(1.2, 1.2):
	set(v):
		size = v
		_rebuild()
@export_enum("touch", "use key") var press := "touch"
@export_range(0.0, 60.0, 0.5) var hold_time := 0.0
## Use key: what the prompt says, "[E] <label>".
@export var label := "Press"
@export var color := Color(0.45, 0.48, 0.6):
	set(v):
		color = v
		_rebuild()

const CAP := 0.22

var _parts: Node3D
var _cap: MeshInstance3D
var _cap_mat: StandardMaterial3D
var _held_until := -1.0
var _toggled := false
var _press := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x + 0.3, 0.12, size.y + 0.3)
	cs.shape = bs
	cs.position.y = 0.06
	body.add_child(cs)
	_parts.add_child(body)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(size.x + 0.3, 0.12, size.y + 0.3), Mats.world(color, 0.5, 0.3), Vector3(0, 0.06, 0)))
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.emission_enabled = true
	_cap = PuzzleNode.box_mesh(Vector3(size.x, CAP, size.y), _cap_mat, Vector3(0, 0.12 + CAP * 0.5, 0))
	_parts.add_child(_cap)
	_tint()


func _tint() -> void:
	if _cap_mat == null:
		return
	var c := Color(0.35, 1.0, 0.45) if active else Color(1.0, 0.45, 0.2)
	_cap_mat.albedo_color = c
	_cap_mat.emission = c
	_cap_mat.emission_energy_multiplier = 2.2 if active else 0.8


func usable() -> bool:
	return press == "use key"


func use_label() -> String:
	return label


func use_point() -> Vector3:
	return global_transform * Vector3(0, 0.25, 0)


func server_used(_pl: Player) -> void:
	if hold_time > 0.0:
		_held_until = world.now() + hold_time
	else:
		_toggled = not _toggled


func evaluate() -> bool:
	var now: float = world.now()
	if press == "use key":
		return _toggled or now < _held_until
	var inv := global_transform.affine_inverse()
	var touched := false
	var reach := Vector2(size.x * 0.5 + 0.15, size.y * 0.5 + 0.15)
	for p: Prop in world.props.values():
		if not is_instance_valid(p):
			continue
		var l: Vector3 = inv * p.global_position
		var r := p.size.length() * 0.5
		if absf(l.x) < reach.x + r * 0.5 and absf(l.z) < reach.y + r * 0.5 and l.y > 0.0 and l.y < 0.35 + r:
			touched = true
			break
	if not touched:
		for pl: Player in world.players.values():
			if not pl.is_alive():
				continue
			var l: Vector3 = inv * pl.global_position
			var lc: Vector3 = inv * pl.body_center()
			if absf(l.x) < reach.x + 0.35 and absf(l.z) < reach.y + 0.35 and minf(l.y, lc.y) < 0.6 and maxf(l.y, lc.y) > -0.9:
				touched = true
				break
	if touched:
		_held_until = now + hold_time
		return true
	return now < _held_until


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx:
		Sfx.play3d("zap" if active else "hit", global_position, -4.0, 1.6 if active else 0.9)


func _process(delta: float) -> void:
	if _cap == null:
		return
	_press = move_toward(_press, 1.0 if active else 0.0, delta * 8.0)
	_cap.position.y = 0.12 + CAP * 0.5 - _press * CAP * 0.6
