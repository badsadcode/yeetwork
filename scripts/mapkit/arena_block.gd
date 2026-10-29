@tool
class_name ArenaBlock
extends StaticBody3D
## Solid box using the arena surface shader. Rotate/scale-free: set `size` instead of
## scaling. Rotate it to make ramps (players walk up slopes up to ~46 degrees).

@export var size := Vector3(4, 1, 4):
	set(v):
		size = v.max(Vector3.ONE * 0.05)
		_rebuild()
@export var color := Color(0.42, 0.47, 0.62):
	set(v):
		color = v
		_rebuild()
@export_range(0.0, 1.0, 0.01) var roughness := 0.7:
	set(v):
		roughness = v
		_rebuild()
@export_range(0.0, 1.0, 0.01) var metallic := 0.0:
	set(v):
		metallic = v
		_rebuild()
## Glow strength (0 = none). Great for neon trims and landmarks.
@export_range(0.0, 8.0, 0.1) var emission := 0.0:
	set(v):
		emission = v
		_rebuild()

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mesh.material_override = Mats.world(color, roughness, metallic, emission)
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
