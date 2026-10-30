@tool
class_name Contacts
extends PuzzleNode
## Two copper pads Gap apart (along local X): on while they're powered (their inputs are on,
## or always with no inputs) and something conductive bridges them. A metal prop lying
## across both (a barrel, an anvil, a battery), water over both (a flood, a pool), or a Yeet
## standing between them, who gets zapped for it (a jolt and a hop, again and again).
## The classic: close the circuit to open the door.

@export_range(0.6, 6.0, 0.1) var gap := 1.4:
	set(v):
		gap = v
		_rebuild()

const PAD := 0.45 # pad radius

var bridged_by := "" # what closes it now (server): "metal", "water", "yeet"
var _parts: Node3D
var _lamp: StandardMaterial3D
var _spark: CPUParticles3D
var _zap_t := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var copper := Mats.plastic(Color(0.85, 0.5, 0.25), 0.25)
	for sx in [-1, 1]:
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = PAD
		cm.bottom_radius = PAD
		cm.height = 0.06
		pad.mesh = cm
		pad.material_override = copper
		pad.position = Vector3(sx * gap * 0.5, 0.03, 0)
		_parts.add_child(pad)
	_lamp = StandardMaterial3D.new()
	_lamp.emission_enabled = true
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.2, 0.2, 0.2), _lamp, Vector3(0, 0.1, -PAD - 0.2)))
	_parts.add_child(PuzzleNode.box_mesh(Vector3(gap, 0.02, 0.05), Mats.plastic(Color(0.15, 0.15, 0.17), 0.6), Vector3(0, 0.01, -PAD - 0.2)))
	if not Engine.is_editor_hint():
		_spark = CPUParticles3D.new()
		_spark.amount = 24
		_spark.lifetime = 0.25
		_spark.emitting = false
		_spark.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_spark.emission_box_extents = Vector3(gap * 0.5, 0.05, 0.2)
		_spark.direction = Vector3.UP
		_spark.spread = 80.0
		_spark.initial_velocity_min = 1.0
		_spark.initial_velocity_max = 3.0
		_spark.gravity = Vector3(0, -6, 0)
		var sm := SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		sm.material = Mats.glow(Color(0.5, 0.85, 1.0), 4.0)
		_spark.mesh = sm
		_spark.position.y = 0.15
		_parts.add_child(_spark)
	_tint()


func _tint() -> void:
	if _lamp == null:
		return
	var c := Color(0.35, 1.0, 0.45) if active else Color(1.0, 0.7, 0.2)
	_lamp.albedo_color = c
	_lamp.emission = c
	_lamp.emission_energy_multiplier = 2.5 if active else 1.0
	if _spark:
		_spark.emitting = active


func pad(side: int) -> Vector3:
	return global_transform * Vector3((side * 2 - 1) * gap * 0.5, 0.05, 0)


func powered() -> bool:
	return inputs.is_empty() or inputs_on()


func evaluate() -> bool:
	bridged_by = _bridge()
	return powered() and bridged_by != ""


func _bridge() -> String:
	var a := pad(0)
	var b := pad(1)
	if world.in_water(a + Vector3.UP * 0.05) and world.in_water(b + Vector3.UP * 0.05):
		return "water"
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0 or p.impact_material() != "metal":
			continue
		var r := p.size.length() * 0.5 + PAD
		if p.global_position.distance_to(a) < r and p.global_position.distance_to(b) < r and p.global_position.y < a.y + p.size.length():
			return "metal"
	if _yeet_across() != null:
		return "yeet"
	return ""


func _yeet_across() -> Player:
	var inv := global_transform.affine_inverse()
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var l: Vector3 = inv * pl.global_position
		if absf(l.x) < gap * 0.5 + 0.2 and absf(l.z) < PAD + 0.2 and l.y > -0.2 and l.y < 0.6:
			return pl
	return null


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx:
		Sfx.play3d("zap" if active else "hit", global_position, -2.0, 1.2 if active else 0.8)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not world.is_server or not powered():
		return
	_zap_t -= delta
	if _zap_t > 0.0:
		return
	var pl := _yeet_across()
	if pl:
		_zap_t = 0.7
		world.server_zap(pl, 6.0)
		world.server_fx("zap", pl.body_center(), Vector3.UP, 1.0)
