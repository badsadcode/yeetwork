class_name Backdrop
extends RefCounted
## Distant scenery around a map, per environment: low-poly, flat-shaded, vertex-coloured
## shapes far beyond the play area (no collision), softened by the environment's haze.
##   hills (day, sunset, night, halloween), islands (tropical), mesas and dunes (desert),
##   peaks and pines (snow), volcano range with a glowing crater and lava streams (volcano).

## Returns a Node3D to add to the arena (or null when the preset has no scenery).
static func build(preset: String, base_y: float, seed_value := 7) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_glow := false
	match preset:
		"tropical":
			for i in 14:
				var a := rng.randf() * TAU
				var r := rng.randf_range(330.0, 700.0)
				var w := rng.randf_range(40.0, 110.0)
				var h := rng.randf_range(18.0, 60.0)
				var p := Vector3(cos(a) * r, base_y - 2.0, sin(a) * r)
				_mound(st, p, w * 1.15, 3.0, Color(0.96, 0.88, 0.62), rng, 9) # beach
				_mound(st, p + Vector3(0, 2.0, 0), w, h, Color(0.28, 0.66, 0.3), rng, 9, Color(0.18, 0.5, 0.25))
				for k in rng.randi_range(2, 5): # palms: a trunk and a tuft
					var q := p + Vector3(rng.randf_range(-0.5, 0.5) * w, 0, rng.randf_range(-0.5, 0.5) * w)
					q.y = base_y + 4.0
					_cone(st, q, 1.2, 16.0, Color(0.55, 0.4, 0.25), 5, 0.6)
					_mound(st, q + Vector3(0, 15.0, 0), 9.0, 3.5, Color(0.2, 0.6, 0.25), rng, 7)
			_mountains(st, rng, 900.0, 1100.0, 10, base_y, 160.0, 280.0, Color(0.35, 0.55, 0.45), Color(0.55, 0.7, 0.6), -1.0)
		"desert":
			for i in 16:
				var a := rng.randf() * TAU
				var r := rng.randf_range(350.0, 800.0)
				var w := rng.randf_range(40.0, 120.0)
				var h := rng.randf_range(40.0, 130.0)
				_mesa(st, Vector3(cos(a) * r, base_y, sin(a) * r), w, h, rng)
			for i in 24:
				var a := rng.randf() * TAU
				var r := rng.randf_range(260.0, 650.0)
				_mound(st, Vector3(cos(a) * r, base_y - 2.0, sin(a) * r), rng.randf_range(50.0, 130.0), rng.randf_range(8.0, 22.0), Color(0.95, 0.76, 0.5), rng, 8, Color(0.85, 0.6, 0.38))
		"snow":
			_mountains(st, rng, 420.0, 900.0, 22, base_y, 120.0, 320.0, Color(0.42, 0.45, 0.55), Color(0.97, 0.98, 1.0), 0.5)
			for i in 60:
				var a := rng.randf() * TAU
				var r := rng.randf_range(260.0, 520.0)
				var p := Vector3(cos(a) * r, base_y, sin(a) * r)
				var h := rng.randf_range(14.0, 30.0)
				_cone(st, p, h * 0.32, h, Color(0.14, 0.32, 0.26), 6, 0.0)
				_cone(st, p + Vector3(0, h * 0.45, 0), h * 0.22, h * 0.6, Color(0.9, 0.95, 1.0), 6, 0.0)
		"volcano":
			_mountains(st, rng, 450.0, 900.0, 18, base_y, 90.0, 240.0, Color(0.14, 0.1, 0.12), Color(0.3, 0.2, 0.2), -1.0)
			var vp := Vector3(-520.0, base_y, -420.0)
			_cone(st, vp, 260.0, 300.0, Color(0.18, 0.12, 0.12), 12, 0.22)
			_cone(glow, vp + Vector3(0, 298.0, 0), 56.0, 6.0, Color(1.0, 0.45, 0.1), 12, 0.0) # crater glow
			for k in 5: # lava streams down the flank
				var a := k * TAU / 5.0 + 0.3
				var top := vp + Vector3(cos(a) * 55.0, 290.0, sin(a) * 55.0)
				var bottom := vp + Vector3(cos(a) * 240.0, 20.0, sin(a) * 240.0)
				_strip(glow, top, bottom, 7.0, Color(1.0, 0.35, 0.05))
			has_glow = true
		"space", "":
			return null
		_: # day, sunset, night, halloween: rolling hills and blue mountains far away
			var grass := Color(0.36, 0.62, 0.32) if preset != "halloween" else Color(0.22, 0.18, 0.28)
			var night := preset in ["night", "halloween"]
			for i in 26:
				var a := rng.randf() * TAU
				var r := rng.randf_range(300.0, 650.0)
				_mound(st, Vector3(cos(a) * r, base_y - 4.0, sin(a) * r), rng.randf_range(80.0, 180.0), rng.randf_range(25.0, 70.0), grass.darkened(0.3 if night else 0.0), rng, 10, grass.darkened(0.25))
			_mountains(st, rng, 750.0, 1100.0, 16, base_y, 140.0, 300.0, Color(0.42, 0.5, 0.7).darkened(0.4 if night else 0.0), Color(0.88, 0.9, 0.98).darkened(0.35 if night else 0.0), 0.62)
	var root := Node3D.new()
	root.name = "Backdrop"
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	root.add_child(mi)
	if has_glow:
		glow.generate_normals()
		var gi := MeshInstance3D.new()
		gi.mesh = glow.commit()
		var gm := StandardMaterial3D.new()
		gm.vertex_color_use_as_albedo = true
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.4, 0.08)
		gm.emission_energy_multiplier = 3.0
		gi.material_override = gm
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gi)
	return root


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_smooth_group(-1) # flat shaded facets
	for v in [a, c, b]:
		st.set_color(col)
		st.add_vertex(v)


## A lumpy dome (hills, dunes, island tops).
static func _mound(st: SurfaceTool, c: Vector3, radius: float, height: float, col: Color, rng: RandomNumberGenerator, sides := 9, low_col := Color(0, 0, 0, 0)) -> void:
	var low := col if low_col.a == 0.0 else low_col
	var ring1: Array[Vector3] = []
	var ring2: Array[Vector3] = []
	for i in sides:
		var a := i * TAU / sides + rng.randf_range(-0.15, 0.15)
		var r := radius * rng.randf_range(0.85, 1.1)
		ring1.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
		ring2.append(c + Vector3(cos(a) * r * 0.55, height * rng.randf_range(0.6, 0.85), sin(a) * r * 0.55))
	var top := c + Vector3(rng.randf_range(-0.1, 0.1) * radius, height, rng.randf_range(-0.1, 0.1) * radius)
	for i in sides:
		var j := (i + 1) % sides
		_tri(st, ring1[i], ring1[j], ring2[j], low)
		_tri(st, ring1[i], ring2[j], ring2[i], low)
		_tri(st, ring2[i], ring2[j], top, col)


## A cone (peaks, trunks, pines, the volcano). crater > 0 cuts the top off.
static func _cone(st: SurfaceTool, c: Vector3, radius: float, height: float, col: Color, sides := 8, crater := 0.0) -> void:
	for i in sides:
		var a0 := i * TAU / sides
		var a1 := (i + 1) * TAU / sides
		var p0 := c + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := c + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		if crater <= 0.0:
			_tri(st, p0, p1, c + Vector3(0, height, 0), col)
		else:
			var t0 := c + Vector3(cos(a0) * radius * crater, height, sin(a0) * radius * crater)
			var t1 := c + Vector3(cos(a1) * radius * crater, height, sin(a1) * radius * crater)
			_tri(st, p0, p1, t1, col)
			_tri(st, p0, t1, t0, col)


## A ring of jagged mountains, snow above snow_line (0..1 of each peak's height; < 0: none).
static func _mountains(st: SurfaceTool, rng: RandomNumberGenerator, inner: float, outer: float, count: int, base_y: float, hmin: float, hmax: float, rock: Color, snow: Color, snow_line: float) -> void:
	for i in count:
		var a := (i + rng.randf() * 0.6) * TAU / count
		var r := rng.randf_range(inner, outer)
		var c := Vector3(cos(a) * r, base_y - 10.0, sin(a) * r)
		var h := rng.randf_range(hmin, hmax)
		var w := h * rng.randf_range(0.9, 1.4)
		var sides := 7
		var peak := c + Vector3(rng.randf_range(-0.15, 0.15) * w, h, rng.randf_range(-0.15, 0.15) * w)
		var base: Array[Vector3] = []
		var mid: Array[Vector3] = []
		for k in sides:
			var b := k * TAU / sides + rng.randf_range(-0.2, 0.2)
			base.append(c + Vector3(cos(b), 0.0, sin(b)) * w * rng.randf_range(0.8, 1.15))
			var m := c.lerp(peak, 0.55) + Vector3(cos(b), 0.0, sin(b)) * w * 0.42 * rng.randf_range(0.8, 1.2)
			mid.append(m)
		var cap := snow if snow_line >= 0.0 and 0.55 >= snow_line else rock
		for k in sides:
			var j := (k + 1) % sides
			_tri(st, base[k], base[j], mid[j], rock)
			_tri(st, base[k], mid[j], mid[k], rock)
			_tri(st, mid[k], mid[j], peak, snow if snow_line >= 0.0 else rock.lightened(0.1))


## A flat-topped mesa with banded sides.
static func _mesa(st: SurfaceTool, c: Vector3, radius: float, height: float, rng: RandomNumberGenerator) -> void:
	var bands := [Color(0.82, 0.42, 0.28), Color(0.9, 0.58, 0.38), Color(0.76, 0.36, 0.25), Color(0.92, 0.66, 0.45)]
	var sides := 8
	var levels := 4
	var rings: Array = []
	for l in levels + 1:
		var ring: Array[Vector3] = []
		var shrink := 1.0 - 0.25 * float(l) / levels
		for k in sides:
			var a := k * TAU / sides
			ring.append(c + Vector3(cos(a) * radius * shrink, height * float(l) / levels, sin(a) * radius * shrink))
		rings.append(ring)
	for l in levels:
		for k in sides:
			var j := (k + 1) % sides
			var col: Color = bands[l % bands.size()]
			_tri(st, rings[l][k], rings[l][j], rings[l + 1][j], col)
			_tri(st, rings[l][k], rings[l + 1][j], rings[l + 1][k], col)
	var top := c + Vector3(0, height, 0)
	for k in sides:
		_tri(st, rings[levels][k], rings[levels][(k + 1) % sides], top, Color(0.8, 0.55, 0.35))


## A flat glowing strip from a to b (lava streams).
static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, width: float, col: Color) -> void:
	var side := (b - a).cross(Vector3.UP).normalized() * width * 0.5
	var lift := Vector3(0, 1.5, 0)
	_tri(st, a - side + lift, a + side + lift, b + side * 2.0 + lift, col)
	_tri(st, a - side + lift, b + side * 2.0 + lift, b - side * 2.0 + lift, col)
