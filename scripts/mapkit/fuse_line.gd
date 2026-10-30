@tool
class_name FuseLine
extends PuzzleNode
## A fuse cord along the floor, from this node to End (the editor shows it). Light its start
## with fire (a burning prop or Yeet, a lit Beacon, or its inputs switching on) and a spark
## runs along it at Speed; when it reaches the end the fuse is on for good (open a gate,
## light the Beacon there, set off a barrel). Water on the cord puts the spark out: light it
## again where it stopped.

@export var end := Vector3(0, 0, -6):
	set(v):
		end = v
		_rebuild()
@export_range(0.2, 10.0, 0.1) var speed := 1.5

var burned := 0.0 # 0..1 along the cord (synced)
var lit := false # the spark is running (synced)
var _parts: Node3D
var _cord: MeshInstance3D
var _ash: MeshInstance3D
var _spark: CPUParticles3D
var _light: OmniLight3D
var _hiss := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_cord = _segment(Mats.plastic(Color(0.55, 0.42, 0.25), 0.8), 0.045)
	_ash = _segment(Mats.plastic(Color(0.12, 0.11, 0.1), 0.95), 0.05)
	# The two ends: a little post where it starts, a cap where it ends.
	var metal := Mats.plastic(Color(0.6, 0.62, 0.68), 0.35)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.18, 0.12, 0.18), metal, Vector3(0, 0.06, 0)))
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.22, 0.16, 0.22), Mats.plastic(Color(0.85, 0.2, 0.15), 0.4), end + Vector3(0, 0.08, 0)))
	if not Engine.is_editor_hint():
		_spark = CPUParticles3D.new()
		_spark.amount = 30
		_spark.lifetime = 0.35
		_spark.emitting = false
		_spark.direction = Vector3.UP
		_spark.spread = 70.0
		_spark.initial_velocity_min = 1.5
		_spark.initial_velocity_max = 3.5
		_spark.gravity = Vector3(0, -9, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		sm.material = Mats.glow(Color(1.0, 0.75, 0.3), 4.0)
		_spark.mesh = sm
		_parts.add_child(_spark)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.6, 0.25)
		_light.omni_range = 2.5
		_light.light_energy = 0.0
		_parts.add_child(_light)
	_layout()


func _segment(mat: Material, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mat
	_parts.add_child(mi)
	return mi


## Stretches the unburned cord from the spark to the end, the ash from the start to the spark.
func _layout() -> void:
	if _cord == null:
		return
	var a := Vector3(0, 0.05, 0)
	var b := end + Vector3(0, 0.05, 0)
	var s := a.lerp(b, burned)
	_place(_ash, a, s)
	_place(_cord, s, b)
	if _spark:
		_spark.position = s
		_light.position = s + Vector3.UP * 0.2


func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	mi.visible = d.length() > 0.01
	if not mi.visible:
		return
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3(1, d.length(), 1)), (a + b) * 0.5)


func spark_position() -> Vector3:
	return global_transform * Vector3(0, 0.05, 0).lerp(end + Vector3(0, 0.05, 0), burned)


func is_machine() -> bool:
	return true


func machine_state() -> PackedFloat32Array:
	return PackedFloat32Array([burned, 1.0 if lit else 0.0])


func apply_machine_state(s: PackedFloat32Array) -> void:
	if s.size() < 2:
		return
	burned = s[0]
	lit = s[1] > 0.5
	_layout()


func evaluate() -> bool:
	return burned >= 1.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not world.is_server or burned >= 1.0:
		return
	var at := spark_position()
	if lit:
		if world.in_water(at + Vector3.UP * 0.1):
			lit = false # doused
			world.server_fx("steam", at, Vector3.UP, 0.5)
			return
		burned = minf(burned + speed * delta / maxf(end.length(), 0.1), 1.0)
		if burned >= 1.0:
			lit = false
		world.server_fire_spot(spark_position(), 0.35, self)
	elif Engine.get_physics_frames() % 6 == 0:
		# Waiting for fire: at the start, or where the spark went out.
		if (burned == 0.0 and not inputs.is_empty() and inputs_on()) or world.fire_near(at, 0.8, self):
			if not world.in_water(at + Vector3.UP * 0.1):
				lit = true
	_layout()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _spark == null:
		return
	_spark.emitting = lit
	_light.light_energy = (1.4 + randf() * 0.6) if lit else 0.0
	if lit:
		_hiss -= delta
		if _hiss <= 0.0:
			_hiss = 0.55
			Sfx.play3d("sizzle", spark_position(), -6.0, randf_range(1.3, 1.6))
