class_name BotField
extends RefCounted
## MegaYeet's map for the bots, one for all of them: every cell's distance to the monster a Yeet
## would best go for (near the Heart counts double), by a Yeet's rules, not a monster's: it can
## hop up about a metre and a bit, drop off anything (it won't climb a wall), ride the jump
## pads (Arena.jump_links: stepping on one launches you, so its only way on is where it
## throws you), go round big props, not through a standing gate. Made on a worker thread every
## second or so from the Horde's grid (update, poll); a bot just steps downhill (next_point).
## No path search per bot: eleven bots cost what one does.

const JUMP := 1.3
const DROP := 9.0
const PAD_COST := 30
const INF_COST := 1 << 30

var dist := PackedInt32Array() # (the latest finished map; empty until the first)
var pads := {} # cell -> landing cell (every cell a pad covers)
var _task := -1
var _job: Job


## Starts a new map on a worker thread (unless one's still being made). `sources`: monster
## cells and their head start (cost: how far they are from the Heart, so nearer ones pull
## harder); `avoid`: cells big props stand in.
func update(field: FlowField, links: Array, sources: Dictionary, avoid: Dictionary) -> void:
	if _task >= 0 or field == null:
		return
	pads = {}
	for l: Array in links:
		var b := standable(field, l[1])
		if b < 0:
			continue
		var pad: Vector3 = l[0]
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var c := field.cell_of(pad + Vector3(dx, 0, dz) * 0.8)
				if c >= 0:
					pads[c] = b
	_job = Job.new(field.nx, field.nz, field.walk.duplicate(), field.height.duplicate(), sources, avoid, pads.duplicate())
	_task = WorkerThreadPool.add_task(_job.run)


## Takes in a finished map; true when it did.
func poll() -> bool:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	dist = _job.dist
	_job = null
	return true


## (the game's quitting: let a map in progress finish)
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Where a bot at `pos` heads next (a point a few steps down the map, or across a pad's
## middle when that's the way); INF: no monster it can get to from here.
func next_point(field: FlowField, pos: Vector3, steps := 3) -> Vector3:
	if dist.size() != field.nx * field.nz:
		return Vector3.INF
	var i := standable(field, pos)
	if i < 0 or dist[i] >= INF_COST:
		return Vector3.INF
	var at := i
	for k in steps: # (a little way down the map, not past a step up or a pad)
		var j := _downhill(field, at)
		if j < 0:
			break
		if pads.has(j) and not pads.has(at):
			var c := field.center(j)
			var pad := Vector3(c.x, field.height[j], c.y)
			var across := Vector3(pad.x - pos.x, 0, pad.z - pos.z)
			return pad + (across.normalized() if across.length() > 0.05 else Vector3.ZERO) * 1.8
		at = j
		if field.height[j] > pos.y + 0.45:
			break
	if at == i:
		return Vector3.INF if dist[i] > 0 else pos
	var c := field.center(at)
	return Vector3(c.x, field.height[at], c.y)


## The bot's next step is up onto something (a hop).
func step_up(field: FlowField, pos: Vector3) -> bool:
	var i := standable(field, pos)
	if i < 0 or dist.size() != field.nx * field.nz:
		return false
	var j := _downhill(field, i)
	return j >= 0 and not pads.has(j) and field.height[j] > pos.y + 0.45


## The way from `from` down the map (world points), for checks: where a bot would go.
func trace(field: FlowField, from: Vector3, max_steps := 400) -> PackedVector3Array:
	var out := PackedVector3Array()
	var i := standable(field, from)
	while i >= 0 and out.size() < max_steps and dist.size() == field.nx * field.nz and dist[i] < INF_COST:
		var c := field.center(i)
		out.append(Vector3(c.x, field.height[i], c.y))
		if dist[i] == 0:
			break
		i = pads[i] if pads.has(i) else _downhill(field, i)
	return out


## The neighbour a Yeet can step to with the least distance left (lower than here).
func _downhill(field: FlowField, i: int) -> int:
	var nx := field.nx
	var x := i % nx
	var z := i / nx
	var best := dist[i]
	var out := -1
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var ox: int = x + dx
			var oz: int = z + dz
			if ox < 0 or oz < 0 or ox >= nx or oz >= field.nz:
				continue
			var j := oz * nx + ox
			if dist[j] < best and can_step(field.walk, field.height, nx, i, j, dx, dz):
				best = dist[j]
				out = j
	return out


## The cell at p, or the nearest one round it a Yeet can stand on (not above it, not far below:
## mid-jump, or up on a prop, counts as the ground under it).
static func standable(field: FlowField, p: Vector3) -> int:
	var c := field.cell_of(p)
	if c >= 0 and field.walk[c] == 1 and _under(field.height[c], p.y):
		return c
	var best := -1
	var best_d := INF
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var q := field.cell_of(p + Vector3(dx, 0, dz))
			if q < 0 or field.walk[q] != 1 or not _under(field.height[q], p.y):
				continue
			var d := Vector2(dx, dz).length()
			if d < best_d:
				best_d = d
				best = q
	return best


static func _under(ground: float, y: float) -> bool:
	return ground <= y + 1.0 and y - ground < 8.0


## Can a Yeet step from cell a to its neighbour b (dx, dz: the way from a to b)?
static func can_step(w: PackedByteArray, h: PackedFloat32Array, cols: int, a: int, b: int, dx: int, dz: int) -> bool:
	if w[b] != 1:
		return false
	var up := h[b] - h[a]
	if up > JUMP or up < -DROP:
		return false
	if dx != 0 and dz != 0: # (not squeezing between two blocked corners)
		var ax := a % cols
		var az := a / cols
		if w[az * cols + ax + dx] != 1 or w[(az + dz) * cols + ax] != 1:
			return false
	return true


## The map itself (Dijkstra out from the monsters, walking backwards), on its own copies.
class Job:
	var nx := 0
	var nz := 0
	var walk: PackedByteArray
	var height: PackedFloat32Array
	var sources: Dictionary
	var avoid: Dictionary
	var pads: Dictionary
	var dist := PackedInt32Array()

	func _init(p_nx: int, p_nz: int, w: PackedByteArray, h: PackedFloat32Array, src: Dictionary, av: Dictionary, pd: Dictionary) -> void:
		nx = p_nx
		nz = p_nz
		walk = w
		height = h
		sources = src
		avoid = av
		pads = pd

	func run() -> void:
		var n := nx * nz
		dist.resize(n)
		dist.fill(INF_COST)
		var heap := []
		for c in sources:
			if dist[c] > int(sources[c]):
				dist[c] = int(sources[c])
				FlowField._push(heap, [dist[c], c])
		var launched := {} # landing cell -> [pad cells]
		for p in pads:
			var l: int = pads[p]
			if not launched.has(l):
				launched[l] = []
			launched[l].append(p)
		while not heap.is_empty():
			var top: Array = FlowField._pop(heap)
			var d: int = top[0]
			var i: int = top[1]
			if d > dist[i]:
				continue
			var x := i % nx
			var z := i / nx
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dz == 0:
						continue
					var ox: int = x + dx
					var oz: int = z + dz
					if ox < 0 or oz < 0 or ox >= nx or oz >= nz:
						continue
					var j := oz * nx + ox
					# (from j a Yeet steps to i; a pad's cells lead only where it throws you)
					if pads.has(j) or avoid.has(j) or not BotField.can_step(walk, height, nx, j, i, -dx, -dz):
						continue
					var cost := d + (14 if dx != 0 and dz != 0 else 10) + (4 if height[i] - height[j] > FlowField.STEP_UP else 0)
					if cost < dist[j]:
						dist[j] = cost
						FlowField._push(heap, [cost, j])
			for p: int in launched.get(i, []):
				var cost := d + PAD_COST
				if cost < dist[p]:
					dist[p] = cost
					FlowField._push(heap, [cost, p])
