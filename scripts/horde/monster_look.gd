class_name MonsterLook
extends RefCounted
## The monsters' looks: one chunky mesh per kind, built here, drawn by the hundred in one
## MultiMesh per kind (Horde). Each part is tagged in UV.x for the shader (monster.gdshader)
## to swing: 0 torso, 1 and 2 the legs, 3 and 4 the arms, 5 the head; UV.y 1 glows (eyes, a
## fuse). Facing -Z, feet at 0, the hips at HIP and shoulders at SHOULDER for every kind (the
## shader's pivots); a bigger or smaller kind is scaled as a whole (Horde.KINDS size).
## - shambler: a zombie, arms out. - runner: lean and grey, head down, sprinting.
## - brute: Frankenstein's monster: square head, flat black hair, neck bolts, a dark coat.
## - ghost: a floating sheet with trailing arms (see-through: monster_ghost.gdshader).
## - climber: a skeleton. - bomber: a little imp with a lit powder keg on its back.

const HIP := 0.8
const SHOULDER := 1.35

static var _meshes := {}
static var _materials := {}


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"runner":
			_runner(st)
		"brute":
			_brute(st)
		"ghost":
			_ghost(st)
		"climber":
			_skeleton(st)
		"bomber":
			_bomber(st)
		_:
			_shambler(st)
	st.generate_normals()
	var m := st.commit()
	_meshes[kind] = m
	return m


static func material(kind := "shambler") -> ShaderMaterial:
	var key := "ghost" if kind == "ghost" else "solid"
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://scripts/horde/monster_ghost.gdshader") if key == "ghost" else preload("res://scripts/horde/monster.gdshader")
		_materials[key] = m
	return _materials[key]


static func _shambler(st: SurfaceTool) -> void:
	var skin := Color(0.38, 0.7, 0.28)
	var shirt := Color(0.55, 0.22, 0.2)
	var pants := Color(0.26, 0.27, 0.36)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.13, HIP * 0.5, 0), Vector3(0.22, HIP, 0.24), pants, _leg(s))
		_box(st, Vector3(s * 0.13, 0.05, -0.05), Vector3(0.24, 0.1, 0.34), Color(0.2, 0.17, 0.15), _leg(s))
		_box(st, Vector3(s * 0.34, SHOULDER, -0.28), Vector3(0.15, 0.15, 0.62), shirt, _arm(s))
		_box(st, Vector3(s * 0.34, SHOULDER, -0.66), Vector3(0.14, 0.14, 0.16), skin, _arm(s))
	_box(st, Vector3(0, 1.12, 0.02), Vector3(0.56, 0.66, 0.34), shirt, 0)
	_box(st, Vector3(0, 0.83, 0.02), Vector3(0.52, 0.1, 0.3), pants, 0)
	_box(st, Vector3(0, 1.62, -0.06), Vector3(0.4, 0.4, 0.38), skin, 5)
	_eyes(st, 1.66, -0.26, Color(1.0, 0.92, 0.3))
	_box(st, Vector3(0, 1.5, -0.255), Vector3(0.2, 0.05, 0.02), Color(0.15, 0.08, 0.08), 5)


static func _runner(st: SurfaceTool) -> void:
	var skin := Color(0.62, 0.64, 0.6)
	var rag := Color(0.42, 0.36, 0.28)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.11, HIP * 0.5, 0), Vector3(0.15, HIP, 0.16), skin, _leg(s))
		_box(st, Vector3(s * 0.11, HIP * 0.78, 0), Vector3(0.18, 0.28, 0.2), rag, _leg(s))
		# Arms swept back as it runs.
		_box(st, Vector3(s * 0.3, SHOULDER - 0.05, 0.2), Vector3(0.11, 0.11, 0.5), skin, _arm(s))
	_box(st, Vector3(0, 1.08, -0.08), Vector3(0.4, 0.58, 0.24), rag, 0)
	_box(st, Vector3(0, 1.48, -0.3), Vector3(0.32, 0.34, 0.34), skin, 5)
	_eyes(st, 1.52, -0.475, Color(1.0, 0.3, 0.2))
	_box(st, Vector3(0, 1.36, -0.47), Vector3(0.2, 0.1, 0.02), Color(0.2, 0.05, 0.05), 5) # (mouth open)


static func _brute(st: SurfaceTool) -> void:
	var skin := Color(0.45, 0.62, 0.38)
	var coat := Color(0.16, 0.16, 0.2)
	var boots := Color(0.1, 0.09, 0.08)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.16, HIP * 0.5, 0), Vector3(0.28, HIP, 0.3), coat, _leg(s))
		_box(st, Vector3(s * 0.16, 0.1, -0.05), Vector3(0.32, 0.2, 0.42), boots, _leg(s))
		_box(st, Vector3(s * 0.44, SHOULDER - 0.25, -0.05), Vector3(0.22, 0.6, 0.24), coat, _arm(s))
		_box(st, Vector3(s * 0.44, SHOULDER - 0.6, -0.08), Vector3(0.24, 0.2, 0.26), skin, _arm(s))
		_box(st, Vector3(s * 0.17, 1.52, 0.0), Vector3(0.1, 0.06, 0.06), Color(0.6, 0.6, 0.62), 5) # (neck bolts)
	_box(st, Vector3(0, 1.12, 0.02), Vector3(0.72, 0.72, 0.42), coat, 0)
	_box(st, Vector3(0, 1.66, -0.02), Vector3(0.42, 0.4, 0.38), skin, 5)
	_box(st, Vector3(0, 1.89, -0.02), Vector3(0.44, 0.07, 0.4), Color(0.05, 0.05, 0.06), 5) # (flat top)
	_box(st, Vector3(0, 1.79, -0.215), Vector3(0.38, 0.06, 0.02), Color(0.05, 0.05, 0.06), 5) # (fringe)
	_eyes(st, 1.7, -0.215, Color(0.9, 0.9, 0.6))
	_box(st, Vector3(0, 1.55, -0.215), Vector3(0.18, 0.03, 0.02), Color(0.15, 0.1, 0.1), 5)


static func _ghost(st: SurfaceTool) -> void:
	var sheet := Color(0.75, 0.85, 1.0)
	# A sheet tapering down to nothing (no legs), arms trailing forward.
	_box(st, Vector3(0, 1.25, 0), Vector3(0.6, 0.7, 0.42), sheet, 0)
	_box(st, Vector3(0, 0.8, 0.02), Vector3(0.52, 0.3, 0.38), sheet, 0)
	_box(st, Vector3(0, 0.55, 0.04), Vector3(0.4, 0.25, 0.3), sheet, 0)
	_box(st, Vector3(0, 0.36, 0.06), Vector3(0.24, 0.16, 0.2), sheet, 0)
	_box(st, Vector3(0, 1.72, -0.02), Vector3(0.44, 0.38, 0.4), sheet, 5)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.36, SHOULDER - 0.05, -0.3), Vector3(0.13, 0.13, 0.55), sheet, _arm(s))
	_eyes(st, 1.76, -0.225, Color(0.2, 0.9, 1.0))
	_box(st, Vector3(0, 1.62, -0.225), Vector3(0.14, 0.1, 0.02), Color(0.1, 0.1, 0.2), 5)


static func _skeleton(st: SurfaceTool) -> void:
	var bone := Color(0.92, 0.9, 0.82)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.12, HIP * 0.5, 0), Vector3(0.08, HIP, 0.08), bone, _leg(s))
		_box(st, Vector3(s * 0.12, 0.04, -0.06), Vector3(0.12, 0.08, 0.22), bone, _leg(s))
		_box(st, Vector3(s * 0.3, SHOULDER - 0.05, -0.25), Vector3(0.07, 0.07, 0.6), bone, _arm(s))
	_box(st, Vector3(0, 0.84, 0), Vector3(0.36, 0.1, 0.16), bone, 0) # (pelvis)
	_box(st, Vector3(0, 1.08, 0.04), Vector3(0.07, 0.5, 0.07), bone, 0) # (spine)
	for k in 4: # (ribs)
		_box(st, Vector3(0, 1.0 + k * 0.1, 0.0), Vector3(0.42 - k * 0.03, 0.04, 0.24), bone, 0)
	_box(st, Vector3(0, 1.36, 0.0), Vector3(0.6, 0.06, 0.08), bone, 0) # (shoulders)
	_box(st, Vector3(0, 1.6, -0.04), Vector3(0.34, 0.34, 0.34), bone, 5)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.08, 1.63, -0.215), Vector3(0.1, 0.09, 0.02), Color(0.08, 0.05, 0.05), 5)
	_eyes(st, 1.63, -0.228, Color(1.0, 0.25, 0.15), 0.035)
	_box(st, Vector3(0, 1.49, -0.215), Vector3(0.2, 0.04, 0.02), Color(0.3, 0.28, 0.25), 5) # (teeth)


static func _bomber(st: SurfaceTool) -> void:
	var skin := Color(0.6, 0.3, 0.62)
	var keg := Color(0.7, 0.18, 0.12)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.12, HIP * 0.5, 0), Vector3(0.16, HIP, 0.18), skin, _leg(s))
		_box(st, Vector3(s * 0.3, SHOULDER - 0.1, -0.2), Vector3(0.12, 0.12, 0.45), skin, _arm(s))
	_box(st, Vector3(0, 1.08, -0.02), Vector3(0.42, 0.56, 0.3), Color(0.3, 0.25, 0.2), 0)
	_box(st, Vector3(0, 1.52, -0.08), Vector3(0.36, 0.34, 0.34), skin, 5)
	for s in [-1, 1]: # (pointed ears)
		_box(st, Vector3(s * 0.22, 1.6, -0.08), Vector3(0.1, 0.16, 0.05), skin, 5)
	_eyes(st, 1.56, -0.255, Color(1.0, 0.85, 0.2))
	# The keg on its back, a fuse burning on top.
	_box(st, Vector3(0, 1.25, 0.33), Vector3(0.44, 0.6, 0.4), keg, 0)
	_box(st, Vector3(0, 1.25, 0.33), Vector3(0.46, 0.06, 0.42), Color(0.2, 0.2, 0.22), 0)
	_box(st, Vector3(0, 1.62, 0.33), Vector3(0.04, 0.16, 0.04), Color(0.25, 0.2, 0.15), 0)
	_box(st, Vector3(0, 1.72, 0.33), Vector3(0.08, 0.08, 0.08), Color(1.0, 0.7, 0.2), 0, 1.0)


static func _eyes(st: SurfaceTool, y: float, z: float, col: Color, size := 0.07) -> void:
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.09, y, z), Vector3(size, size * 0.8, 0.02), col, 5, 1.0)


static func _leg(s: int) -> int:
	return 1 if s < 0 else 2


static func _arm(s: int) -> int:
	return 3 if s < 0 else 4


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
