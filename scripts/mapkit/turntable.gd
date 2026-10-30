@tool
class_name Turntable
extends PuzzleNode
## A round platform turning around its Y axis: always, or while its Inputs are on (a button
## that turns the fan around). Whatever stands on it rides along: props, Yeets, a fan.
## The server turns it and streams the angle; everyone sees the same.

@export_range(0.5, 12.0, 0.1) var radius := 3.0:
	set(v):
		radius = v
		_rebuild()
@export_range(0.1, 2.0, 0.05) var thickness := 0.4:
	set(v):
		thickness = v
		_rebuild()
## Degrees per second (negative: the other way).
@export_range(-360.0, 360.0, 1.0) var speed := 30.0
@export var color := Color(0.55, 0.6, 0.75):
	set(v):
		color = v
		_rebuild()

var angle := 0.0
var _target := 0.0
var _body: AnimatableBody3D
var _rim_mat: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body:
		_body.queue_free()
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = true
	_body.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = thickness
	cs.shape = cyl
	cs.position.y = thickness * 0.5
	_body.add_child(cs)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = thickness
	cm.radial_segments = 48
	disc.mesh = cm
	disc.position.y = thickness * 0.5
	disc.material_override = Mats.world(color, 0.5, 0.3)
	_body.add_child(disc)
	# Stripes across the top, so the turning shows.
	var stripe := Mats.world(color.lightened(0.35), 0.5, 0.2)
	for k in 2:
		var s := PuzzleNode.box_mesh(Vector3(radius * 1.9, 0.04, 0.3), stripe, Vector3(0, thickness + 0.01, 0))
		s.rotation.y = k * PI * 0.5
		_body.add_child(s)
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.emission_enabled = true
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.06
	tm.outer_radius = radius + 0.06
	rim.mesh = tm
	rim.position.y = thickness
	rim.material_override = _rim_mat
	_body.add_child(rim)
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	_tint()


func _tint() -> void:
	if _rim_mat == null:
		return
	var c := Color(0.4, 1.0, 0.6) if active else Color(0.6, 0.62, 0.7)
	_rim_mat.albedo_color = c
	_rim_mat.emission = c
	_rim_mat.emission_energy_multiplier = 2.0 if active else 0.2


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func _state_changed(_play_fx: bool) -> void:
	_tint()


func is_machine() -> bool:
	return true


func machine_state() -> PackedFloat32Array:
	return PackedFloat32Array([angle])


func apply_machine_state(s: PackedFloat32Array) -> void:
	if s.size() > 0:
		_target = s[0]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	if active:
		angle += deg_to_rad(speed) * delta
	if world and not world.is_server:
		angle += wrapf(_target - angle, -PI, PI) * minf(1.0, 6.0 * delta) # drift toward the server's
	angle = wrapf(angle, -PI, PI)
	_body.rotation.y = angle
