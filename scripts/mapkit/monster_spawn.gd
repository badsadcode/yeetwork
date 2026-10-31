@tool
class_name MonsterSpawn
extends Node3D
## MegaYeet: where monsters come from (a rift in the ground, Radius across). Put several round
## the fortress, outside its walls; each wave's monsters share them out. From Wave: this one
## opens from that wave on (a surprise rift later in the game).

@export var radius := 3.0:
	set(v):
		radius = v
		_rebuild()
@export_range(1, 50) var from_wave := 1

var _parts: Node3D


func _ready() -> void:
	_rebuild()


## A spot in the rift for a new monster.
func spot(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * radius * 0.8
	return global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	# A dark pool with a violet glowing rim, and a wisp of mist over it.
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 32
	pool.mesh = cm
	pool.position.y = 0.03
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.02, 0.08)
	dark.emission_enabled = true
	dark.emission = Color(0.35, 0.1, 0.6)
	dark.emission_energy_multiplier = 0.6
	pool.material_override = dark
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts.add_child(pool)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.12
	tm.outer_radius = radius + 0.12
	tm.rings = 32
	rim.mesh = tm
	rim.position.y = 0.05
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.7, 0.3, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.7, 0.3, 1.0)
	glow.emission_energy_multiplier = 2.5
	rim.material_override = glow
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts.add_child(rim)
	if Engine.is_editor_hint():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.3, 1.0)
	light.omni_range = radius * 3.0
	light.light_energy = 1.2
	light.position.y = 1.0
	_parts.add_child(light)
	var mist := CPUParticles3D.new()
	mist.amount = 12
	mist.lifetime = 2.5
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = radius * 0.7
	mist.direction = Vector3.UP
	mist.spread = 15.0
	mist.initial_velocity_min = 0.3
	mist.initial_velocity_max = 0.8
	mist.gravity = Vector3.ZERO
	mist.scale_amount_min = 0.5
	mist.scale_amount_max = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	mist.mesh = qm
	var mm := StandardMaterial3D.new()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.vertex_color_use_as_albedo = true
	mist.material_override = mm
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.2, 0.8, 0.0))
	g.add_point(0.3, Color(0.5, 0.2, 0.8, 0.35))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.1, 0.5, 0.0))
	mist.color_ramp = g
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts.add_child(mist)
