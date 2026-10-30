@tool
class_name Magnet
extends PuzzleNode
## An electromagnet facing its local -Y (hang it from a ceiling; rotate it to face a wall).
## While its inputs are on (always, with no inputs) it pulls metal props within Reach toward
## its face and holds them there: barrels, anvils, batteries, fuses, fans. Switch it off and
## they drop. A Yeet with the gun can still pull a light thing off it. Strength: pull at the
## face (m/s², gravity is 24); heavy things feel less of it (an anvil about a third).

@export_range(1.0, 20.0, 0.5) var reach := 7.0:
	set(v):
		reach = v
		_rebuild()
@export_range(10.0, 200.0, 1.0) var strength := 70.0
@export_range(0.3, 3.0, 0.05) var radius := 0.8:
	set(v):
		radius = v
		_rebuild()

var _parts: Node3D
var _face_mat: StandardMaterial3D
var _field: CPUParticles3D
var _hum: AudioStreamPlayer3D


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
	cyl.radius = radius
	cyl.height = 0.5
	cs.shape = cyl
	body.add_child(cs)
	_parts.add_child(body)
	var housing := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.4
	housing.mesh = cm
	housing.position.y = 0.05
	housing.material_override = Mats.plastic(Color(0.85, 0.2, 0.18), 0.35)
	_parts.add_child(housing)
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_color = Color(0.6, 0.62, 0.68)
	_face_mat.metallic = 0.7
	_face_mat.roughness = 0.3
	_face_mat.emission_enabled = true
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = radius * 0.92
	fm.bottom_radius = radius * 0.92
	fm.height = 0.1
	face.mesh = fm
	face.position.y = -0.22
	face.material_override = _face_mat
	_parts.add_child(face)
	if Engine.is_editor_hint():
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.4, 0.7, 1.0, 0.1)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var cone := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = radius
		cn.bottom_radius = radius + reach * 0.35
		cn.height = reach
		cone.mesh = cn
		cone.position.y = -reach * 0.5
		cone.material_override = gm
		_parts.add_child(cone)
	else:
		_field = CPUParticles3D.new()
		_field.amount = 30
		_field.lifetime = 0.8
		_field.emitting = false
		_field.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_field.emission_ring_axis = Vector3.UP
		_field.emission_ring_radius = radius + 1.5
		_field.emission_ring_inner_radius = radius
		_field.emission_ring_height = 0.0
		_field.position.y = -2.0
		_field.direction = Vector3.UP
		_field.spread = 5.0
		_field.initial_velocity_min = 1.5
		_field.initial_velocity_max = 2.5
		_field.gravity = Vector3.ZERO
		_field.radial_accel_min = -2.0
		_field.radial_accel_max = -1.0
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		sm.material = Mats.glow(Color(0.45, 0.75, 1.0), 3.0)
		_field.mesh = sm
		_parts.add_child(_field)
	_tint()


func _tint() -> void:
	if _face_mat == null:
		return
	_face_mat.emission = Color(0.35, 0.65, 1.0) if active else Color.BLACK
	_face_mat.emission_energy_multiplier = 1.6 if active else 0.0
	if _field:
		_field.emitting = active


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx:
		Sfx.play3d("zap" if active else "creak", global_position, -2.0, 0.6 if active else 1.4)


func face_point() -> Vector3:
	return global_transform * Vector3(0, -0.3, 0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not active or not world.is_server:
		return
	var f := face_point()
	var down := -global_transform.basis.y.normalized()
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0 or p.freeze or p.impact_material() != "metal" or p.has_meta("delivered"):
			continue
		var to := f - p.global_position
		var d := to.length()
		var along := -to.dot(down) # how far out along the magnet's axis
		if d > reach or along < -0.5:
			continue
		var heavy := clampf(100.0 / p.mass, 0.3, 1.0)
		var reach_k := 1.0 - clampf(d / reach, 0.0, 1.0)
		var stick := d < maxf(p.size.length() * 0.5, 0.5) + 0.25
		if stick:
			# Held at the face: gravity cancelled, drift damped.
			p.linear_velocity = p.linear_velocity.lerp(to * 4.0, 0.4)
			p.linear_velocity -= Vector3.DOWN * Player.GRAVITY * delta
			p.angular_velocity *= 0.8
		else:
			p.linear_velocity += to / d * strength * heavy * (0.25 + 0.75 * reach_k * reach_k) * delta
			p.linear_velocity -= Vector3.DOWN * Player.GRAVITY * heavy * minf(1.0, 0.5 + reach_k) * delta # it lifts
		p.sleeping = false
