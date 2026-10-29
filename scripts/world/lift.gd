class_name Lift
extends AnimatableBody3D
## A platform that moves between two points on a clock shared by every peer.

var point_a := Vector3.ZERO
var point_b := Vector3.ZERO
var period := 8.0
var phase := 0.0
var world: Node


func setup(p_world: Node, a: Vector3, b: Vector3, size: Vector3, p_period: float, p_phase: float, color: Color) -> void:
	world = p_world
	point_a = a
	point_b = b
	period = p_period
	phase = p_phase
	position = a
	sync_to_physics = true
	collision_layer = Game.L_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.world(color, 0.4, 0.3)
	add_child(mi)
	var trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(size.x + 0.1, 0.08, size.z + 0.1)
	trim.mesh = tm
	trim.position.y = size.y * 0.5
	trim.material_override = Mats.glow(Color(0.4, 1.0, 0.6), 2.0)
	add_child(trim)


func _physics_process(_delta: float) -> void:
	var t: float = world.net_time() if world else 0.0
	# Ease in/out with a pause at each end.
	var u := fposmod(t / period + phase, 1.0)
	var k := clampf(absf(u * 2.0 - 1.0) * 1.4 - 0.2, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	global_position = point_a.lerp(point_b, 1.0 - k)
