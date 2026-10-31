class_name FlowField
extends RefCounted
## MegaYeet's map of the ways to the Heart, shared by every monster (server): a grid of
## 1 m cells over the map, each knowing its ground height, whether a monster fits there, and
## which way to step to get closer to the Heart. Built once from the world's collision;
## breakable walls (gates) count as passable but costly, so monsters go round by an open way
## if there is one, and otherwise batter the gate down (a gate cell is open again once its
## wall is gone there: refresh_gates()).

const CELL := 1.0
const STEP_UP := 0.55 # (what a monster can climb from one cell to the next)
const DROP := 8.0 # (what it will jump down: off a wall it was flung onto)
const GATE_COST := 120
const INF_COST := 1 << 30

var origin := Vector2.ZERO # world XZ of cell (0, 0)'s corner
var nx := 0
var nz := 0
var height := PackedFloat32Array() # ground (INF: none)
var walk := PackedByteArray() # 1 a monster fits, 2 a standing gate, 0 no
var dist := PackedInt32Array()
var toward := PackedVector2Array() # unit XZ step to the next cell (ZERO at the Heart)
var gate_wall := {} # cell -> Destructible (while it stands there)
var gate_cells := {} # every cell a gate has stood in (looked at again after a repair)
var targets := PackedInt32Array()
var _space: PhysicsDirectSpaceState3D
var _task := -1
var _again := false
var _solver: Solver
var _probe: PhysicsShapeQueryParameters3D


## Builds the grid over `bounds` (world XZ) between y_low and y_high, the Heart at `heart`.
func build(space: PhysicsDirectSpaceState3D, bounds: Rect2, y_low: float, y_high: float, heart: Vector3, heart_radius: float) -> void:
	_space = space
	origin = bounds.position
	nx = int(ceil(bounds.size.x / CELL))
	nz = int(ceil(bounds.size.y / CELL))
	var n := nx * nz
	height.resize(n)
	walk.resize(n)
	dist.resize(n)
	toward.resize(n)
	_probe = PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.1, 0.6)
	_probe.shape = box
	_probe.collision_mask = Game.L_WORLD
	for i in n:
		var c := center(i)
		# Every floor down this column (a ray from inside a wall goes on through it): the
		# lowest one a monster fits on is theirs (under a gate's lintel, the gate's own floor,
		# not the wall top over it), else the highest (a wall: blocked).
		var floors := []
		var from := y_high
		for k in 5:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(c.x, from, c.y), Vector3(c.x, y_low, c.y), Game.L_WORLD)
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				break
			if hit.normal.y >= 0.6:
				floors.append(hit.position.y)
			from = hit.position.y - 0.05
		height[i] = INF
		walk[i] = 0
		for k in range(floors.size() - 1, -1, -1):
			height[i] = floors[k]
			walk[i] = _fits(i)
			if walk[i] != 0:
				break
		if walk[i] == 0 and not floors.is_empty():
			height[i] = floors[0]
		if walk[i] == 0:
			continue
		var liq := Liquid.at(Vector3(c.x, height[i] + 0.1, c.y), 0.0)
		if liq and liq.kind in ["lava", "acid"]:
			walk[i] = 0 # (they don't walk into it: they can be thrown in)
	targets = PackedInt32Array()
	for i in n:
		if walk[i] == 1 and Vector2(heart.x, heart.z).distance_to(center(i)) <= heart_radius + 0.5 and absf(height[i] - heart.y) < 3.0:
			targets.append(i)
	if targets.is_empty(): # (the Heart on a pedestal: the walkable cells round it)
		for i in n:
			if walk[i] == 1 and Vector2(heart.x, heart.z).distance_to(center(i)) <= heart_radius + 3.0:
				targets.append(i)
	solve()
	if OS.get_cmdline_user_args().has("--trace"):
		var c := [0, 0, 0]
		var reached := 0
		for i in n:
			c[walk[i]] += 1
			if dist[i] < INF_COST:
				reached += 1
		print("FLOW cells blocked/open/gate %s, targets %d, reached %d, heart %s" % [c, targets.size(), reached, heart])


## 1 when a monster fits on cell i (nothing solid from knee to head height), 2 when what's in
## the way is a breakable wall (a gate), else 0.
func _fits(i: int) -> int:
	var c := center(i)
	_probe.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, height[i] + 0.4 + 0.55, c.y))
	var hits := _space.intersect_shape(_probe, 4)
	if hits.is_empty():
		gate_wall.erase(i)
		return 1
	for h in hits:
		var col: Object = h.collider
		if col and col.has_meta("destructible"):
			gate_wall[i] = col.get_meta("destructible")
			gate_cells[i] = true
			return 2
	return 0


## Distances to the Heart, and each cell's step toward it (now, on this thread).
func solve() -> void:
	var sv := Solver.new(nx, nz, walk.duplicate(), height.duplicate(), targets.duplicate())
	sv.run()
	dist = sv.dist
	toward = sv.toward


## The same on a worker thread (a gate's broken: a quarter of a second of work on a big map);
## the monsters follow the old ways until poll() takes the new ones in.
func solve_async() -> void:
	if _task >= 0:
		_again = true
		return
	_solver = Solver.new(nx, nz, walk.duplicate(), height.duplicate(), targets.duplicate())
	_task = WorkerThreadPool.add_task(_solver.run)


## Takes in a finished solve_async(); true when it did.
func poll() -> bool:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	dist = _solver.dist
	toward = _solver.toward
	_solver = null
	if _again:
		_again = false
		solve_async()
	return true


## (the game's quitting or the map's going: let a solve in progress finish first)
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Can a monster step from cell a to its neighbour b (dx, dz: the way from a to b)?
func _can_step(a: int, b: int, diagonal: bool, dx: int, dz: int) -> bool:
	return Solver.can_step(walk, height, nx, a, b, diagonal, dx, dz)


## Dijkstra over the cells, walking backwards from the Heart, on its own copies of the grid
## (so it can run on another thread).
class Solver:
	var nx := 0
	var nz := 0
	var walk: PackedByteArray
	var height: PackedFloat32Array
	var targets: PackedInt32Array
	var dist := PackedInt32Array()
	var toward := PackedVector2Array()

	func _init(p_nx: int, p_nz: int, w: PackedByteArray, h: PackedFloat32Array, t: PackedInt32Array) -> void:
		nx = p_nx
		nz = p_nz
		walk = w
		height = h
		targets = t

	func run() -> void:
		var n := nx * nz
		dist.resize(n)
		dist.fill(INF_COST)
		toward.resize(n)
		var heap := []
		for t in targets:
			dist[t] = 0
			heap.append([0, t])
		heap.sort()
		# (a binary heap of [cost, cell])
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
					if walk[j] == 0 or not can_step(walk, height, nx, j, i, dx != 0 and dz != 0, -dx, -dz):
						continue
					var cost := d + (14 if dx != 0 and dz != 0 else 10) + (GATE_COST if walk[j] == 2 or walk[i] == 2 else 0)
					if cost < dist[j]:
						dist[j] = cost
						FlowField._push(heap, [cost, j])
		for i in n:
			toward[i] = _best_step(i)

	func _best_step(i: int) -> Vector2:
		if dist[i] == 0 or dist[i] >= INF_COST:
			return Vector2.ZERO
		var x := i % nx
		var z := i / nx
		var best := dist[i]
		var out := Vector2.ZERO
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var ox: int = x + dx
				var oz: int = z + dz
				if (dx == 0 and dz == 0) or ox < 0 or oz < 0 or ox >= nx or oz >= nz:
					continue
				var j := oz * nx + ox
				if dist[j] < best and can_step(walk, height, nx, i, j, dx != 0 and dz != 0, dx, dz):
					best = dist[j]
					out = Vector2(dx, dz).normalized()
		return out

	static func can_step(w: PackedByteArray, h: PackedFloat32Array, cols: int, a: int, b: int, diagonal: bool, dx: int, dz: int) -> bool:
		if w[b] == 0 or w[a] == 0:
			return false
		var up := h[b] - h[a]
		if up > STEP_UP or up < -DROP:
			return false
		if diagonal: # (not squeezing between two blocked cells' corners)
			var ax := a % cols
			var az := a / cols
			if w[az * cols + ax + dx] == 0 or w[(az + dz) * cols + ax] == 0:
				return false
		return true


## Gate cells looked at again: open where their wall is gone, shut again where it's been
## rebuilt (a repair); true when any changed (solve them).
func refresh_gates() -> bool:
	var changed := false
	for i in gate_cells.keys():
		var now := _fits(i)
		if now != walk[i]:
			walk[i] = now
			changed = true
	return changed


func cell_of(p: Vector3) -> int:
	var x := int(floor((p.x - origin.x) / CELL))
	var z := int(floor((p.z - origin.y) / CELL))
	if x < 0 or z < 0 or x >= nx or z >= nz:
		return -1
	return z * nx + x


func center(i: int) -> Vector2:
	return origin + Vector2((i % nx) + 0.5, (i / nx) + 0.5) * CELL


func ground(p: Vector3) -> float:
	var i := cell_of(p)
	return height[i] if i >= 0 else INF


## The way to go from here (XZ, unit; ZERO: at the Heart, or nowhere to go).
func direction(p: Vector3) -> Vector2:
	var i := cell_of(p)
	return toward[i] if i >= 0 else Vector2.ZERO


func distance(p: Vector3) -> int:
	var i := cell_of(p)
	return dist[i] if i >= 0 else INF_COST


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var k := heap.size() - 1
	while k > 0:
		var parent := (k - 1) >> 1
		if heap[parent][0] <= item[0]:
			break
		heap[k] = heap[parent]
		k = parent
	heap[k] = item


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	var k := 0
	var n := heap.size()
	while true:
		var l := k * 2 + 1
		if l >= n:
			break
		var r := l + 1
		var c := r if r < n and heap[r][0] < heap[l][0] else l
		if heap[c][0] >= last[0]:
			break
		heap[k] = heap[c]
		k = c
	heap[k] = last
	return top
