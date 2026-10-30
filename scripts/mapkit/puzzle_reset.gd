@tool
class_name PuzzleReset
extends PuzzleNode
## The big red button: walk up and press Use (E) on it, and every map prop whose home is
## inside Area goes back home, and the ones that were destroyed come back. Players can always
## recover a room they've made a mess of; nobody resets it by bumping into it. Gates and
## other pieces are not reset. (It also fires when its Inputs switch on, if it has any.)

## The box whose props are reset: Area Center (relative to the button) and its size.
@export var area := Vector3(16, 8, 16):
	set(v):
		area = v
		_rebuild()
@export var area_center := Vector3.ZERO:
	set(v):
		area_center = v
		_rebuild()

var _parts: Node3D
var _cap: MeshInstance3D
var _cap_mat: StandardMaterial3D
var _cooldown_until := -1.0
var _ghost: MeshInstance3D


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
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 1.0
	cs.shape = cyl
	cs.position.y = 0.5
	body.add_child(cs)
	_parts.add_child(body)
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.3
	pm.bottom_radius = 0.38
	pm.height = 1.0
	post.mesh = pm
	post.position.y = 0.5
	post.material_override = Mats.world(Color(0.95, 0.8, 0.2), 0.5, 0.2)
	_parts.add_child(post)
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.emission_enabled = true
	_cap = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.5
	_cap.mesh = sm
	_cap.position.y = 1.05
	_cap.material_override = _cap_mat
	_parts.add_child(_cap)
	var sign := Label3D.new()
	sign.text = "RESET"
	sign.font_size = 48
	sign.outline_size = 12
	sign.position = Vector3(0, 1.75, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_parts.add_child(sign)
	_tint()
	if Engine.is_editor_hint():
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(1.0, 0.3, 0.2, 0.08)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost = PuzzleNode.box_mesh(area, gm, area_center)
		_parts.add_child(_ghost)


func _tint() -> void:
	if _cap_mat == null:
		return
	var c := Color(1.0, 0.95, 0.6) if active else Color(1.0, 0.15, 0.1)
	_cap_mat.albedo_color = c
	_cap_mat.emission = c
	_cap_mat.emission_energy_multiplier = 3.0 if active else 1.2


func evaluate() -> bool:
	var now: float = world.now()
	if now < _cooldown_until:
		return true # stays lit for a moment after a reset
	return not inputs.is_empty() and inputs_on()


func usable() -> bool:
	return true


func use_label() -> String:
	return "Reset the room"


func use_point() -> Vector3:
	return global_transform * Vector3(0, 1.05, 0)


func server_used(_pl: Player) -> void:
	if world.now() >= _cooldown_until:
		_cooldown_until = world.now() + 2.5 # on the next check it switches on, which resets


func server_switched(on: bool) -> void:
	if on:
		_cooldown_until = world.now() + 2.5
		var n: int = world.server_reset_area(Transform3D(global_transform.basis.orthonormalized(), global_transform * area_center), area)
		world.server_message("Room reset (%d props back home)" % n, Color(1.0, 0.85, 0.4))


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx and active:
		Sfx.play3d("spawn", global_position, 0.0, 0.7)
