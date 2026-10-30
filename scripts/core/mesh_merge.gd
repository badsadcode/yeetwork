class_name MeshMerge
extends RefCounted
## Fewer draw calls for models built from many small pieces (the characters, the gravity gun):
## the meshes under a node become one mesh with a surface per material. Each piece is a draw
## call of its own, so a character of 40 pieces costs 40 (and as many again for shadows).
## - by_color: pieces whose materials differ only in their colour share one surface; the
##   colour goes into the vertices (characters: many plain plastic colours).
## - Pieces in `keep` (and anything under them) stay as they are: the parts that move on
##   their own (eyes, mouth, a propeller...).
## - The merged mesh gets distance LODs (like an imported model), so far away it's lighter
##   still.

static var _vc_materials := {} # material key -> the vertex-colour version, shared by everyone


## Merges the visible meshes under root (in root's space) into one MeshInstance3D added to
## root. Returns it (null when there was nothing worth merging). cache: a Dictionary to
## reuse the built mesh for identical models, under cache_key.
static func merge(root: Node3D, keep: Dictionary, by_color: bool, cache: Dictionary = {}, cache_key := "") -> MeshInstance3D:
	var pieces: Array[MeshInstance3D] = []
	_collect(root, root, keep, pieces)
	if pieces.size() < 2:
		return null
	var mesh: ArrayMesh = cache.get(cache_key) if cache_key != "" else null
	if mesh == null:
		mesh = _build(root, pieces, by_color)
		if cache_key != "":
			cache[cache_key] = mesh
	var mi := MeshInstance3D.new()
	mi.name = "Merged"
	mi.mesh = mesh
	mi.cast_shadow = pieces[0].cast_shadow
	root.add_child(mi)
	for p in pieces:
		if p.get_child_count() == 0:
			p.get_parent().remove_child(p)
			p.free()
		else:
			p.mesh = null # (it holds other nodes, e.g. a muzzle marker)
	return mi


static func _collect(root: Node3D, n: Node, keep: Dictionary, out: Array[MeshInstance3D]) -> void:
	for c in n.get_children():
		if keep.has(c) or not (c is Node3D) or not (c as Node3D).visible:
			continue
		var mi := c as MeshInstance3D
		if mi and mi.mesh and mi.material_overlay == null and mi.mesh.get_surface_count() > 0:
			out.append(mi)
		_collect(root, c, keep, out)


## The material a piece's surface is drawn with.
static func _material(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var m := mi.get_surface_override_material(s)
	return m if m else mi.mesh.surface_get_material(s)


## Plain materials whose only difference is the colour can share a vertex-coloured one.
static func _colorable(m: Material) -> bool:
	var sm := m as StandardMaterial3D
	return sm != null and sm.albedo_texture == null and not sm.emission_enabled \
		and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.vertex_color_use_as_albedo


static func _color_key(sm: StandardMaterial3D) -> String:
	return "%d_%.3f_%.3f_%.3f_%s_%.2f_%s_%.2f_%.2f" % [sm.shading_mode, sm.roughness, sm.metallic, sm.metallic_specular,
		sm.rim_enabled, sm.rim, sm.subsurf_scatter_enabled, sm.subsurf_scatter_strength, sm.rim_tint]


static func _vc_material(sm: StandardMaterial3D) -> StandardMaterial3D:
	var key := _color_key(sm)
	if not _vc_materials.has(key):
		var m := sm.duplicate() as StandardMaterial3D
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_vc_materials[key] = m
	return _vc_materials[key]


static func _build(root: Node3D, pieces: Array[MeshInstance3D], by_color: bool) -> ArrayMesh:
	var im := ImporterMesh.new()
	var groups := {} # key -> {mat, v, n, uv, c, i}
	var order: Array = []
	var inv := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	for p in pieces:
		var xf := _relative(root, p, inv)
		for s in p.mesh.get_surface_count():
			var mat := _material(p, s)
			var col := Color.WHITE
			var key: Variant = mat
			var use_mat := mat
			if by_color and _colorable(mat):
				var sm := mat as StandardMaterial3D
				col = sm.albedo_color
				key = _color_key(sm)
				use_mat = _vc_material(sm)
			if not groups.has(key):
				groups[key] = {"mat": use_mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
				order.append(key)
			_append(groups[key], p.mesh.surface_get_arrays(s), xf, col)
	for key in order:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_TEX_UV] = g.uv
		arrays[Mesh.ARRAY_COLOR] = g.c
		arrays[Mesh.ARRAY_INDEX] = g.i
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, g.mat)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## A piece's transform in root's space (works before the model is in the scene tree too).
static func _relative(root: Node3D, p: Node3D, inv: Transform3D) -> Transform3D:
	if root.is_inside_tree():
		return inv * p.global_transform
	var xf := p.transform
	var n := p.get_parent() as Node3D
	while n and n != root:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf


static func _append(g: Dictionary, a: Array, xf: Transform3D, col: Color) -> void:
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var base: int = g.v.size()
	var nb := xf.basis.inverse().transposed()
	var vs: PackedVector3Array = g.v
	var ns: PackedVector3Array = g.n
	var us: PackedVector2Array = g.uv
	var cs: PackedColorArray = g.c
	var ii: PackedInt32Array = g.i
	for k in verts.size():
		vs.append(xf * verts[k])
		ns.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
		us.append(uvs[k] if k < uvs.size() else Vector2.ZERO)
		cs.append(col)
	var flip := xf.basis.determinant() < 0.0 # a mirrored piece: keep its faces facing out
	if idx.is_empty():
		for k in verts.size():
			idx.append(k)
	for t in range(0, idx.size() - 2, 3):
		if flip:
			ii.append_array([base + idx[t], base + idx[t + 2], base + idx[t + 1]])
		else:
			ii.append_array([base + idx[t], base + idx[t + 1], base + idx[t + 2]])
	g.v = vs
	g.n = ns
	g.uv = us
	g.c = cs
	g.i = ii
