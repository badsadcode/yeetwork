class_name RopeLine
extends MeshInstance3D
## A rope drawn between two points: a flat ribbon turned toward the camera, sagging with its
## slack (the rope's length minus the distance it spans). Visual only, on every peer:
## grapple lines, hanging ropes, pulleys.

const SEGMENTS := 14

var width := 0.06
var color := Color(0.55, 0.42, 0.28)
var _im := ImmediateMesh.new()
var _mat: StandardMaterial3D


func _init() -> void:
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.roughness = 0.9
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true # drawn in world space
	extra_cull_margin = 16384.0 # (its points move every frame)


func set_color(c: Color, glow := 0.0) -> void:
	color = c
	_mat.albedo_color = c
	_mat.emission_enabled = glow > 0.0
	_mat.emission = c
	_mat.emission_energy_multiplier = glow


## Draws the rope from a to b with `slack` metres of rope to spare (it hangs lower).
func draw(a: Vector3, b: Vector3, slack := 0.0) -> void:
	_im.clear_surfaces()
	visible = true
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam else a + Vector3.UP * 10.0
	var sag := sqrt(maxf(slack, 0.0) * a.distance_to(b)) * 0.5
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var dir := (b - a).normalized() if i == 0 else (p - _point(a, b, sag, (i - 1.0) / SEGMENTS)).normalized()
		var side := dir.cross(eye - p).normalized() * width * 0.5
		if not side.is_finite() or side.length_squared() < 1e-8:
			side = Vector3.RIGHT * width * 0.5
		_im.surface_add_vertex(p - side)
		_im.surface_add_vertex(p + side)
	_im.surface_end()


func _point(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


func hide_rope() -> void:
	_im.clear_surfaces()
	visible = false
