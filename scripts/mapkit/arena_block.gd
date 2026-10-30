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

## arena: the usual soft panels. ice: clear, frosty blue ice that can't be broken, and is
## slippery (Yeets skate on it, props glide). For breakable ice use a BreakableSlab of ice.
@export_enum("arena", "ice") var surface := "arena":
	set(v):
		surface = v
		_rebuild()
## Ice only, optional: a clarity map (greyscale: white clear, black cloudy) and a normal map
## (the surface's bumps), wrapped onto every face; Ice Map Scale = repeats per metre.
## Without them the ice makes its own frost and bumps.
@export var ice_clarity_map: Texture2D:
	set(v):
		ice_clarity_map = v
		_rebuild()
@export var ice_normal_map: Texture2D:
	set(v):
		ice_normal_map = v
		_rebuild()
@export_range(0.05, 4.0, 0.05) var ice_map_scale := 0.5:
	set(v):
		ice_map_scale = v
		_rebuild()
## Your own material instead of the colour above: PBR textures (albedo, normal, roughness,
## metallic, AO...). A StandardMaterial3D / ORMMaterial3D is wrapped onto every face in
## world space, so it tiles evenly whatever the block's size: Texture Size = the metres one
## repeat covers. Other materials (your own shaders) are used as they are.
@export var custom_material: Material:
	set(v):
		custom_material = v
		_rebuild()
@export_range(0.1, 20.0, 0.1) var texture_size := 2.0:
	set(v):
		texture_size = v
		_rebuild()
## Ricochet surfaces: how much bounce things keep off it (0 = like any wall; 0.8 = a lot).
## A bouncy block is also frictionless, so things leave it at the angle they came in.
@export_range(0.0, 1.0, 0.05) var bounciness := 0.0

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if bounciness > 0.0 or surface == "ice":
		var pm := PhysicsMaterial.new()
		pm.bounce = bounciness
		pm.friction = 0.0 if bounciness > 0.0 else 0.03
		physics_material_override = pm
	if surface == "ice":
		set_meta("ice", true)
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
	var maps := {}
	if ice_clarity_map or ice_normal_map:
		maps = {"clarity": ice_clarity_map, "normal": ice_normal_map, "scale": ice_map_scale}
	_mesh.material_override = Mats.ice(size * 0.5, false, false, maps) if surface == "ice" else Mats.world(color, roughness, metallic, emission)
	if custom_material and surface != "ice":
		var m := custom_material
		if m is BaseMaterial3D:
			m = m.duplicate()
			(m as BaseMaterial3D).uv1_triplanar = true
			(m as BaseMaterial3D).uv1_world_triplanar = true
			(m as BaseMaterial3D).uv1_scale = Vector3.ONE / maxf(texture_size, 0.05)
		_mesh.material_override = m
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
