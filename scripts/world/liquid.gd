class_name Liquid
extends Node3D
## A body of liquid: animated surface (liquid.gdshader), a trigger volume that makes it
## behave (water floats and slows things, acid and lava bounce and burn), splashes, spray
## and fizz. The node sits at the centre of the surface; the volume extends size.y below.
## Oceans are huge, flat far away and drown players who fall in.

const PRESETS := {
	"water": {
		"shallow_color": Color(0.12, 0.62, 0.62), "deep_color": Color(0.02, 0.13, 0.24),
		"scatter_color": Color(0.1, 0.75, 0.55), "foam_color": Color(0.95, 0.98, 1.0),
		"glow_color": Color(0, 0, 0), "glow_energy": 0.0, "clarity": 6.0, "depth_fade": 5.0,
		"refraction": 0.045, "roughness_value": 0.035, "foam_amount": 1.0, "bubbles": 0.0,
		"caustics": 1.0, "wave_height": 0.35, "wave_length": 0.45, "wave_speed": 1.0,
		"fog": Color(0.03, 0.27, 0.33), "visibility": 14.0, "shafts": 1.0,
	},
	"acid": {
		"shallow_color": Color(0.45, 1.0, 0.2), "deep_color": Color(0.08, 0.35, 0.05),
		"scatter_color": Color(0.7, 1.0, 0.3), "foam_color": Color(0.85, 1.0, 0.6),
		"glow_color": Color(0.35, 1.0, 0.15), "glow_energy": 0.9, "clarity": 1.6, "depth_fade": 1.5,
		"refraction": 0.06, "roughness_value": 0.05, "foam_amount": 0.6, "bubbles": 1.0,
		"caustics": 0.6, "wave_height": 0.12, "wave_length": 0.22, "wave_speed": 0.8,
		"fog": Color(0.22, 0.6, 0.08), "visibility": 2.5, "shafts": 0.3,
	},
	"lava": {
		"shallow_color": Color(1.0, 0.45, 0.1), "deep_color": Color(0.5, 0.06, 0.0),
		"scatter_color": Color(1.0, 0.7, 0.2), "foam_color": Color(0.12, 0.05, 0.04),
		"glow_color": Color(1.0, 0.35, 0.05), "glow_energy": 3.0, "clarity": 0.12, "depth_fade": 0.4,
		"refraction": 0.0, "roughness_value": 0.55, "foam_amount": 1.6, "bubbles": 0.6,
		"caustics": 0.0, "wave_height": 0.1, "wave_length": 0.35, "wave_speed": 0.25,
		"fog": Color(1.0, 0.3, 0.02), "visibility": 0.6, "shafts": 0.0,
	},
}

static var all: Array[Liquid] = []
static var _normal_a: Texture2D
static var _normal_b: Texture2D
static var _foam_noise: Texture2D

var kind := "water"
## Surface size (x, z) and how deep the volume reaches below the surface (y).
var size := Vector3(20, 4, 20)
var ocean := false
var damage := 22.0
var params: Dictionary
var material: ShaderMaterial
var volume: TriggerVolume
var _spray_timer := 0.0
var _world: Node


static func create(p_kind: String, center: Vector3, p_size: Vector3, p_damage := 22.0) -> Liquid:
	var l := Liquid.new()
	l.kind = p_kind if PRESETS.has(p_kind) else "water"
	l.size = p_size
	l.damage = p_damage
	l.position = center
	return l


static func create_ocean(level: float) -> Liquid:
	var l := Liquid.new()
	l.kind = "water"
	l.ocean = true
	l.size = Vector3(1600, 40, 1600)
	l.position = Vector3(0, level, 0)
	return l


func _ready() -> void:
	params = PRESETS[kind].duplicate()
	if ocean:
		params.wave_height = 1.0
		params.wave_length = 1.0
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/world/liquid.gdshader")
	_textures()
	for key in params:
		if key in ["fog", "visibility", "shafts"]:
			continue
		material.set_shader_parameter(key, params[key])
	material.set_shader_parameter("normal_a", _normal_a)
	material.set_shader_parameter("normal_b", _normal_b)
	material.set_shader_parameter("foam_noise", _foam_noise)
	for key in wave_uniforms():
		material.set_shader_parameter(key, wave_uniforms()[key])
	if ocean:
		material.set_shader_parameter("detail_scale", 0.6)
		_build_ocean_meshes()
	else:
		var spacing := 0.5 if Game.graphics != 0 else 0.9
		_add_plane(Vector2(size.x, size.z), Vector3.ZERO, int(size.x / spacing), int(size.z / spacing))
	volume = TriggerVolume.new()
	add_child(volume)
	volume.position = Vector3(0, -size.y * 0.5 + 0.25, 0)
	var vkind := TriggerVolume.Kind.WATER if kind == "water" else TriggerVolume.Kind.ACID
	volume.setup(vkind, Vector3(size.x, size.y + 0.5, size.z), Vector3.ZERO, damage)
	volume.liquid = self
	if params.glow_energy > 0.0:
		var l := OmniLight3D.new()
		l.light_color = params.glow_color
		l.omni_range = maxf(size.x, size.z) * 0.9
		l.light_energy = 2.5 if kind == "acid" else 3.5
		l.position = Vector3(0, 2.0, 0)
		add_child(l)
	if params.bubbles > 0.0 and not ocean:
		_add_fizz()
	all.append(self)
	_world = get_node_or_null("/root/Main/World")


func _exit_tree() -> void:
	all.erase(self)


func _process(delta: float) -> void:
	material.set_shader_parameter("wave_time", wave_time())
	if ocean:
		_spray(delta)


## Uniforms of liquid_waves.gdshaderinc for this liquid (also fed to the underwater pass).
func wave_uniforms() -> Dictionary:
	return {
		"surface_y": global_position.y, "wave_height": params.wave_height,
		"wave_length": params.wave_length, "wave_speed": params.wave_speed,
		"fade_center": Vector2.ZERO, "fade_inner": 70.0 if ocean else 1000000.0,
		"fade_outer": 105.0 if ocean else 2000000.0,
	}


## Shared wave clock: wall-clock based so every machine sees the same waves.
static func wave_time() -> float:
	return fmod(Time.get_unix_time_from_system(), 3600.0)


# --- CPU copy of liquid_waves.gdshaderinc ------------------------------------------

const WAVES := [Vector3(0.3, 14.0, 0.25), Vector3(1.4, 8.5, 0.22), Vector3(-0.8, 5.2, 0.2), Vector3(2.4, 3.1, 0.15)]


func _fade(p: Vector2) -> float:
	if not ocean:
		return 1.0
	return 1.0 - smoothstep(70.0, 105.0, p.length())


## Returns Vector4(offset x, offset y, offset z, crest 0..1) for the rest point p.
func _gerstner(p: Vector2, t: float) -> Vector4:
	var amp_scale: float = params.wave_height * _fade(p)
	var wl: float = params.wave_length
	var ws: float = params.wave_speed
	var off := Vector3.ZERO
	var total := 0.0
	for w: Vector3 in WAVES:
		var d := Vector2(cos(w.x), sin(w.x))
		var k := TAU / (w.y * wl)
		var c := sqrt(9.8 / k) * ws
		var f := k * (d.dot(p) - c * t)
		var a := w.z * amp_scale / k
		off += Vector3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f))
		total += a
	var crest := clampf(off.y / total * 0.5 + 0.5, 0.0, 1.0) if total > 0.0001 else 0.0
	return Vector4(off.x, off.y, off.z, crest)


## World height of the surface at (x, z).
func height_at(x: float, z: float) -> float:
	var t := wave_time()
	var p := Vector2(x, z)
	var o := _gerstner(p, t)
	o = _gerstner(p - Vector2(o.x, o.z), t)
	return global_position.y + o.y


func contains_xz(p: Vector3) -> bool:
	var l := p - global_position
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5


## The liquid whose surface is above or just below this point, if any.
static func at(p: Vector3, margin := 1.5) -> Liquid:
	for l: Liquid in all:
		if is_instance_valid(l) and l.contains_xz(p) and p.y > l.global_position.y - l.size.y - 0.5 and p.y < l.global_position.y + margin:
			return l
	return null


# --- Building ---------------------------------------------------------------------------

func _add_plane(plane_size: Vector2, offset: Vector3, sub_x: int, sub_z: int) -> void:
	var pm := PlaneMesh.new()
	pm.size = plane_size
	pm.subdivide_width = clampi(sub_x, 1, 400)
	pm.subdivide_depth = clampi(sub_z, 1, 400)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = offset
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)


func _build_ocean_meshes() -> void:
	# Dense, waving middle; flat far planes around it (waves have faded out by then).
	var inner := 220.0
	var sub := 160 if Game.graphics == 0 else 300
	_add_plane(Vector2(inner, inner), Vector3.ZERO, sub, sub)
	var far := size.x
	var band := (far - inner) * 0.5
	_add_plane(Vector2(far, band), Vector3(0, 0, -(inner + band) * 0.5), 1, 1)
	_add_plane(Vector2(far, band), Vector3(0, 0, (inner + band) * 0.5), 1, 1)
	_add_plane(Vector2(band, inner), Vector3(-(inner + band) * 0.5, 0, 0), 1, 1)
	_add_plane(Vector2(band, inner), Vector3((inner + band) * 0.5, 0, 0), 1, 1)


static func _textures() -> void:
	if _normal_a:
		return
	_normal_a = _noise_tex(11, 0.012, true)
	_normal_b = _noise_tex(23, 0.02, true)
	var n := FastNoiseLite.new()
	n.seed = 5
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.03
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 2
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	_foam_noise = t


static func _noise_tex(seed: int, freq: float, normal: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = normal
	t.bump_strength = 6.0
	t.noise = n
	return t


## Rising, popping bubbles for acid and lava.
func _add_fizz() -> void:
	var p := CPUParticles3D.new()
	p.amount = clampi(int(size.x * size.z * 0.15), 8, 90)
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.48, 0.05, size.z * 0.48)
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 8
	sm.rings = 4
	p.mesh = sm
	var col: Color = params.glow_color.lightened(0.3)
	p.material_override = Mats.glow(col, 2.0, true)
	p.position = Vector3(0, 0.05, 0)
	add_child(p)


## Ocean spray: the wind tears mist off the tallest crests near the camera.
func _spray(delta: float) -> void:
	_spray_timer -= delta
	if _spray_timer > 0.0:
		return
	_spray_timer = 0.12 if Game.graphics != 0 else 0.3
	var cam := get_viewport().get_camera_3d()
	if cam == null or _world == null or _world.get("fx") == null:
		return
	var t := wave_time()
	for i in 4:
		var ang := randf() * TAU
		var r := randf_range(6.0, 55.0)
		var p := Vector2(cam.global_position.x, cam.global_position.z) + Vector2(cos(ang), sin(ang)) * r
		if _fade(p) < 0.5:
			continue
		var o := _gerstner(p, t)
		if o.w > 0.86:
			var pos := Vector3(p.x + o.x, global_position.y + o.y, p.y + o.z)
			var wind := Vector3(cos(WAVES[0].x), 0, sin(WAVES[0].x))
			_world.fx.spray(pos, wind, 1.0)
			return


## Splash when something hits the surface (called by the volume on every peer).
func splash(pos: Vector3, speed: float) -> void:
	if _world == null or _world.get("fx") == null:
		return
	var at_surface := Vector3(pos.x, height_at(pos.x, pos.z), pos.z)
	var strength := clampf(speed / 14.0, 0.25, 2.0)
	_world.fx.splash(at_surface, strength, params.shallow_color, kind)
	Sfx.play3d("splash" if kind == "water" else "sizzle", at_surface, -4.0 + strength * 4.0, randf_range(0.85, 1.1) / sqrt(strength))
