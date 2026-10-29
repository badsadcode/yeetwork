class_name Liquid
extends Node3D
## A body of liquid: animated surface (liquid.gdshader), a trigger volume that makes it
## behave (water floats and slows things, acid and lava bounce and burn), splashes, spray
## and fizz. The node sits at the centre of the surface; the volume extends size.y below.
## Oceans are huge, flat far away and drown players who fall in.

const PRESETS := {
	"water": {
		"shallow_color": Color(0.16, 0.72, 0.72), "deep_color": Color(0.02, 0.24, 0.34),
		"scatter_color": Color(0.15, 0.85, 0.6), "foam_color": Color(0.95, 0.98, 1.0),
		"glow_color": Color(0, 0, 0), "glow_energy": 0.0, "clarity": 7.0, "depth_fade": 4.0,
		"refraction": 0.04, "roughness_value": 0.03, "foam_amount": 0.8, "bubbles": 0.0,
		"caustics": 1.0, "wave_height": 0.18, "wave_length": 0.35, "wave_speed": 0.9,
		"scatter_strength": 0.6, "glint": 1.0, "crust": 0.0,
		"fog": Color(0.08, 0.5, 0.55), "visibility": 16.0, "shafts": 1.0,
	},
	"acid": {
		"shallow_color": Color(0.45, 0.95, 0.1), "deep_color": Color(0.05, 0.28, 0.02),
		"scatter_color": Color(0.75, 1.0, 0.25), "foam_color": Color(0.85, 1.0, 0.55),
		"glow_color": Color(0.35, 1.0, 0.1), "glow_energy": 0.35, "clarity": 1.4, "depth_fade": 1.2,
		"refraction": 0.05, "roughness_value": 0.06, "foam_amount": 0.7, "bubbles": 1.0,
		"caustics": 0.8, "wave_height": 0.12, "wave_length": 0.25, "wave_speed": 0.7,
		"scatter_strength": 0.8, "glint": 0.8, "crust": 0.0,
		"fog": Color(0.2, 0.55, 0.05), "visibility": 2.5, "shafts": 0.4,
	},
	"lava": {
		"shallow_color": Color(1.0, 0.55, 0.12), "deep_color": Color(0.85, 0.18, 0.02),
		"scatter_color": Color(1.0, 0.75, 0.25), "foam_color": Color(0.09, 0.05, 0.05),
		"glow_color": Color(1.0, 0.38, 0.06), "glow_energy": 2.2, "clarity": 0.08, "depth_fade": 0.3,
		"refraction": 0.0, "roughness_value": 0.5, "foam_amount": 1.0, "bubbles": 0.5,
		"caustics": 0.0, "wave_height": 0.08, "wave_length": 0.4, "wave_speed": 0.2,
		"scatter_strength": 0.3, "glint": 0.15, "crust": 1.0,
		"fog": Color(1.0, 0.3, 0.02), "visibility": 0.6, "shafts": 0.0,
	},
}
## The open sea: deeper teal-blue, clearer, with big rolling swells.
const OCEAN := {
	"shallow_color": Color(0.05, 0.52, 0.56), "deep_color": Color(0.0, 0.17, 0.27),
	"scatter_color": Color(0.12, 0.9, 0.62), "clarity": 9.0, "depth_fade": 7.0,
	"wave_height": 1.0, "wave_length": 1.15, "wave_speed": 1.0, "foam_amount": 1.0,
	"fog": Color(0.05, 0.4, 0.46), "visibility": 18.0, "detail_scale": 0.6,
}
## Keys of a preset that drive the underwater pass, not the surface shader.
const VIEW_KEYS := ["fog", "visibility", "shafts"]

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
var _sun_dir := Vector3.ZERO
## Grid spacing of the surface mesh; waves too short for it are left out.
var _spacing := 0.5


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
	l.size = Vector3(5000, 40, 5000) # to the camera's far plane: no gap before the horizon
	l.position = Vector3(0, level, 0)
	return l


func _ready() -> void:
	params = PRESETS[kind].duplicate()
	if ocean:
		params.merge(OCEAN, true)
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/world/liquid.gdshader")
	_textures()
	for key in params:
		if key not in VIEW_KEYS:
			material.set_shader_parameter(key, params[key])
	material.set_shader_parameter("normal_a", _normal_a)
	material.set_shader_parameter("normal_b", _normal_b)
	material.set_shader_parameter("foam_noise", _foam_noise)
	material.set_shader_parameter("ssr_steps", [8, 12, 16][clampi(Game.graphics, 0, 2)])
	if ocean:
		_spacing = 0.75 if Game.graphics != 0 else 1.4
		_build_ocean_mesh()
	else:
		_spacing = 0.5 if Game.graphics != 0 else 0.9
		_add_plane(Vector2(size.x, size.z), Vector3.ZERO, int(size.x / _spacing), int(size.z / _spacing))
	var u := wave_uniforms()
	for key in u:
		material.set_shader_parameter(key, u[key])
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
		"min_wavelength": _spacing * 2.8, "fade_center": Vector2.ZERO, "fade_inner": FADE_INNER if ocean else 1000000.0,
		"fade_outer": FADE_OUTER if ocean else 2000000.0,
	}


## Shared wave clock: wall-clock based so every machine sees the same waves.
static func wave_time() -> float:
	return fmod(Time.get_unix_time_from_system(), 3600.0)


# --- CPU copy of liquid_waves.gdshaderinc ------------------------------------------

## Ocean waves fade out between these distances from the map centre (flat far away).
const FADE_INNER := 95.0
const FADE_OUTER := 145.0
const WAVES := [
	Vector3(0.3, 23.0, 0.16), Vector3(-0.45, 15.3, 0.15), Vector3(1.05, 10.9, 0.13), Vector3(0.75, 7.7, 0.12),
	Vector3(-1.2, 5.3, 0.1), Vector3(2.1, 3.9, 0.09), Vector3(-0.15, 2.7, 0.08), Vector3(1.6, 1.9, 0.07),
]


func _fade(p: Vector2) -> float:
	if not ocean:
		return 1.0
	return 1.0 - smoothstep(FADE_INNER, FADE_OUTER, p.length())


## Swell groups: see wave_group() in the shader.
static func _group(p: Vector2, i: float, t: float) -> float:
	var a := p.dot(Vector2(0.021, 0.013) * (1.0 + 0.37 * i)) + i * 1.7 - t * 0.11
	var b := p.dot(Vector2(-0.011, 0.024)) - i * 2.3 + t * 0.07
	return 0.6 + 0.4 * sin(a) * sin(b)


## Returns Vector4(offset x, offset y, offset z, crest 0..1) for the rest point p.
func _gerstner(p: Vector2, t: float) -> Vector4:
	var amp_scale: float = params.wave_height * _fade(p)
	var min_wl := _spacing * 2.8
	var off := Vector3.ZERO
	var total := 0.0
	for i in WAVES.size():
		var w: Vector3 = WAVES[i]
		var wl: float = w.y * params.wave_length
		var res := smoothstep(min_wl, min_wl * 1.5, wl)
		if res <= 0.0:
			continue
		var d := Vector2(cos(w.x), sin(w.x))
		var k := TAU / wl
		var c := sqrt(9.8 / k) * float(params.wave_speed)
		var f := k * (d.dot(p) - c * t)
		var a := w.z * amp_scale * res * _group(p, i, t) / k
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


## Direction toward the sun (the brightest shadow-casting DirectionalLight3D), for the
## underwater light shafts. Looked up on first use, once the map's lights exist.
func sun_dir() -> Vector3:
	if _sun_dir == Vector3.ZERO:
		_sun_dir = Vector3(0.35, 0.8, 0.45).normalized()
		var best := 0.0
		for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			var l := n as DirectionalLight3D
			if l.visible and l.shadow_enabled and l.light_energy > best:
				best = l.light_energy
				_sun_dir = l.global_transform.basis.z.normalized()
	return _sun_dir


## Cellular noise shared by the foam and the underwater light shafts.
static func shaft_noise() -> Texture2D:
	_textures()
	return _foam_noise


## The liquid whose surface is above or just below this point, if any. A pool inside an
## ocean wins over the ocean.
static func at(p: Vector3, margin := 1.5) -> Liquid:
	var best: Liquid = null
	for l: Liquid in all:
		if is_instance_valid(l) and l.contains_xz(p) and p.y > l.global_position.y - l.size.y - 0.5 and p.y < l.global_position.y + margin:
			if best == null or l.size.x * l.size.z < best.size.x * best.size.z:
				best = l
	return best


# --- Building ---------------------------------------------------------------------------

func _add_plane(plane_size: Vector2, offset: Vector3, sub_x: int, sub_z: int) -> void:
	var pm := PlaneMesh.new()
	pm.size = plane_size
	pm.subdivide_width = clampi(sub_x, 1, 400)
	pm.subdivide_depth = clampi(sub_z, 1, 400)
	_add_mesh(pm, offset)


func _add_mesh(mesh: Mesh, offset: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED # moving and see-through: keep it out of SDFGI
	mi.extra_cull_margin = 4.0
	add_child(mi)


## One grid for the whole sea: even and fine where the waves are, then each ring of cells
## wider than the last out to the horizon. A single mesh has no cracks or seams between a
## detailed middle and flat far parts.
func _build_ocean_mesh() -> void:
	var step := _spacing
	var inner := 150.0 # waves have faded out by fade_outer
	var half := PackedFloat32Array([0.0])
	var c := 0.0
	var s := step
	while c < size.x * 0.5:
		if c >= inner:
			s *= 1.18
		c = minf(c + s, size.x * 0.5)
		half.append(c)
	var axis := PackedFloat32Array()
	for i in range(half.size() - 1, 0, -1):
		axis.append(-half[i])
	axis.append_array(half)
	var n := axis.size()
	var verts := PackedVector3Array()
	verts.resize(n * n)
	var normals := PackedVector3Array()
	normals.resize(n * n)
	normals.fill(Vector3.UP)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(axis[i], 0.0, axis[j])
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[k] = a
			idx[k + 1] = a + 1
			idx[k + 2] = a + n
			idx[k + 3] = a + 1
			idx[k + 4] = a + n + 1
			idx[k + 5] = a + n
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_add_mesh(mesh, Vector3.ZERO)


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
