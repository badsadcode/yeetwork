@tool
class_name Fracture
extends RefCounted
## 2D fracture geometry for slab-like destructibles (walls, floors, bridges) and their
## fragments. Slabs live in a local XY plane with thickness along Z, so every cell and
## fragment is an extruded polygon (prism):
##   * voronoi(): seeded irregular cell pattern, with neighbor graph.
##   * jagged(): noisy cell outlines; shared edges displace identically on both sides
##     so intact walls stay watertight while holes get ragged borders.
##   * shatter(): splits one polygon into irregular sub-fragments (impact debris).
##   * Prism mesh/collision builders for walls and debris.

const MATERIALS := {
	# cell: base cell size (x, y) in meters; jitter: seed randomness; shatter: fragments per
	# broken cell near an impact; hp: cell health; density: gameplay kg/m^3.
	"plaster": {"cell": Vector2(0.9, 0.9), "jitter": 0.42, "shatter": 3, "hp": 90.0, "density": 80.0, "jag": 0.14, "sound": "crack"},
	"concrete": {"cell": Vector2(1.0, 1.0), "jitter": 0.45, "shatter": 3, "hp": 160.0, "density": 140.0, "jag": 0.16, "sound": "crack"},
	"brick": {"cell": Vector2(1.2, 0.6), "jitter": 0.12, "shatter": 2, "hp": 130.0, "density": 120.0, "jag": 0.05, "sound": "crack", "brick": true},
	"wood": {"cell": Vector2(0.55, 1.6), "jitter": 0.3, "shatter": 3, "hp": 70.0, "density": 55.0, "jag": 0.1, "sound": "splinter", "grain": Vector2(1.0, 0.35)},
	"glass": {"cell": Vector2(0.6, 0.6), "jitter": 0.48, "shatter": 6, "hp": 25.0, "density": 90.0, "jag": 0.08, "sound": "glass"},
	"metal": {"cell": Vector2(1.2, 1.2), "jitter": 0.3, "shatter": 2, "hp": 500.0, "density": 300.0, "jag": 0.03, "sound": "clang"},
	# Ice: cracks spread far before it gives way, then bursts into chunky shards.
	"ice": {"cell": Vector2(0.75, 0.75), "jitter": 0.45, "shatter": 4, "hp": 45.0, "density": 92.0, "jag": 0.1, "sound": "glass"},
}


static func mat(name: String) -> Dictionary:
	return MATERIALS.get(name, MATERIALS.plaster)


# --- Polygon basics -------------------------------------------------------------------

## Keep the part of a convex polygon where dot(p - o, n) <= 0.
static func clip(poly: PackedVector2Array, o: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := poly.size()
	for i in cnt:
		var a := poly[i]
		var b := poly[(i + 1) % cnt]
		var da := (a - o).dot(n)
		var db := (b - o).dot(n)
		if da <= 0.0:
			out.append(a)
		if (da <= 0.0) != (db <= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


static func area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


static func centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	var a2 := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var cr := p.x * q.y - q.x * p.y
		a2 += cr
		c += (p + q) * cr
	if absf(a2) < 1e-8:
		for p in poly:
			c += p
		return c / maxf(poly.size(), 1)
	return c / (3.0 * a2)


static func translated(poly: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + off)
	return out


# --- Voronoi slab pattern -------------------------------------------------------------

## Returns {"polys": Array[PackedVector2Array], "seeds": PackedVector2Array,
## "neighbors": Array[PackedInt32Array]} covering a w x h rectangle centered at origin.
static func voronoi(w: float, h: float, material: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cs: Vector2 = material.cell
	var jitter: float = material.jitter
	var nx := maxi(1, int(round(w / cs.x)))
	var ny := maxi(1, int(round(h / cs.y)))
	var sx := w / nx
	var sy := h / ny
	var seeds := PackedVector2Array()
	for iy in ny:
		var offset := 0.5 if material.get("brick", false) and iy % 2 == 1 else 0.0
		var count := nx + (1 if offset > 0.0 else 0)
		for ix in count:
			var x := (ix + 0.5 - offset) * sx - w * 0.5
			var y := (iy + 0.5) * sy - h * 0.5
			x += rng.randf_range(-jitter, jitter) * sx
			y += rng.randf_range(-jitter, jitter) * sy
			seeds.append(Vector2(clampf(x, -w * 0.5 + 0.02, w * 0.5 - 0.02), clampf(y, -h * 0.5 + 0.02, h * 0.5 - 0.02)))
	# Anisotropic metric (wood grain) is applied by scaling space before bisecting.
	var metric: Vector2 = material.get("grain", Vector2.ONE)
	var rect := PackedVector2Array([Vector2(-w, -h) * 0.5, Vector2(w, -h) * 0.5, Vector2(w, h) * 0.5, Vector2(-w, h) * 0.5])
	var reach := maxf(sx, sy) * 2.6
	var polys: Array[PackedVector2Array] = []
	var neighbors: Array[PackedInt32Array] = []
	for i in seeds.size():
		var si := seeds[i]
		var poly := rect.duplicate()
		var cands := PackedInt32Array()
		for j in seeds.size():
			if j != i and seeds[j].distance_to(si) < reach:
				cands.append(j)
				poly = _clip_bisector(poly, si, seeds[j], metric)
		polys.append(poly)
		var nb := PackedInt32Array()
		for j in cands:
			if _on_bisector_count(poly, si, seeds[j], metric) >= 2:
				nb.append(j)
		neighbors.append(nb)
	return {"polys": polys, "seeds": seeds, "neighbors": neighbors}


static func _clip_bisector(poly: PackedVector2Array, a: Vector2, b: Vector2, metric: Vector2) -> PackedVector2Array:
	# Bisector in metric space mapped back: points p with |M(p-a)| <= |M(p-b)|.
	var m2 := metric * metric
	var n := (b - a) * m2
	var o := (a + b) * 0.5
	return clip(poly, o, n.normalized())


static func _on_bisector_count(poly: PackedVector2Array, a: Vector2, b: Vector2, metric: Vector2) -> int:
	var m2 := metric * metric
	var n := ((b - a) * m2).normalized()
	var o := (a + b) * 0.5
	var c := 0
	for p in poly:
		if absf((p - o).dot(n)) < 1e-4:
			c += 1
	return c


# --- Jagged outlines ------------------------------------------------------------------

## Adds two noise-displaced points to every interior edge. Edges on the slab border stay
## straight. Displacement is keyed on the (rounded) edge so neighbors agree exactly.
static func jagged(poly: PackedVector2Array, w: float, h: float, amp: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := poly.size()
	for i in cnt:
		var a := poly[i]
		var b := poly[(i + 1) % cnt]
		out.append(a)
		if amp <= 0.0 or _on_border(a, b, w, h) or a.distance_to(b) < 0.18:
			continue
		var ka := a.snapped(Vector2(0.001, 0.001))
		var kb := b.snapped(Vector2(0.001, 0.001))
		var forward := ka.x < kb.x or (is_equal_approx(ka.x, kb.x) and ka.y < kb.y)
		var p0 := ka if forward else kb
		var p1 := kb if forward else ka
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%.3f,%.3f,%.3f,%.3f" % [p0.x, p0.y, p1.x, p1.y])
		var dir := p1 - p0
		var perp := Vector2(-dir.y, dir.x).normalized()
		var l := dir.length()
		var pts := [p0.lerp(p1, 0.33) + perp * rng.randf_range(-amp, amp) * l, p0.lerp(p1, 0.67) + perp * rng.randf_range(-amp, amp) * l]
		if not forward:
			pts.reverse()
		out.append(pts[0])
		out.append(pts[1])
	return out


static func _on_border(a: Vector2, b: Vector2, w: float, h: float) -> bool:
	var e := 0.002
	var hw := w * 0.5
	var hh := h * 0.5
	return (absf(a.x - hw) < e and absf(b.x - hw) < e) or (absf(a.x + hw) < e and absf(b.x + hw) < e) \
		or (absf(a.y - hh) < e and absf(b.y - hh) < e) or (absf(a.y + hh) < e and absf(b.y + hh) < e)


# --- Shattering -----------------------------------------------------------------------

## Splits a convex polygon into `count` irregular convex pieces (Voronoi inside it).
## `bias` (local 2D point) concentrates seeds toward an impact.
static func shatter(poly: PackedVector2Array, count: int, rng: RandomNumberGenerator, bias := Vector2.INF, metric := Vector2.ONE) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if count <= 1 or poly.size() < 3:
		out.append(poly)
		return out
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var seeds := PackedVector2Array()
	var tries := 0
	while seeds.size() < count and tries < count * 20:
		tries += 1
		var s := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if bias != Vector2.INF and rng.randf() < 0.5:
			s = s.lerp(bias, rng.randf_range(0.2, 0.6))
		if Geometry2D.is_point_in_polygon(s, poly):
			seeds.append(s)
	if seeds.size() < 2:
		out.append(poly)
		return out
	for i in seeds.size():
		var piece := poly.duplicate()
		for j in seeds.size():
			if j != i:
				piece = _clip_bisector(piece, seeds[i], seeds[j], metric)
		if piece.size() >= 3 and area(piece) > 0.002:
			out.append(piece)
	return out


## Cuts a convex polygon in two along a random line through `through`.
static func split(poly: PackedVector2Array, through: Vector2, rng: RandomNumberGenerator) -> Array[PackedVector2Array]:
	var n := Vector2.from_angle(rng.randf() * TAU)
	var a := clip(poly, through, n)
	var b := clip(poly, through, -n)
	var out: Array[PackedVector2Array] = []
	for p in [a, b]:
		if p.size() >= 3 and area(p) > 0.01:
			out.append(p)
	return out


# --- Meshes & collision ---------------------------------------------------------------

## Convex prism collision points.
static func prism_points(poly: PackedVector2Array, t: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for p in poly:
		pts.append(Vector3(p.x, p.y, t * 0.5))
		pts.append(Vector3(p.x, p.y, -t * 0.5))
	return pts


class MeshBuilder:
	## Two surfaces: 0 = outer faces (front/back), 1 = fracture faces (sides).
	var faces_v := PackedVector3Array()
	var faces_n := PackedVector3Array()
	var faces_c := PackedColorArray()
	var sides_v := PackedVector3Array()
	var sides_n := PackedVector3Array()
	var sides_c := PackedColorArray()

	func _tri(v: PackedVector3Array, nn: PackedVector3Array, cc: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
		# Godot treats clockwise triangles as front-facing.
		if (b - a).cross(c - a).dot(n) > 0.0:
			var tmp := b
			b = c
			c = tmp
		v.append_array([a, b, c])
		nn.append_array([n, n, n])
		cc.append_array([col, col, col])

	## Adds an extruded polygon. `z_front` / `z_back` are the face depths.
	func add_prism(poly: PackedVector2Array, z_front: float, z_back: float, col := Color(0, 0, 0, 1), with_faces := true) -> void:
		var cnt := poly.size()
		if cnt < 3:
			return
		if with_faces:
			var idx := Geometry2D.triangulate_polygon(poly)
			if idx.is_empty():
				idx = PackedInt32Array()
				for i in range(1, cnt - 1):
					idx.append_array([0, i, i + 1])
			for k in range(0, idx.size(), 3):
				var p0 := poly[idx[k]]
				var p1 := poly[idx[k + 1]]
				var p2 := poly[idx[k + 2]]
				_tri(faces_v, faces_n, faces_c, Vector3(p0.x, p0.y, z_front), Vector3(p1.x, p1.y, z_front), Vector3(p2.x, p2.y, z_front), Vector3.BACK, col)
				_tri(faces_v, faces_n, faces_c, Vector3(p0.x, p0.y, z_back), Vector3(p1.x, p1.y, z_back), Vector3(p2.x, p2.y, z_back), Vector3.FORWARD, col)
		var ccw := _signed_area(poly) > 0.0
		for i in cnt:
			var a := poly[i]
			var b := poly[(i + 1) % cnt]
			var e := b - a
			if e.length_squared() < 1e-8:
				continue
			var out2 := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
			var n := Vector3(out2.x, out2.y, 0.0)
			var af := Vector3(a.x, a.y, z_front)
			var bf := Vector3(b.x, b.y, z_front)
			var ab := Vector3(a.x, a.y, z_back)
			var bb := Vector3(b.x, b.y, z_back)
			_tri(sides_v, sides_n, sides_c, af, bf, bb, n, col)
			_tri(sides_v, sides_n, sides_c, af, bb, ab, n, col)

	func _signed_area(poly: PackedVector2Array) -> float:
		var s := 0.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			s += a.x * b.y - b.x * a.y
		return s

	func commit(face_mat: Material, side_mat: Material) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for pair in [[faces_v, faces_n, faces_c, face_mat], [sides_v, sides_n, sides_c, side_mat]]:
			var verts: PackedVector3Array = pair[0]
			if verts.is_empty():
				# Keep surface indices stable: add a degenerate triangle.
				verts = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
				pair[1] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
				pair[2] = PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = pair[1]
			arrays[Mesh.ARRAY_COLOR] = pair[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, pair[3])
		return mesh


## Builds a debris mesh + convex shapes for a fragment made of one or more polygons.
static func fragment_mesh(polys: Array, t: float, face_mat: Material, side_mat: Material) -> ArrayMesh:
	var mb := MeshBuilder.new()
	for p in polys:
		mb.add_prism(p, t * 0.5, -t * 0.5)
	return mb.commit(face_mat, side_mat)
