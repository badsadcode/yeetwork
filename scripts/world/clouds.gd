class_name Clouds
extends Node3D
## Cartoony volumetric-looking clouds (cloud.gdshader): clusters of soft balls merged into
## one mesh each, scattered in a ring high above the map and drifting with the wind.
## Graphics option "clouds": 0 off, 1 few, 2 many.

var _mat: ShaderMaterial
var _wind := Vector3(1.6, 0, 0.6)
var _radius := 600.0


## count: how many clouds; altitude/radius in metres; colours for lit tops and shaded bottoms.
static func create(count: int, altitude: float, inner: float, outer: float, lit: Color, shade: Color, size := 1.0, seed_value := 1) -> Clouds:
	var c := Clouds.new()
	c.name = "Clouds"
	c._radius = outer
	c._mat = ShaderMaterial.new()
	c._mat.shader = preload("res://scripts/world/cloud.gdshader")
	c._mat.set_shader_parameter("lit_color", lit)
	c._mat.set_shader_parameter("shade_color", shade)
	c._mat.set_shader_parameter("rim_color", lit.lerp(Color.WHITE, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var meshes: Array[Mesh] = []
	for i in 6: # a few shapes, reused
		meshes.append(_cloud_mesh(rng, size))
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i % meshes.size()]
		mi.material_override = c._mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(inner * inner, outer * outer))
		mi.position = Vector3(cos(a) * r, altitude + rng.randf_range(-0.25, 0.35) * altitude, sin(a) * r)
		mi.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.7, 1.5) * size
		mi.scale = Vector3(s, s * rng.randf_range(0.8, 1.1), s)
		c.add_child(mi)
	return c


## One cloud: a flat-bottomed heap of overlapping spheres, biggest in the middle.
static func _cloud_mesh(rng: RandomNumberGenerator, _size: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var balls := rng.randi_range(6, 11)
	var length := rng.randf_range(28.0, 46.0)
	for b in balls:
		var t := (b + 0.5) / balls
		var bulge := sin(t * PI)
		var r := rng.randf_range(6.0, 9.0) + bulge * rng.randf_range(4.0, 8.0)
		var c := Vector3((t - 0.5) * length, r * 0.55 + rng.randf_range(-1.0, 2.5) * bulge, rng.randf_range(-5.0, 5.0))
		_ball(st, c, r, 2.0 + length * 0.0)
	# A few small puffs on top for a cauliflower crown.
	for k in rng.randi_range(2, 4):
		var c := Vector3(rng.randf_range(-0.25, 0.25) * length, rng.randf_range(12.0, 16.0), rng.randf_range(-3.0, 3.0))
		_ball(st, c, rng.randf_range(4.0, 6.5), 2.0)
	st.generate_normals()
	return st.commit()


static func _ball(st: SurfaceTool, c: Vector3, r: float, _detail: float) -> void:
	var rings := 8
	var segs := 12
	for y in rings:
		for x in segs:
			var quad := []
			for k in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var v: float = float(y + k[1]) / rings
				var u: float = float(x + k[0]) / segs
				var th := v * PI
				var ph := u * TAU
				var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var p := c + n * r
				p.y = maxf(p.y, c.y - r * 0.45) # flat-ish bottom, like real cumulus
				quad.append(p)
			for idx in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = quad[idx]
				st.set_uv(Vector2(0, clampf(p.y / 22.0, 0.0, 1.0)))
				st.add_vertex(p)


func _process(delta: float) -> void:
	if _mat:
		_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	# Drift with the wind; clouds that leave the ring come back on the other side.
	for c in get_children():
		var n := c as Node3D
		n.position += _wind * delta
		var flat := Vector2(n.position.x, n.position.z)
		if flat.length() > _radius * 1.1:
			n.position.x = -n.position.x * 0.98
			n.position.z = -n.position.z * 0.98
