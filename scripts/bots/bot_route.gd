class_name BotRoute
extends RefCounted
## A bot's way somewhere over MegaYeet's grid (the FlowField's cells), by a Yeet's rules, not a
## monster's: it can jump up about a metre and a bit, drop off anything (it won't climb a
## wall), and ride the map's jump pads (Arena.jump_links: from the pad to where it lands).
## A standing gate is in the way. Stepping onto a pad launches you: from a pad's cells the
## only way on is where it throws you (so a route doesn't wander across one by accident).
## `avoid`: cells to go round (big props standing there). A* with a cap on how far it looks;
## empty when there's no way.

const JUMP := 1.3
const DROP := 9.0
const PAD_COST := 30


## World points (cell centres at ground height) from near `from` to near `to`; empty if none.
static func find(field: FlowField, links: Array, from: Vector3, to: Vector3, max_steps := 9000, avoid := {}) -> PackedVector3Array:
	var out := PackedVector3Array()
	if field == null:
		return out
	var start := _standable(field, from)
	var goal := _standable(field, to)
	if start < 0 or goal < 0:
		return out
	var nx := field.nx
	var pads := {} # cell -> [landing cells] (every cell a pad covers)
	for l: Array in links:
		var b := _standable(field, l[1])
		if b < 0:
			continue
		var pad: Vector3 = l[0]
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var c := field.cell_of(pad + Vector3(dx, 0, dz) * 0.8)
				if c >= 0:
					if not pads.has(c):
						pads[c] = []
					if not b in pads[c]:
						pads[c].append(b)
	var g := {start: 0}
	var came := {}
	var heap := [[_h(field, start, goal), start]]
	var steps := 0
	while not heap.is_empty() and steps < max_steps:
		steps += 1
		var top: Array = FlowField._pop(heap)
		var i: int = top[1]
		if i == goal:
			var path := [i]
			while came.has(i):
				i = came[i]
				path.push_front(i)
			for c: int in path:
				var p := field.center(c)
				out.append(Vector3(p.x, field.height[c], p.y))
			return out
		var gi: int = g[i]
		if top[0] > gi + _h(field, i, goal):
			continue # (a stale entry)
		var x := i % nx
		var z := i / nx
		for dz in ([] if pads.has(i) and i != start else [-1, 0, 1]): # (on a pad: launched, nowhere else)
			for dx in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var ox: int = x + dx
				var oz: int = z + dz
				if ox < 0 or oz < 0 or ox >= nx or oz >= field.nz:
					continue
				var j := oz * nx + ox
				if not _step(field, i, j, dx, dz) or (avoid.has(j) and j != goal):
					continue
				var cost := gi + (14 if dx != 0 and dz != 0 else 10) + (4 if field.height[j] - field.height[i] > FlowField.STEP_UP else 0)
				if cost < int(g.get(j, 1 << 30)):
					g[j] = cost
					came[j] = i
					FlowField._push(heap, [cost + _h(field, j, goal), j])
		for j: int in pads.get(i, []):
			var cost := gi + PAD_COST
			if cost < int(g.get(j, 1 << 30)):
				g[j] = cost
				came[j] = i
				FlowField._push(heap, [cost + _h(field, j, goal), j])
	return out


static func _step(field: FlowField, a: int, b: int, dx: int, dz: int) -> bool:
	if field.walk[b] != 1:
		return false
	var up := field.height[b] - field.height[a]
	if up > JUMP or up < -DROP:
		return false
	if dx != 0 and dz != 0: # (not squeezing between two blocked corners)
		var ax := a % field.nx
		var az := a / field.nx
		if field.walk[az * field.nx + ax + dx] != 1 or field.walk[(az + dz) * field.nx + ax] != 1:
			return false
	return true


## The cell at p, or the nearest one around it a Yeet can stand on (within two cells, not
## above it, and not far below: mid-jump, or up on a prop, counts as the ground under it).
static func _standable(field: FlowField, p: Vector3) -> int:
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


static func _h(field: FlowField, a: int, b: int) -> int:
	var dx := absi(a % field.nx - b % field.nx)
	var dz := absi(a / field.nx - b / field.nx)
	return 10 * maxi(dx, dz) + 4 * mini(dx, dz)
