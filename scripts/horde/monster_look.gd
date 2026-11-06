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
## - golem (a boss): a hulk of stone blocks, glowing cracks, fists like boulders.
## - ram (a boss): a hunched horned beast, head down, great curling horns, an iron nose ring.
## A monster of your own (a MonsterType's model, a MapTheme's monster slot): from_model()
## tags its parts the same way, from their names, and its joints come from the parts' origins.

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
		"golem":
			_golem(st)
		"ram":
			_ram(st)
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


## Your model's part names (lower case) and their tags.
const PARTS := {"torso": 0, "leg_l": 1, "leg_r": 2, "arm_l": 3, "arm_r": 4, "head": 5}
const PART_NAMES := ["Torso", "Leg_L", "Leg_R", "Arm_L", "Arm_R", "Head"]
static var _models := {} # model path (+ "#ghost") -> ArrayMesh

## A monster model of your own as one mesh for the horde: its parts named Torso, Leg_L, Leg_R,
## Arm_L, Arm_R, Head (each with its origin at its joint) tagged for the shader to swing
## (anything else rides on the part it's in, or the torso); "Glow" in a part's or a
## material's name, or an emissive material, glows. A surface per texture, each with its own
## material (the joints, the texture): draw it without a material override. ghost: see-through
## (monster_ghost.gdshader).
static func from_model(scene: PackedScene, ghost := false) -> ArrayMesh:
	var key := scene.resource_path + ("#ghost" if ghost else "")
	if _models.has(key):
		return _models[key]
	var root := scene.instantiate() as Node3D
	var joints := {}
	var groups := {} # texture (or null) -> SurfaceTool
	_take(root, Transform3D.IDENTITY, 0, false, joints, groups)
	root.free()
	var mesh := ArrayMesh.new()
	for tex in groups:
		var st: SurfaceTool = groups[tex]
		st.commit(mesh)
		var m := ShaderMaterial.new()
		m.shader = preload("res://scripts/horde/monster_ghost.gdshader") if ghost else preload("res://scripts/horde/monster.gdshader")
		m.set_shader_parameter("legs", _pair(joints, 1, 2, Vector2(0.8, 0.0)))
		m.set_shader_parameter("arms", _pair(joints, 3, 4, Vector2(1.35, 0.0)))
		if tex:
			m.set_shader_parameter("albedo_tex", tex)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	mesh.set_meta("joints", joints)
	_models[key] = mesh
	return mesh


## What a monster model is missing (for the map check): [] when every part is there.
static func notes(scene: PackedScene) -> Array:
	var root := scene.instantiate() as Node3D
	var found := {}
	for n in root.find_children("*", "Node3D", true, false):
		var p := _part_of(n.name)
		if p >= 0:
			found[p] = true
	root.free()
	var out := []
	for i in PART_NAMES.size():
		if not found.has(i):
			out.append(PART_NAMES[i])
	return out


static func _part_of(node_name: String) -> int:
	var n := node_name.to_lower().replace(".", "_").replace(" ", "_")
	for k in PARTS:
		if n == k or n.begins_with(k + "_"):
			return PARTS[k]
	return -1


static func _pair(joints: Dictionary, l: int, r: int, fallback: Vector2) -> Vector4:
	var a: Vector3 = joints.get(l, joints.get(r, Vector3(0, fallback.x, fallback.y)))
	var b: Vector3 = joints.get(r, joints.get(l, Vector3(0, fallback.x, fallback.y)))
	return Vector4(a.y, a.z, b.y, b.z)


## Every mesh under n into its texture's SurfaceTool, in the model's space, tagged.
static func _take(n: Node, xf: Transform3D, part: int, glow: bool, joints: Dictionary, groups: Dictionary) -> void:
	var p := _part_of(n.name)
	if p >= 0:
		part = p
		if not joints.has(p):
			joints[p] = xf.origin
	glow = glow or n.name.to_lower().contains("glow")
	var mi := n as MeshInstance3D
	if mi and mi.mesh and mi.visible:
		for s in mi.mesh.get_surface_count():
			# (only an ArrayMesh can be asked; Godot's own box and sphere are triangles)
			if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat := mi.get_active_material(s) as BaseMaterial3D
			var tex: Texture2D = mat.albedo_texture if mat else null
			var tint := mat.albedo_color.srgb_to_linear() if mat else Color.WHITE # (the shader takes it as it is)
			var shine := glow or (mat != null and (mat.emission_enabled or mat.resource_name.to_lower().contains("glow")))
			if not groups.has(tex):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[tex] = st
			var g: SurfaceTool = groups[tex]
			var a := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var cols: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx[i] = i
			var nb := xf.basis.inverse().transposed()
			for i in idx:
				g.set_color(tint * (cols[i] if i < cols.size() else Color.WHITE))
				g.set_uv(Vector2(part, 1.0 if shine else 0.0))
				g.set_uv2(uvs[i] if i < uvs.size() else Vector2.ZERO)
				g.set_normal((nb * norms[i]).normalized() if i < norms.size() else Vector3.UP)
				g.add_vertex(xf * verts[i])
	for c in n.get_children():
		if c is Node3D:
			_take(c, xf * (c as Node3D).transform, part, glow, joints, groups)


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


static func _golem(st: SurfaceTool) -> void:
	var stone := Color(0.46, 0.44, 0.42)
	var dark := Color(0.3, 0.29, 0.28)
	var moss := Color(0.3, 0.45, 0.2)
	var glow := Color(1.0, 0.45, 0.1)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.17, HIP * 0.5, 0), Vector3(0.28, HIP, 0.3), dark, _leg(s))
		_box(st, Vector3(s * 0.17, 0.08, -0.04), Vector3(0.34, 0.16, 0.42), stone, _leg(s))
		# Long arms hanging to the knees, fists like boulders.
		_box(st, Vector3(s * 0.48, SHOULDER - 0.3, -0.05), Vector3(0.22, 0.62, 0.24), stone, _arm(s))
		_box(st, Vector3(s * 0.5, SHOULDER - 0.72, -0.08), Vector3(0.32, 0.3, 0.32), dark, _arm(s))
		_box(st, Vector3(s * 0.5, SHOULDER - 0.6, -0.245), Vector3(0.2, 0.03, 0.02), glow, _arm(s), 1.0)
		_box(st, Vector3(s * 0.4, SHOULDER + 0.08, 0.0), Vector3(0.36, 0.26, 0.4), stone, 0) # (shoulder slabs)
		_box(st, Vector3(s * 0.4, SHOULDER + 0.22, 0.0), Vector3(0.3, 0.05, 0.34), moss, 0)
	_box(st, Vector3(0, 1.08, 0.04), Vector3(0.72, 0.66, 0.48), stone, 0)
	_box(st, Vector3(0, 0.84, 0.02), Vector3(0.6, 0.14, 0.42), dark, 0)
	# Glowing cracks across the chest.
	_box(st, Vector3(-0.08, 1.16, -0.205), Vector3(0.04, 0.4, 0.02), glow, 0, 1.0)
	_box(st, Vector3(0.06, 1.02, -0.205), Vector3(0.3, 0.04, 0.02), glow, 0, 1.0)
	_box(st, Vector3(0.16, 1.24, -0.205), Vector3(0.04, 0.22, 0.02), glow, 0, 1.0)
	# Its back: a ridge of stones down the spine, cracks glowing between them, moss.
	for k in 3:
		_box(st, Vector3(0, 0.95 + k * 0.17, 0.3), Vector3(0.2, 0.12, 0.08), dark, 0)
	_box(st, Vector3(0.14, 1.1, 0.29), Vector3(0.04, 0.42, 0.02), glow, 0, 1.0) # (on the back's surface, z 0.28)
	_box(st, Vector3(-0.16, 1.18, 0.29), Vector3(0.26, 0.04, 0.02), glow, 0, 1.0)
	_box(st, Vector3(-0.2, 0.98, 0.29), Vector3(0.22, 0.16, 0.03), moss, 0)
	# A small head sunk between the shoulders.
	_box(st, Vector3(0, 1.5, -0.08), Vector3(0.3, 0.26, 0.28), stone, 5)
	_box(st, Vector3(0, 1.65, -0.08), Vector3(0.32, 0.06, 0.3), moss, 5)
	_eyes(st, 1.52, -0.225, glow, 0.06)


static func _ram(st: SurfaceTool) -> void:
	var hide := Color(0.36, 0.2, 0.13)
	var dark := Color(0.2, 0.12, 0.09)
	var wool := Color(0.62, 0.55, 0.42)
	var horn := Color(0.85, 0.78, 0.6)
	var iron := Color(0.25, 0.26, 0.3)
	var glow := Color(1.0, 0.25, 0.1)
	for s in [-1, 1]:
		_box(st, Vector3(s * 0.2, HIP * 0.55, 0.04), Vector3(0.3, HIP * 0.9, 0.34), hide, _leg(s))
		_box(st, Vector3(s * 0.2, 0.07, -0.04), Vector3(0.34, 0.14, 0.44), dark, _leg(s)) # (hooves)
		# Thick arms held low and forward, hooves for fists.
		_box(st, Vector3(s * 0.5, SHOULDER - 0.14, -0.2), Vector3(0.26, 0.34, 0.6), hide, _arm(s))
		_box(st, Vector3(s * 0.5, SHOULDER - 0.3, -0.56), Vector3(0.3, 0.26, 0.26), dark, _arm(s))
		_box(st, Vector3(s * 0.34, SHOULDER + 0.06, 0.0), Vector3(0.42, 0.34, 0.5), wool, 0) # (shaggy shoulders)
		# Horns: out from the head, curling round and forward.
		_box(st, Vector3(s * 0.25, 1.52, -0.3), Vector3(0.2, 0.16, 0.18), horn, 5)
		_box(st, Vector3(s * 0.4, 1.58, -0.27), Vector3(0.16, 0.18, 0.16), horn, 5)
		_box(st, Vector3(s * 0.48, 1.47, -0.33), Vector3(0.13, 0.2, 0.15), horn, 5)
		_box(st, Vector3(s * 0.46, 1.34, -0.44), Vector3(0.1, 0.14, 0.18), horn, 5)
		_box(st, Vector3(s * 0.4, 1.27, -0.55), Vector3(0.07, 0.08, 0.16), horn, 5)
	_box(st, Vector3(0, 1.12, 0.08), Vector3(0.74, 0.62, 0.6), hide, 0)
	_box(st, Vector3(0, 0.84, 0.06), Vector3(0.62, 0.16, 0.5), dark, 0)
	_box(st, Vector3(0, 1.4, 0.18), Vector3(0.52, 0.22, 0.44), wool, 0) # (the hump)
	# Its head, low and thrust forward: a heavy brow, a long muzzle, a ring through the nose.
	_box(st, Vector3(0, 1.42, -0.38), Vector3(0.36, 0.34, 0.34), hide, 5)
	_box(st, Vector3(0, 1.58, -0.38), Vector3(0.38, 0.1, 0.36), wool, 5)
	_box(st, Vector3(0, 1.28, -0.58), Vector3(0.24, 0.2, 0.2), dark, 5)
	_box(st, Vector3(0, 1.16, -0.68), Vector3(0.12, 0.1, 0.03), iron, 5)
	_eyes(st, 1.46, -0.56, glow, 0.07)


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
