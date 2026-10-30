@tool
class_name FloodDrain
extends PuzzleNode
## A grate in the floor that takes water out of the FloodZone it's in, while its inputs are
## on (always, with no inputs): open the drain to empty the room. Rate: m³ a second.
## (Water also pours out wherever the floor falls away below the zone: a pit.)

@export_range(0.1, 40.0, 0.1) var rate := 3.0
@export_range(0.3, 3.0, 0.1) var radius := 0.8:
	set(v):
		radius = v
		_rebuild()

var _zone: FloodZone
var _parts: Node3D
var _swirl: CPUParticles3D
var _grate_mat: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_grate_mat = StandardMaterial3D.new()
	_grate_mat.albedo_color = Color(0.25, 0.28, 0.32)
	_grate_mat.metallic = 0.6
	_grate_mat.roughness = 0.4
	_grate_mat.emission_enabled = true
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	ring.mesh = cm
	ring.material_override = _grate_mat
	ring.position.y = 0.02
	_parts.add_child(ring)
	# Bars across the grate.
	var dark := Mats.plastic(Color(0.08, 0.09, 0.1), 0.8)
	for k in 5:
		var bar := PuzzleNode.box_mesh(Vector3(radius * 1.7, 0.03, 0.06), dark, Vector3(0, 0.045, (k - 2) * radius * 0.32))
		_parts.add_child(bar)
	_tint()
	if Engine.is_editor_hint():
		return
	_swirl = CPUParticles3D.new()
	_swirl.amount = 24
	_swirl.lifetime = 1.0
	_swirl.emitting = false
	_swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_swirl.emission_ring_axis = Vector3.UP
	_swirl.emission_ring_radius = radius
	_swirl.emission_ring_inner_radius = radius * 0.6
	_swirl.emission_ring_height = 0.0
	_swirl.gravity = Vector3.ZERO
	_swirl.orbit_velocity_min = 0.6
	_swirl.orbit_velocity_max = 0.9
	_swirl.radial_accel_min = -3.0
	_swirl.radial_accel_max = -2.0
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.98, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	_swirl.mesh = sm
	_parts.add_child(_swirl)


func _tint() -> void:
	if _grate_mat == null:
		return
	_grate_mat.emission = Color(0.2, 0.6, 1.0) if active else Color(0.0, 0.0, 0.0)
	_grate_mat.emission_energy_multiplier = 0.8 if active else 0.0


func link() -> void:
	_zone = FloodZone.at(world, global_position)


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func _state_changed(_play_fx: bool) -> void:
	_tint()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not active or _zone == null:
		return
	if world.is_server:
		_zone.pour(global_position, radius, -rate * delta)


func _process(_delta: float) -> void:
	if _swirl == null or _zone == null:
		return
	var s := _zone.surface_at(global_position)
	var wet := active and s > global_position.y + 0.05
	_swirl.emitting = wet
	if wet:
		_swirl.global_position.y = s + 0.03


func problems() -> Array[String]:
	var out := super.problems()
	if FloodZone.at(world, global_position) == null and world != null:
		out.append("%s: the drain isn't inside a FloodZone." % name)
	return out
