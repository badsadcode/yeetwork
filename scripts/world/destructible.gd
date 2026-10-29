class_name Destructible
extends Node3D
## A slab (wall, floor or bridge) made of a grid of breakable cells.
## The local grid lies in the XY plane with thickness along Z. Every peer builds the same
## slabs in the same order, so `wall_id` + cell index identifies a cell on the network.
## Cell health lives on the server; peers only learn which cells broke.

var wall_id := 0
var nx := 1
var ny := 1
var cell := Vector2(1, 1)
var thickness := 0.6
var color := Color.WHITE
var anchors: Array = ["bottom"] # any of "bottom", "top", "left", "right"
var cell_hp := 100.0

var _hp := PackedFloat32Array()
var _alive := PackedByteArray()
var _bodies: Array[StaticBody3D] = []
var _mm: MultiMesh
var broken_cells := PackedInt32Array()


func setup(id: int, p_nx: int, p_ny: int, p_cell: Vector2, p_thickness: float, p_color: Color, p_anchors: Array, hp := 100.0) -> void:
	wall_id = id
	nx = p_nx
	ny = p_ny
	cell = p_cell
	thickness = p_thickness
	color = p_color
	anchors = p_anchors
	cell_hp = hp
	name = "D%d" % id
	_build()


func _build() -> void:
	var count := nx * ny
	_hp.resize(count)
	_alive.resize(count)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(cell.x * 0.985, cell.y * 0.985, thickness)
	_mm.mesh = bm
	_mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = Mats.world(color, 0.6)
	add_child(mmi)
	var shape := BoxShape3D.new()
	shape.size = Vector3(cell.x, cell.y, thickness)
	for i in count:
		_hp[i] = cell_hp
		_alive[i] = 1
		var local := cell_local(i)
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, local))
		var body := StaticBody3D.new()
		body.collision_layer = Game.L_WORLD
		body.collision_mask = 0
		body.position = local
		body.set_meta("destructible", self)
		body.set_meta("cell", i)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		_bodies.append(body)


func cell_local(i: int) -> Vector3:
	var ix := i % nx
	var iy := i / nx
	return Vector3((ix + 0.5) * cell.x - nx * cell.x * 0.5, (iy + 0.5) * cell.y - ny * cell.y * 0.5, 0.0)


func cell_world(i: int) -> Vector3:
	return global_transform * cell_local(i)


func cell_world_size() -> Vector3:
	return Vector3(cell.x, cell.y, thickness)


func is_alive(i: int) -> bool:
	return i >= 0 and i < _alive.size() and _alive[i] == 1


func cell_body(i: int) -> StaticBody3D:
	return _bodies[i] if is_alive(i) else null


## Cells (alive) whose centers lie within `radius` of a world point.
func cells_near(world_point: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var local := global_transform.affine_inverse() * world_point
	var reach := radius + maxf(cell.x, cell.y) * 0.5
	for i in _alive.size():
		if _alive[i] == 1 and cell_local(i).distance_to(local) <= reach:
			out.append(i)
	return out


## Server only: applies damage around a point and returns every cell that should break,
## including cells left hanging with no path to an anchored edge.
func apply_damage(world_point: Vector3, radius: float, amount: float) -> PackedInt32Array:
	var broken := PackedInt32Array()
	var local := global_transform.affine_inverse() * world_point
	var reach := radius + maxf(cell.x, cell.y) * 0.5
	for i in _alive.size():
		if _alive[i] == 0:
			continue
		var d := cell_local(i).distance_to(local)
		if d > reach:
			continue
		var falloff := clampf(1.0 - d / reach, 0.25, 1.0)
		_hp[i] -= amount * falloff
		if _hp[i] <= 0.0:
			broken.append(i)
	if broken.is_empty():
		return broken
	# Temporarily mark broken, then find unsupported islands.
	for i in broken:
		_alive[i] = 0
	var supported := _supported_cells()
	for i in _alive.size():
		if _alive[i] == 1 and not supported[i]:
			broken.append(i)
	for i in broken:
		_alive[i] = 1 # remove_cells() does the real removal on every peer
	return broken


func _is_anchor(i: int) -> bool:
	var ix := i % nx
	var iy := i / nx
	for a in anchors:
		match a:
			"bottom":
				if iy == 0:
					return true
			"top":
				if iy == ny - 1:
					return true
			"left":
				if ix == 0:
					return true
			"right":
				if ix == nx - 1:
					return true
	return false


func _supported_cells() -> Array:
	var supported := []
	supported.resize(_alive.size())
	supported.fill(false)
	var stack: Array[int] = []
	for i in _alive.size():
		if _alive[i] == 1 and _is_anchor(i):
			supported[i] = true
			stack.append(i)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var ix := i % nx
		var iy := i / nx
		for n in [[ix - 1, iy], [ix + 1, iy], [ix, iy - 1], [ix, iy + 1]]:
			if n[0] < 0 or n[0] >= nx or n[1] < 0 or n[1] >= ny:
				continue
			var j: int = n[1] * nx + n[0]
			if _alive[j] == 1 and not supported[j]:
				supported[j] = true
				stack.append(j)
	return supported


## Every peer: removes cells visually and physically.
func remove_cells(cells: PackedInt32Array) -> void:
	for i in cells:
		if not is_alive(i):
			continue
		_alive[i] = 0
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), cell_local(i)))
		var b := _bodies[i]
		if is_instance_valid(b):
			b.collision_layer = 0
			b.queue_free()
		broken_cells.append(i)
