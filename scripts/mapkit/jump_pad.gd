@tool
class_name JumpPadNode
extends Node3D
## Launches players and props. Aim it by moving `target` (relative to the pad); the
## launch velocity is computed so the arc peaks `arc_height` above the higher end.
## The editor draws the predicted arc.

@export var target := Vector3(0, 6, -8):
	set(v):
		target = v
		_rebuild()
@export_range(0.5, 30.0, 0.1) var arc_height := 2.5:
	set(v):
		arc_height = v
		_rebuild()
## If set, launch with exactly this velocity (relative to the pad) instead of aiming at
## `target` (the converted built-in maps use it to keep their original pads).
@export var velocity_override := Vector3.ZERO:
	set(v):
		velocity_override = v
		_rebuild()

## Your own model for it (a scene: a mesh, an imported .glb...), instead of the built-in look.
## It works the same; only the look changes.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var _preview: MeshInstance3D
var _model: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func gravity() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)


## World-space launch velocity.
func launch_velocity() -> Vector3:
	if velocity_override != Vector3.ZERO:
		return global_transform.basis * velocity_override
	var g := gravity()
	var t := global_transform.basis * target
	var apex := maxf(t.y, 0.0) + arc_height
	var vy := sqrt(2.0 * g * apex)
	var t_up := vy / g
	var t_down := sqrt(2.0 * (apex - t.y) / g)
	var h := Vector3(t.x, 0, t.z) / (t_up + t_down)
	return Vector3(h.x, vy, h.z)


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _model:
		_model.queue_free()
		_model = null
	if model:
		_model = model.instantiate() as Node3D
		if _model:
			add_child(_model, false, Node.INTERNAL_MODE_FRONT)
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.top_level = true
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var v := launch_velocity()
	var p := global_position + Vector3(0, 0.6, 0)
	var g := gravity()
	for i in 80:
		im.surface_add_vertex(p)
		v.y -= g * 0.03
		p += v * 0.03
		if p.y < global_position.y - 20.0:
			break
	im.surface_end()
	_preview.mesh = im
	_preview.global_transform = Transform3D.IDENTITY
	_preview.material_override = Mats.glow(Color(0.35, 1.0, 0.55), 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_rebuild()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
