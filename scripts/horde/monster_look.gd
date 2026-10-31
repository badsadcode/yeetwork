class_name MonsterLook
extends RefCounted
## The monsters' looks: one chunky mesh per kind, built here, drawn by the hundred in one
## MultiMesh (Horde). Each part is tagged in UV.x for the shader (monster.gdshader) to swing:
## 0 torso, 1 and 2 the legs, 3 and 4 the arms, 5 the head; UV.y 1 glows (eyes).
## Facing -Z, feet at 0.

const HIP := 0.8
const SHOULDER := 1.35

static var _meshes := {}
static var _material: ShaderMaterial


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin := Color(0.38, 0.7, 0.28)
	var shirt := Color(0.55, 0.22, 0.2)
	var pants := Color(0.26, 0.27, 0.36)
	var eye := Color(1.0, 0.92, 0.3)
	# Legs, a hunched torso, a head pushed forward, arms reaching out in front.
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.13, HIP * 0.5, 0), Vector3(0.22, HIP, 0.24), pants, 1 if s < 0 else 2)
		_box(st, Vector3(s * 0.13, 0.05, -0.05), Vector3(0.24, 0.1, 0.34), Color(0.2, 0.17, 0.15), 1 if s < 0 else 2)
		_box(st, Vector3(s * 0.34, SHOULDER, -0.28), Vector3(0.15, 0.15, 0.62), shirt, 3 if s < 0 else 4)
		_box(st, Vector3(s * 0.34, SHOULDER, -0.66), Vector3(0.14, 0.14, 0.16), skin, 3 if s < 0 else 4)
	_box(st, Vector3(0, 1.12, 0.02), Vector3(0.56, 0.66, 0.34), shirt, 0)
	_box(st, Vector3(0, 0.83, 0.02), Vector3(0.52, 0.1, 0.3), pants, 0)
	_box(st, Vector3(0, 1.62, -0.06), Vector3(0.4, 0.4, 0.38), skin, 5)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.09, 1.66, -0.26), Vector3(0.08, 0.06, 0.02), eye, 5, 1.0)
	_box(st, Vector3(0, 1.5, -0.255), Vector3(0.2, 0.05, 0.02), Color(0.15, 0.08, 0.08), 5)
	st.generate_normals()
	var m := st.commit()
	_meshes[kind] = m
	return m


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scripts/horde/monster.gdshader")
	return _material


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, part: int, glow := 0.0) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var p0 := c + (n - u - v) * h
		var p1 := c + (n + u - v) * h
		var p2 := c + (n + u + v) * h
		var p3 := c + (n - u + v) * h
		for p in [p0, p2, p1, p0, p3, p2]:
			st.set_color(col)
			st.set_uv(Vector2(part, glow))
			st.add_vertex(p)
