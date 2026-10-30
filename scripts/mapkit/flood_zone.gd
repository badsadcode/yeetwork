@tool
class_name FloodZone
extends PuzzleNode
## Flood water for puzzles: a 2.5D water grid over the box (Size, standing on this node; keep
## it unrotated). Every 0.5 m column holds a water depth; water runs toward lower water
## ("virtual pipes" shallow water, the model from GangTheGame), so it fills rooms, pours
## through holes smashed in walls, piles up behind closed doors and drains away. The floor
## under each column is what the level's collision says (rescanned all the time, so doors
## and broken walls count). Where the floor falls away below the box (a pit), water pours
## out and is gone. Valves (FloodValve) pour water in, drains (FloodDrain) take it out, and a
## FloatSwitch turns on when the water reaches it. Yeets swim in it, wood floats, the current
## carries things along and fire goes out. The host runs it and sends the changes to everyone.
## Limits: one floor per column (no water on two levels of the same box), no water in the air.

@export var size := Vector3(16, 6, 16):
	set(v):
		size = v
		_rebuild()
## Water already there at the start, up to this height above the node (0: dry).
@export_range(0.0, 20.0, 0.1) var start_level := 0.0:
	set(v):
		start_level = v
		_rebuild()

const CELL := 0.5
const G := 15.0 # a bit livelier than real water
const DAMP := 0.995
const DRY := 0.0005
const WET := 0.01
const MAX_SPEED := 6.0
const CHUNK := 16
const SEND_EVERY := 0.1
const RENDER_EVERY := 0.05
const HOLE := -1.0e9

var nx := 0
var nz := 0
var depth := PackedFloat32Array()
var floor_h := PackedFloat32Array()
var vx := PackedFloat32Array() # current (m/s), host computed, sent to everyone
var vz := PackedFloat32Array()
var spilled := 0.0 # m³ that poured out into pits
var _fl := PackedFloat32Array()
var _fr := PackedFloat32Array()
var _fu := PackedFloat32Array()
var _fd := PackedFloat32Array()
var _sent := PackedFloat32Array()
var _shown := PackedFloat32Array()
var _tex_data := PackedFloat32Array()
var _tex: ImageTexture
var _liquid: Liquid
var _wet := Rect2i() # cells holding water (host: stepped area)
var _dirty := Rect2i() # host: cells changed since the last send
var _render := Rect2i() # cells the picture has to keep up with
var _ready_grid := false
var _scan_row := 0
var _send_t := 0.0
var _render_t := 0.0
var _changed := false
var _sources: Array = [] # host: [position, radius, m³ this step] (valves +, drains -)
var _preview: Node3D
var _pending: Array = [] # chunks that arrived before the grid was set up


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
	_preview = Node3D.new()
	add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.6, 1.0, 0.08)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview.add_child(PuzzleNode.box_mesh(size, m, Vector3(0, size.y * 0.5, 0)))
	if start_level > 0.0:
		var w := StandardMaterial3D.new()
		w.albedo_color = Color(0.2, 0.5, 0.9, 0.35)
		w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		w.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.02, size.z), w, Vector3(0, start_level, 0)))


# --- Queries (every peer) ------------------------------------------------------------------

func cell_of(p: Vector3) -> Vector2i:
	var o := global_position
	return Vector2i(floori((p.x - o.x + size.x * 0.5) / CELL), floori((p.z - o.z + size.z * 0.5) / CELL))


func cell_center(x: int, z: int) -> Vector2:
	return Vector2(global_position.x - size.x * 0.5 + (x + 0.5) * CELL, global_position.z - size.z * 0.5 + (z + 0.5) * CELL)


func contains(p: Vector3) -> bool:
	var c := cell_of(p)
	return _ready_grid and c.x >= 0 and c.y >= 0 and c.x < nx and c.y < nz


func depth_at(p: Vector3) -> float:
	if not contains(p):
		return 0.0
	var c := cell_of(p)
	return depth[c.y * nx + c.x]


## World height of the water surface over p, or -1e6 where it's dry.
func surface_at(p: Vector3) -> float:
	if not contains(p):
		return -1.0e6
	var c := cell_of(p)
	var i := c.y * nx + c.x
	return floor_h[i] + depth[i] if depth[i] > WET else -1.0e6


## How fast the water runs at p (horizontal, m/s).
func current_at(p: Vector3) -> Vector3:
	if not contains(p):
		return Vector3.ZERO
	var c := cell_of(p)
	var i := c.y * nx + c.x
	return Vector3(vx[i], 0, vz[i]) if depth[i] > WET else Vector3.ZERO


func volume() -> float:
	var s := 0.0
	for d in depth:
		s += d
	return s * CELL * CELL


## Inside the zone's box (a little above and below too).
func in_box(p: Vector3) -> bool:
	var l := p - global_position
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 and l.y > -2.0 and l.y < size.y + 2.0


## The flood zone around p, if any.
static func at(w: Node, p: Vector3) -> FloodZone:
	if w == null or w.arena == null:
		return null
	for n in w.arena.puzzle:
		if n is FloodZone and n.in_box(p):
			return n
	return null


# --- Host: water in and out -----------------------------------------------------------------

## Pours `volume` m³ (negative: takes it) over the columns within `radius` of p, this step.
func pour(p: Vector3, radius: float, amount: float) -> void:
	_sources.append([p, radius, amount])


func _apply_source(p: Vector3, radius: float, amount: float) -> void:
	var c := cell_of(p)
	var r := ceili(radius / CELL)
	var cells: Array[int] = []
	for z in range(maxi(c.y - r, 0), mini(c.y + r, nz - 1) + 1):
		for x in range(maxi(c.x - r, 0), mini(c.x + r, nx - 1) + 1):
			if cell_center(x, z).distance_to(Vector2(p.x, p.z)) <= maxf(radius, CELL * 0.75) and floor_h[z * nx + x] > HOLE:
				if amount > 0.0 or depth[z * nx + x] > DRY:
					cells.append(z * nx + x)
	if cells.is_empty():
		return
	var each := amount / cells.size() / (CELL * CELL)
	for i in cells:
		depth[i] = maxf(depth[i] + each, 0.0)
		_grow(i % nx, i / nx)


func _grow(x: int, z: int) -> void:
	var r := Rect2i(x, z, 1, 1)
	_wet = r if _wet.size == Vector2i.ZERO else _wet.merge(r)


# --- Setup ----------------------------------------------------------------------------------

func _setup() -> void:
	nx = maxi(ceili(size.x / CELL), 1)
	nz = maxi(ceili(size.z / CELL), 1)
	var n := nx * nz
	# (packed arrays are values: each one resized by name)
	depth.resize(n)
	floor_h.resize(n)
	vx.resize(n)
	vz.resize(n)
	_fl.resize(n)
	_fr.resize(n)
	_fu.resize(n)
	_fd.resize(n)
	_sent.resize(n)
	_shown.resize(n)
	_tex_data.resize(n * 2)
	for z in nz:
		_scan(z)
	if world.is_server and start_level > 0.0:
		var level := global_position.y + start_level
		for i in n:
			if floor_h[i] > HOLE and floor_h[i] < level:
				depth[i] = level - floor_h[i]
				_grow(i % nx, i / nx)
	_render = Rect2i(0, 0, nx, nz)
	_changed = true
	# The surface: Yeetwork's own water, bent to the flood's heights by a texture.
	_tex = ImageTexture.create_from_image(Image.create_empty(nx, nz, false, Image.FORMAT_RGF))
	var rect := flood_rect()
	_liquid = Liquid.create("water", Vector3(rect.x + rect.z * 0.5, global_position.y + size.y, rect.y + rect.w * 0.5), Vector3(rect.z, size.y, rect.w))
	_liquid.flood = self
	world.arena.add_child(_liquid)
	_ready_grid = true
	for p in _pending:
		decode_chunk(p[0], p[1])
	_pending.clear()
	_update_texture()


## The floor under one row of columns: the highest solid thing in the box (a wall's top,
## a door), or HOLE where nothing is (a pit below the box).
func _scan(z: int) -> void:
	var space := get_world_3d().direct_space_state
	var top := global_position.y + size.y
	var bottom := global_position.y - 2.0
	for x in nx:
		var c := cell_center(x, z)
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, top, c.y), Vector3(c.x, bottom, c.y), Game.L_WORLD)
		q.hit_from_inside = true
		var hit := space.intersect_ray(q)
		var h: float = hit.position.y if not hit.is_empty() else HOLE
		var i := z * nx + x
		if absf(h - floor_h[i]) > 0.01:
			floor_h[i] = h
			_changed = true


# --- Running --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null:
		return
	if not _ready_grid:
		_setup()
		return
	# Doors move and walls break: a few rows of floor are looked at again every frame.
	for k in 3:
		_scan(_scan_row)
		_scan_row = (_scan_row + 1) % nz
	if world.is_server:
		_step(minf(delta, 1.0 / 30.0))
		_send_t += delta
		if _send_t >= SEND_EVERY:
			_send_t = 0.0
			_send()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _ready_grid:
		return
	_render_t += delta
	if _render_t >= RENDER_EVERY and _changed:
		_render_t = 0.0
		_update_texture()


func _step(dt: float) -> void:
	for s in _sources:
		_apply_source(s[0], s[1], s[2])
	_sources.clear()
	if _wet.size == Vector2i.ZERO:
		return
	var x0 := maxi(_wet.position.x - 1, 0)
	var z0 := maxi(_wet.position.y - 1, 0)
	var x1 := mini(_wet.end.x, nx - 1)
	var z1 := mini(_wet.end.y, nz - 1)
	var area := CELL * CELL
	var pipe := dt * G * CELL
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * nx + x
			var d := depth[i]
			if d <= DRY or floor_h[i] <= HOLE:
				_fl[i] = 0.0
				_fr[i] = 0.0
				_fu[i] = 0.0
				_fd[i] = 0.0
				continue
			var h := floor_h[i] + d
			var l := 0.0 if x == 0 else maxf(0.0, _fl[i] * DAMP + pipe * (h - _surf(i - 1)))
			var r := 0.0 if x == nx - 1 else maxf(0.0, _fr[i] * DAMP + pipe * (h - _surf(i + 1)))
			var u := 0.0 if z == 0 else maxf(0.0, _fu[i] * DAMP + pipe * (h - _surf(i - nx)))
			var w := 0.0 if z == nz - 1 else maxf(0.0, _fd[i] * DAMP + pipe * (h - _surf(i + nx)))
			# Never more out than there is.
			var total := (l + r + u + w) * dt
			var k := d * area / total if total > d * area else 1.0
			_fl[i] = l * k
			_fr[i] = r * k
			_fu[i] = u * k
			_fd[i] = w * k
	var wet := Rect2i()
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := z * nx + x
			var inflow := (_fr[i - 1] if x > 0 else 0.0) + (_fl[i + 1] if x < nx - 1 else 0.0) \
					+ (_fd[i - nx] if z > 0 else 0.0) + (_fu[i + nx] if z < nz - 1 else 0.0)
			var outflow := _fl[i] + _fr[i] + _fu[i] + _fd[i]
			var d := maxf(depth[i] + (inflow - outflow) * dt / area, 0.0)
			if floor_h[i] <= HOLE:
				spilled += d * area # poured into the pit
				d = 0.0
			depth[i] = d
			if d > DRY:
				var r := Rect2i(x, z, 1, 1)
				wet = r if wet.size == Vector2i.ZERO else wet.merge(r)
			# The current: what passes through the cell over its cross-section.
			if d > WET:
				var from_l := _fr[i - 1] if x > 0 else 0.0
				var from_r := _fl[i + 1] if x < nx - 1 else 0.0
				var from_u := _fd[i - nx] if z > 0 else 0.0
				var from_d := _fu[i + nx] if z < nz - 1 else 0.0
				var cvx := 0.5 * ((from_l - _fl[i]) + (_fr[i] - from_r)) / (d * CELL)
				var cvz := 0.5 * ((from_u - _fu[i]) + (_fd[i] - from_d)) / (d * CELL)
				var len := sqrt(cvx * cvx + cvz * cvz)
				var lim := minf(1.0, MAX_SPEED / len) if len > 0.0 else 1.0
				vx[i] = cvx * lim
				vz[i] = cvz * lim
			else:
				vx[i] = 0.0
				vz[i] = 0.0
	var stepped := Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)
	_dirty = stepped if _dirty.size == Vector2i.ZERO else _dirty.merge(stepped)
	_wet = wet
	_changed = true


func _surf(i: int) -> float:
	return floor_h[i] + depth[i]


# --- Network ----------------------------------------------------------------------------------

func _chunks_x() -> int:
	return ceili(nx / float(CHUNK))


func _send() -> void:
	if _dirty.size == Vector2i.ZERO:
		return
	var ids := PackedInt32Array()
	var blobs: Array[PackedByteArray] = []
	var cx0 := _dirty.position.x / CHUNK
	var cz0 := _dirty.position.y / CHUNK
	var cx1 := (_dirty.end.x - 1) / CHUNK
	var cz1 := (_dirty.end.y - 1) / CHUNK
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var id := cz * _chunks_x() + cx
			if _chunk_changed(id):
				ids.append(id)
				blobs.append(encode_chunk(id))
	_dirty = Rect2i()
	if not ids.is_empty():
		world.server_flood(puzzle_index, ids, blobs)


func _chunk_rect(id: int) -> Rect2i:
	var cx := id % _chunks_x()
	var cz := id / _chunks_x()
	return Rect2i(cx * CHUNK, cz * CHUNK, mini(CHUNK, nx - cx * CHUNK), mini(CHUNK, nz - cz * CHUNK))


func _chunk_changed(id: int) -> bool:
	var r := _chunk_rect(id)
	var changed := false
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := z * nx + x
			if absf(depth[i] - _sent[i]) > 0.003:
				changed = true
				break
		if changed:
			break
	if changed:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_sent[z * nx + x] = depth[z * nx + x]
	return changed


## A chunk's depths (mm) and current (5 cm/s steps), 4 bytes a column, compressed.
func encode_chunk(id: int) -> PackedByteArray:
	var r := _chunk_rect(id)
	var raw := PackedByteArray()
	raw.resize(r.size.x * r.size.y * 4)
	var o := 0
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := z * nx + x
			raw.encode_u16(o, clampi(roundi(depth[i] * 1000.0), 0, 65535))
			raw.encode_s8(o + 2, clampi(roundi(vx[i] * 20.0), -127, 127))
			raw.encode_s8(o + 3, clampi(roundi(vz[i] * 20.0), -127, 127))
			o += 4
	return raw.compress(FileAccess.COMPRESSION_ZSTD)


func decode_chunk(id: int, data: PackedByteArray) -> void:
	if not _ready_grid:
		_pending.append([id, data])
		return
	var r := _chunk_rect(id)
	var raw := data.decompress(r.size.x * r.size.y * 4, FileAccess.COMPRESSION_ZSTD)
	var o := 0
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if o + 3 >= raw.size():
				return
			var i := z * nx + x
			depth[i] = raw.decode_u16(o) / 1000.0
			vx[i] = raw.decode_s8(o + 2) / 20.0
			vz[i] = raw.decode_s8(o + 3) / 20.0
			o += 4
	_changed = true


## Every chunk holding water, for players joining a match in progress.
func full_state() -> Array:
	var ids := PackedInt32Array()
	var blobs: Array[PackedByteArray] = []
	if not _ready_grid:
		return [ids, blobs]
	for id in _chunks_x() * ceili(nz / float(CHUNK)):
		var r := _chunk_rect(id)
		var any := false
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if depth[z * nx + x] > DRY:
					any = true
		if any:
			ids.append(id)
			blobs.append(encode_chunk(id))
	return [ids, blobs]


# --- The picture -----------------------------------------------------------------------------

## The surface texture the water shader reads: R = surface height, G = depth. Shown depths
## ease toward the real ones so 10 updates a second still look smooth.
func _update_texture() -> void:
	var still := true
	var top := global_position.y + size.y
	for z in nz:
		for x in nx:
			var i := z * nx + x
			var target := depth[i]
			var s := _shown[i]
			if absf(target - s) > 0.002:
				s = lerpf(s, target, 0.45)
				_shown[i] = s
				still = false
			elif s != target:
				_shown[i] = target
				still = false
	for z in nz:
		for x in nx:
			var i := z * nx + x
			var f := floor_h[i]
			var s := _shown[i]
			var h: float
			if s > WET:
				h = f + s
			else:
				# Dry: just under the floor, or under the neighbouring water against a wall.
				var nb := -1.0e6
				if x > 0 and _shown[i - 1] > WET:
					nb = maxf(nb, floor_h[i - 1] + _shown[i - 1])
				if x < nx - 1 and _shown[i + 1] > WET:
					nb = maxf(nb, floor_h[i + 1] + _shown[i + 1])
				if z > 0 and _shown[i - nx] > WET:
					nb = maxf(nb, floor_h[i - nx] + _shown[i - nx])
				if z < nz - 1 and _shown[i + nx] > WET:
					nb = maxf(nb, floor_h[i + nx] + _shown[i + nx])
				h = (minf(f, nb) if nb > -1.0e5 else f) - 0.06
				if f <= HOLE:
					h = global_position.y - 2.0
			_tex_data[i * 2] = minf(h, top)
			_tex_data[i * 2 + 1] = s
	_tex.update(Image.create_from_data(nx, nz, false, Image.FORMAT_RGF, _tex_data.to_byte_array()))
	_changed = not still


func flood_texture() -> Texture2D:
	return _tex


## Min x, min z, size x, size z of the grid (for the shader).
func flood_rect() -> Vector4:
	return Vector4(global_position.x - size.x * 0.5, global_position.z - size.z * 0.5, nx * CELL, nz * CELL)


func problems() -> Array[String]:
	var out := super.problems()
	if size.x * size.z > 40.0 * 40.0:
		out.append("%s: the flood zone is big (%.0f x %.0f m); keep it under 40 x 40 for the Steam Deck." % [name, size.x, size.z])
	if not rotation.is_zero_approx():
		out.append("%s: flood zones can't be rotated." % name)
	return out
