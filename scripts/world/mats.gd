@tool
class_name Mats
extends RefCounted
## Procedural textures and a material cache shared by the arena, props and characters.

static var _cache := {}
static var _grid_tex: ImageTexture
static var _grid_normal: ImageTexture
static var _splat_textures: Array[ImageTexture] = []


## Stylized arena surface: soft panels and warm/cool height gradient (see world_surface.gdshader).
static func world(color: Color, roughness := 0.75, metallic := 0.0, emission := 0.0) -> Material:
	var key := "w%s_%.2f_%.2f_%.2f" % [color.to_html(), roughness, metallic, emission]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/world/world_surface.gdshader")
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("roughness_value", roughness)
	m.set_shader_parameter("metallic_value", metallic)
	m.set_shader_parameter("emission_energy", emission)
	_cache[key] = m
	return m


## Ice (ice.gdshader): `box_half` makes a box's edges glow (zero: no edge glow);
## `damage` draws cracks from vertex colour (breakable ice). Low "simple glass": a plain
## translucent blue.
static func ice(box_half := Vector3.ZERO, inner := false, damage := false) -> Material:
	var q := 2 if Engine.is_editor_hint() else clampi(int(Game.gfx.get("glass", 2)), 0, 2)
	var key := "ice%s_%s_%s_%d" % [box_half, inner, damage, q]
	if _cache.has(key):
		return _cache[key]
	var m: Material
	if q > 0:
		var im := ShaderMaterial.new()
		im.shader = preload("res://scripts/world/ice.gdshader")
		im.set_shader_parameter("box_half", box_half)
		im.set_shader_parameter("inner", inner)
		im.set_shader_parameter("use_vertex_damage", damage)
		m = im
	else:
		var s := StandardMaterial3D.new()
		s.albedo_color = Color(0.7, 0.88, 1.0, 0.55 if not inner else 0.7)
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.roughness = 0.1
		s.rim_enabled = true
		s.rim = 0.5
		s.emission_enabled = true
		s.emission = Color(0.25, 0.4, 0.55)
		m = s
	_cache[key] = m
	return m


## Destructible slab outer faces (cracks from vertex damage) and fracture faces.
static func slab(color: Color, material: String, inner := false) -> Material:
	if material == "ice":
		return Mats.ice(Vector3.ZERO, inner, not inner)
	var glass_q := 0
	if material == "glass":
		glass_q = 2 if Engine.is_editor_hint() else clampi(int(Game.gfx.get("glass", 2)), 0, 2)
	var key := "slab%s_%s_%s_%d" % [color.to_html(), material, inner, glass_q]
	if _cache.has(key):
		return _cache[key]
	var m: Material
	if material == "glass" and glass_q > 0:
		# Refracting glass (glass.gdshader); "reflections" adds screen-space reflections.
		var gm := ShaderMaterial.new()
		gm.shader = preload("res://scripts/world/glass.gdshader")
		gm.set_shader_parameter("inner", inner)
		gm.set_shader_parameter("use_vertex_damage", not inner)
		gm.set_shader_parameter("reflections", glass_q >= 2)
		gm.set_shader_parameter("ssr_steps", 10)
		gm.set_shader_parameter("ssr_distance", 25.0)
		m = gm
	elif material == "glass":
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.75, 0.95, 1.0, 0.28) if not inner else Color(0.85, 1.0, 1.0, 0.06)
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.roughness = 0.05
		g.metallic_specular = 0.9
		g.rim_enabled = true
		g.rim = 0.4
		g.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = g
	else:
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://scripts/world/world_surface.gdshader")
		var c := color
		var rough := 0.7
		var metal := 0.0
		match material:
			"wood":
				rough = 0.8
			"metal":
				rough = 0.35
				metal = 0.6
			"concrete":
				rough = 0.85
		if inner:
			c = color.darkened(0.18).lerp(Color(1.0, 0.75, 0.55), 0.18)
		sm.set_shader_parameter("base_color", c)
		sm.set_shader_parameter("roughness_value", rough)
		sm.set_shader_parameter("metallic_value", metal)
		sm.set_shader_parameter("use_vertex_damage", not inner)
		sm.set_shader_parameter("inner", inner)
		sm.set_shader_parameter("panel_size", 1.0 if material == "brick" else 2.0)
		m = sm
	_cache[key] = m
	return m


## Soft toy/clay-like plastic, used for characters and props.
static func plastic(color: Color, roughness := 0.45, emission := 0.0) -> StandardMaterial3D:
	var key := "p%s_%.2f_%.2f" % [color.to_html(), roughness, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = clampf(roughness + 0.1, 0.0, 1.0)
	m.metallic_specular = 0.5
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


## Skin with a touch of subsurface scattering for that soft, lit-from-within look.
static func skin(color: Color) -> StandardMaterial3D:
	var key := "s%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := plastic(color, 0.5).duplicate() as StandardMaterial3D
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.35
	m.subsurf_scatter_skin_mode = true
	_cache[key] = m
	return m


## Bright unshaded material for beams, trims and markers.
static func glow(color: Color, energy := 3.0, transparent := false) -> StandardMaterial3D:
	var key := "g%s_%.2f_%s" % [color.to_html(), energy, transparent]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	_cache[key] = m
	return m


static func grid_texture() -> ImageTexture:
	if _grid_tex:
		return _grid_tex
	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for y in size:
		for x in size:
			var v := 0.92 + rng.randf() * 0.06
			var gx := x % 64
			var gy := y % 64
			# Major lines every 64 px (1 m), faint minor lines every 16 px.
			if gx < 2 or gy < 2:
				v = 0.62
			elif gx % 16 == 0 or gy % 16 == 0:
				v = 0.84
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_grid_tex = ImageTexture.create_from_image(img)
	return _grid_tex


static func grid_normal() -> ImageTexture:
	if _grid_normal:
		return _grid_normal
	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var nx := 0.0
			var ny := 0.0
			var gx := x % 64
			var gy := y % 64
			if gx == 0:
				nx = -0.6
			elif gx == 2:
				nx = 0.6
			if gy == 0:
				ny = -0.6
			elif gy == 2:
				ny = 0.6
			var n := Vector3(nx, ny, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	_grid_normal = ImageTexture.create_from_image(img)
	return _grid_normal


## Random blobby splat textures for blood decals (white, tinted by the decal modulate).
static func splat_textures() -> Array[ImageTexture]:
	if not _splat_textures.is_empty():
		return _splat_textures
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 6:
		_splat_textures.append(_make_splat(rng))
	return _splat_textures


static func _make_splat(rng: RandomNumberGenerator) -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var blobs := []
	var c := Vector2(size, size) * 0.5
	blobs.append([c, rng.randf_range(18.0, 26.0)])
	for b in rng.randi_range(8, 16):
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(10.0, 56.0)
		var r := lerpf(12.0, 2.0, dist / 56.0) * rng.randf_range(0.6, 1.3)
		blobs.append([c + Vector2.from_angle(ang) * dist, r])
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var a := 0.0
			for b in blobs:
				var d: float = p.distance_to(b[0])
				var r: float = b[1]
				a = maxf(a, clampf((r - d) / 2.0, 0.0, 1.0))
			if a > 0.0:
				var shade := 0.75 + 0.25 * a
				img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
