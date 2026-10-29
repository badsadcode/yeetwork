class_name EnergyTrail
extends MeshInstance3D
## A short glowing ribbon behind something the gravity gun just threw: it follows the
## object for a moment (a few metres of flight), sheds sparks, then fades out.
## Visual only, on every peer (arc.gdshader, additive).

const KEEP := 0.16 # seconds of path the ribbon shows

var target: Node3D
var color := Color(0.3, 0.6, 1.0)
var strength := 1.0
var _points: Array = [] # [position, time]
var _age := 0.0
var _life := 0.45
var _mesh := ImmediateMesh.new()
var _mat: ShaderMaterial
var _sparks: CPUParticles3D


static func follow(parent: Node, p_target: Node3D, p_color: Color, p_strength: float) -> EnergyTrail:
	var t := EnergyTrail.new()
	t.target = p_target
	t.color = p_color
	t.strength = p_strength
	t._life = 0.35 + 0.25 * clampf(p_strength - 1.0, 0.0, 1.0)
	parent.add_child(t)
	return t


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/fx/arc.gdshader")
	material_override = _mat
	_sparks = CPUParticles3D.new()
	_sparks.amount = 16
	_sparks.lifetime = 0.35
	_sparks.local_coords = false
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 1.0
	_sparks.initial_velocity_max = 3.5
	_sparks.gravity = Vector3(0, -6, 0)
	_sparks.particle_flag_align_y = true
	var sm := BoxMesh.new()
	sm.size = Vector3(0.012, 0.12, 0.012)
	_sparks.mesh = sm
	_sparks.material_override = Mats.glow(color.lightened(0.5), 6.0)
	add_child(_sparks)


func _process(delta: float) -> void:
	_age += delta
	var now := _age
	if is_instance_valid(target) and _age < _life:
		_points.append([target.global_position, now])
		_sparks.global_position = target.global_position
		_sparks.emitting = true
	else:
		_sparks.emitting = false
	while not _points.is_empty() and now - float(_points[0][1]) > KEEP:
		_points.pop_front()
	var fade := 1.0 - clampf((_age - _life) / 0.3, 0.0, 1.0)
	if fade <= 0.0 and _points.size() < 2:
		queue_free()
		return
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _points.size()
	for i in n - 1:
		var a: Vector3 = _points[i][0]
		var b: Vector3 = _points[i + 1][0]
		var t := float(i + 1) / n # 0 at the tail, 1 at the object
		var w := (0.06 + 0.3 * t) * clampf(strength, 0.6, 1.6)
		_ribbon(a, b, w, Color(color, t * fade), cam.global_position, 0.0)
		_ribbon(a, b, w * 0.25, Color(color, t * fade), cam.global_position, 1.0)
	# A glowing halo around the object itself: what you see of the trail from behind.
	if is_instance_valid(target) and _age < _life + 0.2:
		_halo(target.global_position, (0.55 + 0.35 * strength) * fade, Color(color, 0.8 * fade), cam)
	_mesh.surface_end()
	_mat.set_shader_parameter("energy", 2.2 + strength)


func _halo(p: Vector3, size: float, col: Color, cam: Camera3D) -> void:
	var right := cam.global_transform.basis.x * size
	var up := cam.global_transform.basis.y * size
	_mesh.surface_set_color(col)
	_mesh.surface_set_uv2(Vector2(1, 0))
	var c := [[p - right - up, Vector2(0, 1)], [p + right - up, Vector2(1, 1)], [p + right + up, Vector2(1, 0)], [p - right + up, Vector2(0, 0)]]
	for i in [0, 1, 2, 0, 2, 3]:
		_mesh.surface_set_uv(c[i][1])
		_mesh.surface_add_vertex(c[i][0])


func _ribbon(a: Vector3, b: Vector3, width: float, col: Color, cam_pos: Vector3, hot: float) -> void:
	var side := (b - a).cross(cam_pos - a).normalized() * width
	_mesh.surface_set_color(col)
	_mesh.surface_set_uv2(Vector2.ZERO)
	for q in [[a - side, 0.0], [a + side, 1.0], [b + side, 1.0], [a - side, 0.0], [b + side, 1.0], [b - side, 0.0]]:
		_mesh.surface_set_uv(Vector2(hot, q[1]))
		_mesh.surface_add_vertex(q[0])
