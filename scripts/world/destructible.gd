class_name Destructible
extends Node3D
## A breakable slab (wall, floor, bridge, window) made of irregular Voronoi cells.
## The local slab lies in the XY plane with thickness along Z. Every peer builds the same
## cells from the same seed, so `wall_id` + cell index identifies a cell on the network.
##
## The visible mesh is rebuilt from the surviving cells with jagged outlines, so holes are
## real geometry. Damaged cells show cracks, chips (they shrink, exposing fracture faces)
## and dents. Cell health lives on the server; peers receive broken cells and quantized
## damage for visuals.

var wall_id := 0
var size := Vector2.ONE
var thickness := 0.6
var color := Color.WHITE
var anchors: Array = ["bottom"] # any of "bottom", "top", "left", "right"
var material := "plaster"
var matdef: Dictionary
var max_hp := 100.0

var cells: Array[PackedVector2Array] = [] # convex cell polygons (collision, fragments)
var outlines: Array[PackedVector2Array] = [] # jagged polygons (visuals)
var centers := PackedVector2Array()
var areas := PackedFloat32Array()
var neighbors: Array[PackedInt32Array] = []
var damage := PackedFloat32Array() # 0..1, all peers (visual)
var broken_cells := PackedInt32Array()

var _hp := PackedFloat32Array() # server
var _alive := PackedByteArray()
var _anchored := PackedByteArray()
var _bodies: Array[StaticBody3D] = []
var _mesh: MeshInstance3D
var _dirty := false
var _radius := 0.6


func setup(id: int, p_size: Vector2, p_thickness: float, p_color: Color, p_anchors: Array, p_material: String, hp_scale := 1.0) -> void:
	wall_id = id
	size = p_size
	thickness = p_thickness
	color = p_color
	anchors = p_anchors
	material = p_material
	matdef = Fracture.mat(material)
	max_hp = matdef.hp * hp_scale
	name = "D%d" % id
	var cs: Vector2 = matdef.cell
	_radius = maxf(cs.x, cs.y) * 0.75
	var v := Fracture.voronoi(size.x, size.y, matdef, id * 7919 + 101)
	cells = v.polys
	neighbors = v.neighbors
	var count := cells.size()
	_hp.resize(count)
	_alive.resize(count)
	_anchored.resize(count)
	damage.resize(count)
	for i in count:
		var poly := cells[i]
		outlines.append(Fracture.jagged(poly, size.x, size.y, matdef.jag))
		centers.append(Fracture.centroid(poly))
		areas.append(Fracture.area(poly))
		_hp[i] = max_hp
		_alive[i] = 1
		_anchored[i] = 1 if _touches_anchor(poly) else 0
		var body := StaticBody3D.new()
		body.collision_layer = Game.L_WORLD
		body.collision_mask = 0
		body.set_meta("destructible", self)
		body.set_meta("cell", i)
		var cs3 := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = Fracture.prism_points(poly, thickness)
		cs3.shape = shape
		body.add_child(cs3)
		add_child(body)
		_bodies.append(body)
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_rebuild_mesh()


func _touches_anchor(poly: PackedVector2Array) -> bool:
	var e := 0.003
	for p in poly:
		for a in anchors:
			match a:
				"bottom":
					if absf(p.y + size.y * 0.5) < e:
						return true
				"top":
					if absf(p.y - size.y * 0.5) < e:
						return true
				"left":
					if absf(p.x + size.x * 0.5) < e:
						return true
				"right":
					if absf(p.x - size.x * 0.5) < e:
						return true
	return false


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild_mesh()


func _rebuild_mesh() -> void:
	var mb := Fracture.MeshBuilder.new()
	var t := thickness * 0.5
	for i in cells.size():
		if _alive[i] == 0:
			continue
		var d := damage[i]
		var poly := outlines[i]
		if d > 0.45:
			# Chipped: the cell shrinks a little, revealing fracture faces around it.
			var k := 1.0 - (d - 0.45) * 0.22
			var c := centers[i]
			var shrunk := PackedVector2Array()
			for p in poly:
				shrunk.append(c + (p - c) * k)
			poly = shrunk
		var dent := d * d * 0.12 * thickness
		mb.add_prism(poly, t - dent, -t + dent * 0.6, Color(d, 0, 0, 1))
	_mesh.mesh = mb.commit(Mats.slab(color, material), Mats.slab(color, material, true))


# --- Queries ------------------------------------------------------------------------

func to_local2(world_point: Vector3) -> Vector3:
	return global_transform.affine_inverse() * world_point


func cell_world(i: int) -> Vector3:
	return global_transform * Vector3(centers[i].x, centers[i].y, 0.0)


func is_alive(i: int) -> bool:
	return i >= 0 and i < _alive.size() and _alive[i] == 1


func cell_body(i: int) -> StaticBody3D:
	return _bodies[i] if is_alive(i) else null


func _distance(local: Vector3, i: int) -> float:
	var d2 := Vector2(local.x, local.y).distance_to(centers[i])
	var dz := maxf(absf(local.z) - thickness * 0.5, 0.0)
	return sqrt(d2 * d2 + dz * dz)


## Alive cells whose centers lie within `radius` (+ a cell radius) of a world point.
func cells_near(world_point: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var local := to_local2(world_point)
	for i in cells.size():
		if _alive[i] == 1 and _distance(local, i) <= radius + _radius:
			out.append(i)
	return out


# --- Damage (server) ------------------------------------------------------------------

## Applies damage around a point. `sharp` shapes the profile: low = concentrated punch,
## high = flat (whole radius breaks evenly). Cells just outside the radius take a little
## damage so cracks spread around holes. Returns {"broken", "damaged"} cell lists.
func apply_damage(world_point: Vector3, radius: float, amount: float, sharp := 2.0) -> Dictionary:
	var broken := PackedInt32Array()
	var damaged := PackedInt32Array()
	var local := to_local2(world_point)
	for i in cells.size():
		if _alive[i] == 0:
			continue
		var dist := maxf(_distance(local, i) - _radius * 0.35, 0.0)
		var dmg := 0.0
		if dist < radius:
			dmg = amount * (1.0 - pow(dist / radius, sharp))
		elif dist < radius * 1.8:
			dmg = amount * 0.18 * (1.0 - (dist - radius) / (radius * 0.8))
		if dmg <= 0.0:
			continue
		_hp[i] -= dmg
		if _hp[i] <= 0.0:
			broken.append(i)
		else:
			damaged.append(i)
			damage[i] = 1.0 - _hp[i] / max_hp
	return {"broken": broken, "damaged": damaged}


## Adds visible strain to cells (used while unsupported sections creak).
func strain(list: PackedInt32Array, amount: float) -> PackedInt32Array:
	var changed := PackedInt32Array()
	for i in list:
		if _alive[i] == 1:
			_hp[i] = maxf(_hp[i] - max_hp * amount, max_hp * 0.05)
			damage[i] = 1.0 - _hp[i] / max_hp
			changed.append(i)
	return changed


func damage_bytes(list: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	for i in list:
		out.append(clampi(int(damage[i] * 255.0), 0, 255))
	return out


func all_damage_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	for i in cells.size():
		out.append(clampi(int(damage[i] * 255.0), 0, 255))
	return out


## Every peer: apply quantized damage for visuals.
func set_damage(list: PackedInt32Array, bytes: PackedByteArray) -> void:
	for k in mini(list.size(), bytes.size()):
		var i := list[k]
		if i >= 0 and i < damage.size():
			damage[i] = bytes[k] / 255.0
	_dirty = true


func set_all_damage(bytes: PackedByteArray) -> void:
	for i in mini(bytes.size(), damage.size()):
		damage[i] = bytes[i] / 255.0
	_dirty = true


## Connected groups of alive cells with no path to an anchored cell.
func unsupported_islands() -> Array[PackedInt32Array]:
	var supported := PackedByteArray()
	supported.resize(cells.size())
	var stack: Array[int] = []
	for i in cells.size():
		if _alive[i] == 1 and _anchored[i] == 1:
			supported[i] = 1
			stack.append(i)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for j in neighbors[i]:
			if _alive[j] == 1 and supported[j] == 0:
				supported[j] = 1
				stack.append(j)
	var islands: Array[PackedInt32Array] = []
	var seen := supported.duplicate()
	for i in cells.size():
		if _alive[i] == 0 or seen[i] == 1:
			continue
		var isl := PackedInt32Array()
		stack.append(i)
		seen[i] = 1
		while not stack.is_empty():
			var c: int = stack.pop_back()
			isl.append(c)
			for j in neighbors[c]:
				if _alive[j] == 1 and seen[j] == 0:
					seen[j] = 1
					stack.append(j)
		islands.append(isl)
	return islands


## Cells of an island that border a hole (where crumbling starts).
func edge_cells(island: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in island:
		for j in neighbors[i]:
			if _alive[j] == 0:
				out.append(i)
				break
	return out if not out.is_empty() else island


func island_center(island: PackedInt32Array) -> Vector2:
	var c := Vector2.ZERO
	var total := 0.0
	for i in island:
		c += centers[i] * areas[i]
		total += areas[i]
	return c / maxf(total, 0.0001)


## Every peer: removes cells visually and physically.
func remove_cells(list: PackedInt32Array) -> void:
	for i in list:
		if not is_alive(i):
			continue
		_alive[i] = 0
		var b := _bodies[i]
		if is_instance_valid(b):
			b.collision_layer = 0
			b.queue_free()
		broken_cells.append(i)
	_dirty = true
