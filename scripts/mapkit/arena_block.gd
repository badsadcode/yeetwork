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
## metallic, AO, height...). It's used as it is, every setting included, on a box whose
## texture coordinates are laid out in metres in the map, so the texture tiles evenly
## whatever the block's size and lines up across neighbouring blocks: Texture Size = the
## metres one repeat covers. The material's own UV1 Scale / Offset apply on top.
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

# Each face: [outward normal, right, up] as seen from outside (right x up = normal).
const FACES := [
	[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
]


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
	if Engine.is_editor_hint():
		set_notify_transform(true) # the texture stays put in the map while you move the block
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _mesh and custom_material and surface != "ice":
		_mesh.mesh = _textured_box()


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
		_mesh.mesh = _textured_box()
		_mesh.material_override = custom_material
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs


## The box for a custom material: texture coordinates (UV and UV2) are the face's position in
## the map in metres / Texture Size, upright on the sides; tangents for normal and height maps.
func _textured_box() -> ArrayMesh:
	var anchor := global_basis.inverse() * global_position
	var k := 1.0 / maxf(texture_size, 0.05)
	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in FACES:
		var n: Vector3 = f[0]
		var r: Vector3 = f[1]
		var u: Vector3 = f[2]
		var c := n * (h * n.abs()).length()
		var hr := r * (h * r.abs()).length()
		var hu := u * (h * u.abs()).length()
		var corners := [c - hr + hu, c + hr + hu, c + hr - hu, c - hr - hu] # clockwise from outside
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = corners[i]
			var w := anchor + p
			var uv := Vector2(w.dot(r), -w.dot(u)) * k
			st.set_normal(n)
			st.set_uv(uv)
			st.set_uv2(uv)
			st.add_vertex(p)
	st.generate_tangents()
	return st.commit()
