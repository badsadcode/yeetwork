class_name Horde
extends Node3D
## MegaYeet's monsters. The server runs them: lightweight walkers, not physics bodies, so
## there can be hundreds. Each steps along the FlowField toward the Heart, chases a Yeet that
## comes close and hits them, batters a gate in its way, and keeps its distance from the
## others. Things that hurt them: a gravity-gun push and blasts (they go flying), props
## flung into them (crushed), flying into walls or each other, falls, lava and acid, deep
## water. Every peer draws them from compact snapshots (10 a second, 12 bytes a monster) in
## one MultiMesh, the shader making them shamble; deaths go out reliably (a tumbling body).
## World holds the RPCs (_s_horde, _s_horde_deaths) and calls in here.

const SNAP_RATE := 0.1
const PER_PACKET := 90
const MAX_DRAWN := 600
const MAX_CORPSES := 40
const GRAVITY := 22.0
const RADIUS := 0.38 # (keeping apart: twice this)
const HEIGHT := 1.8
const POS_SCALE := 32.0

## Kinds: hit points, walking speed, damage to a Yeet, to a gate.
const KINDS := {
	"shambler": {"hp": 40.0, "speed": 1.7, "bite": 7.0, "bash": 22.0},
}
const KIND_IDS := ["shambler"]

enum State { WALK, FLY, STUN }


class Monster:
	var id := 0
	var kind := "shambler"
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var hp := 40.0
	var max_hp := 40.0
	var speed := 1.7
	var state := State.WALK
	var stun := 0.0
	var attack_cd := 0.0
	var flash := 0.0
	var attacker := 0
	var attacker_t := -10.0
	var cause := ""
	var chase: Player
	var think := 0.0
	var wet := 0.0
	var walk := 1.0
	var bash_at := -1


var world: Node
var field: FlowField
var monsters: Array[Monster] = [] # (server)
var _by_id := {}
var _next_id := 1
var _hash := {}
var _deaths := PackedFloat32Array()
var _snap_t := 0.0
var _gate_t := 0.0
var _gates_hit := false
var _prop_hits := {} # "monster:prop" -> time
# Every peer's view of them: id -> [pos, target, vel, yaw, flags, seen, kind]
var _views := {}
var _mmi: MultiMeshInstance3D
var _buf := PackedFloat32Array() # (every drawn monster's transform and shader data, set whole)
var _corpses: Array[Node3D] = []
var _groan_t := 2.0


func _ready() -> void:
	_mmi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = MonsterLook.mesh("shambler")
	mm.instance_count = MAX_DRAWN
	mm.visible_instance_count = 0
	_buf.resize(MAX_DRAWN * 16)
	_mmi.multimesh = mm
	_mmi.material_override = MonsterLook.material()
	_mmi.extra_cull_margin = 4096.0 # (they're everywhere: one big box)
	add_child(_mmi)


func _exit_tree() -> void:
	if field:
		field.finish()


func is_server() -> bool:
	return multiplayer.is_server()


func count() -> int:
	return monsters.size() if is_server() else _views.size()


# --- Server ---------------------------------------------------------------------------------

func server_spawn(pos: Vector3, kind := "shambler") -> Monster:
	var m := Monster.new()
	m.id = _next_id
	_next_id = (_next_id % 65000) + 1
	m.kind = kind
	var def: Dictionary = KINDS[kind]
	m.hp = def.hp
	m.max_hp = def.hp
	m.speed = def.speed * randf_range(0.8, 1.2)
	var g := field.ground(pos) if field else pos.y
	m.pos = Vector3(pos.x, g if g < INF else pos.y, pos.z)
	m.yaw = randf() * TAU
	m.think = randf() * 0.5
	monsters.append(m)
	_by_id[m.id] = m
	return m


func server_clear() -> void:
	for m in monsters:
		_deaths.append_array([m.id, m.pos.x, m.pos.y, m.pos.z, 0.0, 2.0, 0.0, 0.0])
	monsters.clear()
	_by_id.clear()


## A gravity-gun push: monsters in the cone go flying.
func server_punt(origin: Vector3, dir: Vector3, reach: float, cos_cone: float, strength: float, attacker: int) -> int:
	var n := 0
	for m: Monster in _near(origin, reach + 1.0):
		var c := m.pos + Vector3.UP * 0.9
		var to := c - origin
		var d := to.length()
		if d > reach or (d > 1.5 and dir.dot(to / d) < cos_cone):
			continue
		var falloff := (1.0 - (d / reach) * 0.5) * strength
		_hit(m, 12.0 * falloff, dir * 16.0 * falloff + Vector3.UP * 6.0, attacker, "punt")
		n += 1
	return n


## A blast: everything near goes flying, the closest in pieces.
func server_blast(pos: Vector3, radius: float, attacker: int) -> void:
	for m: Monster in monsters.duplicate():
		var to := m.pos + Vector3.UP * 0.9 - pos
		var d := to.length()
		if d > radius:
			continue
		var f := 1.0 - d / radius
		var away := to.normalized() if d > 0.1 else Vector3.UP
		away.y = maxf(away.y, 0.2)
		_hit(m, 25.0 + 110.0 * f, away.normalized() * 16.0 * f + Vector3.UP * (5.0 + 8.0 * f), attacker, "blast")


func _hit(m: Monster, amount: float, push: Vector3, attacker: int, cause: String) -> void:
	if attacker != 0:
		m.attacker = attacker
		m.attacker_t = world.now()
	m.flash = 1.0
	if push.length() > 0.5:
		m.vel = push
		m.state = State.FLY
		m.pos.y += 0.05
	_damage(m, amount, cause)


func _damage(m: Monster, amount: float, cause: String) -> void:
	if m.hp <= 0.0:
		return
	m.hp -= amount
	m.cause = cause
	if m.hp <= 0.0:
		_kill(m, cause)


func _kill(m: Monster, cause: String) -> void:
	m.hp = 0.0
	var idx := monsters.find(m)
	if idx >= 0:
		monsters[idx] = monsters[monsters.size() - 1]
		monsters.pop_back()
	_by_id.erase(m.id)
	var attacker := m.attacker if world.now() - m.attacker_t < 8.0 else 0
	var code := ["", "punt", "blast", "crushed", "fall", "lava", "acid", "drowned", "bowled", "wall", "heart", "hit"].find(cause)
	_deaths.append_array([m.id, m.pos.x, m.pos.y, m.pos.z, m.vel.x, m.vel.y, m.vel.z, float(maxi(code, 0))])
	if world.mode_logic and world.mode_logic.has_method("on_monster_killed"):
		world.mode_logic.on_monster_killed(m, cause, attacker)


func _physics_process(delta: float) -> void:
	if not is_server() or field == null:
		return
	var now: float = world.now()
	_rebuild_hash()
	_props_hit(now)
	for m: Monster in monsters.duplicate():
		if m.hp <= 0.0:
			continue
		m.flash = maxf(m.flash - delta * 4.0, 0.0)
		m.attack_cd -= delta
		match m.state:
			State.FLY:
				_fly(m, delta)
			State.STUN:
				m.stun -= delta
				m.walk = 0.0
				if m.stun <= 0.0:
					m.state = State.WALK
			_:
				_walk(m, delta, now)
		if m.hp > 0.0:
			_hazards(m, delta)
	_bite_players(now)
	_gate_t -= delta
	if _gates_hit and _gate_t <= 0.0:
		_gate_t = 1.0
		_gates_hit = false
		if field.refresh_gates():
			field.solve_async()
	if field.poll() and OS.get_cmdline_user_args().has("--trace"):
		print("FLOW re-solved (a gate changed)")
	if not _deaths.is_empty():
		world.server_horde_deaths(_deaths)
		_deaths = PackedFloat32Array()
	_snap_t -= delta
	if _snap_t <= 0.0:
		_snap_t = SNAP_RATE
		_send_snapshot()


func _walk(m: Monster, delta: float, now: float) -> void:
	m.think -= delta
	if m.think <= 0.0:
		m.think = 0.5
		m.chase = null
		var best := 7.0
		for pl: Player in world.players.values():
			if not pl.is_alive():
				continue
			var d := pl.global_position.distance_to(m.pos)
			if d < best and absf(pl.global_position.y - m.pos.y) < 2.0:
				best = d
				m.chase = pl
	var dir := field.direction(m.pos)
	if m.chase and is_instance_valid(m.chase) and m.chase.is_alive():
		var to := m.chase.global_position - m.pos
		var flat := Vector2(to.x, to.z)
		if flat.length() > 0.8:
			dir = flat.normalized()
		else:
			dir = Vector2.ZERO
	var step := Vector3(dir.x, 0, dir.y) * m.speed * (0.45 if m.wet > 0.0 else 1.0)
	# Keep apart.
	var push := Vector3.ZERO
	for o: Monster in _near(m.pos, RADIUS * 2.0):
		if o == m:
			continue
		var away := m.pos - o.pos
		away.y = 0.0
		var d := away.length()
		if d < RADIUS * 2.0 and d > 0.001:
			push += away / d * (RADIUS * 2.0 - d) * 4.0
		elif d <= 0.001:
			push += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var move := (step + push) * delta
	var here := field.cell_of(m.pos)
	var to_pos := m.pos + move
	var cell := field.cell_of(to_pos)
	m.bash_at = -1
	if cell != here and not _can_enter(m, here, cell):
		if cell >= 0 and field.walk[cell] == 2:
			m.bash_at = cell # (a gate in the way)
		# Slide along whatever's in the way.
		var alt := [m.pos + Vector3(move.x, 0, 0), m.pos + Vector3(0, 0, move.z)]
		to_pos = m.pos
		for a: Vector3 in alt:
			var c := field.cell_of(a)
			if c == here or _can_enter(m, here, c):
				to_pos = a
				break
	m.pos.x = to_pos.x
	m.pos.z = to_pos.z
	var g := field.ground(m.pos)
	if g == INF or g < m.pos.y - 0.7:
		m.state = State.FLY # (off an edge)
		m.vel = step * 0.8
	else:
		m.pos.y = move_toward(m.pos.y, g, delta * 5.0)
	m.walk = clampf(step.length() / maxf(m.speed, 0.1), 0.0, 1.0) if move.length() > 0.0005 else 0.0
	if step.length() > 0.05:
		m.yaw = lerp_angle(m.yaw, atan2(-step.x, -step.z), 1.0 - exp(-6.0 * delta))
	if m.bash_at >= 0 and m.attack_cd <= 0.0:
		_bash(m)
	if field.dist[maxi(here, 0)] == 0 and here >= 0:
		if world.mode_logic and world.mode_logic.has_method("on_monster_reached"):
			world.mode_logic.on_monster_reached(m)
		m.attacker = 0
		_kill(m, "heart")


func _can_enter(_m: Monster, from: int, to: int) -> bool:
	if to < 0 or field.walk[to] != 1:
		return false
	if from < 0:
		return true
	return field.height[to] - field.height[from] <= FlowField.STEP_UP


func _bash(m: Monster) -> void:
	m.attack_cd = 1.4
	var wall = field.gate_wall.get(m.bash_at)
	if wall == null or not is_instance_valid(wall):
		_gates_hit = true
		return
	var c := field.center(m.bash_at)
	var at := Vector3(c.x, field.height[m.bash_at] + 1.0, c.y)
	var dir := (at - m.pos).normalized()
	world.server_damage_destructible(wall, at, 0.7, KINDS[m.kind].bash, dir * 3.0, 0, 1.0)
	_gates_hit = true


func _fly(m: Monster, delta: float) -> void:
	m.walk = 0.0
	m.vel.y -= GRAVITY * delta
	m.vel *= 1.0 - 0.15 * delta
	var from := m.pos + Vector3.UP * 0.9
	var to := from + m.vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to + m.vel.normalized() * 0.3, Game.L_WORLD)
	var hit := space.intersect_ray(q)
	var speed := m.vel.length()
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		m.pos = hit.position - m.vel.normalized() * 0.35 - Vector3.UP * 0.9
		if n.y > 0.6:
			_land(m, -m.vel.dot(n))
		else:
			if speed > 9.0:
				_damage(m, (speed - 9.0) * 5.0, "wall")
			m.vel = m.vel.bounce(n) * 0.3
			m.flash = 1.0
		return
	m.pos = to - Vector3.UP * 0.9
	# Bowling: flying into the others knocks them over too.
	if speed > 6.0:
		for o: Monster in _near(m.pos, RADIUS * 2.4):
			if o == m or o.state == State.FLY:
				continue
			if (o.pos - m.pos).length() < RADIUS * 2.4:
				o.attacker = m.attacker
				o.attacker_t = m.attacker_t
				_hit(o, 10.0, m.vel * 0.55 + Vector3.UP * 3.0, 0, "bowled")
				m.vel *= 0.8
	var g := field.ground(m.pos)
	if g < INF and m.pos.y <= g and m.vel.y < 0.0 and m.pos.y > g - 1.5:
		m.pos.y = g
		_land(m, -m.vel.y)
	elif m.pos.y < world.arena.kill_y:
		_kill(m, "fall")


func _land(m: Monster, impact: float) -> void:
	if impact > 11.0:
		_damage(m, (impact - 11.0) * 7.0, "fall")
	if m.hp <= 0.0:
		return
	m.state = State.STUN
	m.stun = 0.5
	m.vel = Vector3.ZERO


func _hazards(m: Monster, delta: float) -> void:
	var liq := Liquid.at(m.pos + Vector3.UP * 0.2, 0.0)
	if liq == null:
		m.wet = 0.0
		return
	if liq.kind == "lava" or liq.kind == "acid":
		_kill(m, liq.kind)
		return
	var depth := liq.height_at(m.pos.x, m.pos.z) - m.pos.y
	if depth > 1.5:
		m.wet += delta
		if m.wet > 3.0:
			_kill(m, "drowned")
	else:
		m.wet = 0.01 if depth > 0.4 else 0.0


## Props flung into them: crushed (and sent flying), the prop slowed a little.
func _props_hit(now: float) -> void:
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.freeze or p.held_by != 0:
			continue
		var v := p.linear_velocity
		var speed := v.length()
		if speed < 6.0:
			continue
		var r := maxf(p.size.x, maxf(p.size.y, p.size.z)) * 0.5 + RADIUS
		var at := p.global_position
		for m: Monster in _near(at, r + 1.0):
			var low := m.pos.y
			var top := m.pos.y + HEIGHT
			var closest := Vector3(m.pos.x, clampf(at.y, low, top), m.pos.z)
			if closest.distance_to(at) > r:
				continue
			var key := "%d:%d" % [m.id, p.prop_id]
			if now - float(_prop_hits.get(key, -10.0)) < 0.4:
				continue
			_prop_hits[key] = now
			var energy := 0.5 * p.mass * speed * speed
			var attacker: int = p.last_thrower if now - p.last_thrown_time < 6.0 else 0
			_hit(m, clampf(energy / 30.0, 6.0, 500.0), v * 0.6 + Vector3.UP * 4.0, attacker, "crushed")
			p.linear_velocity = v * 0.85
	if _prop_hits.size() > 2000:
		_prop_hits.clear()


## Monsters next to a Yeet hit them.
func _bite_players(_now: float) -> void:
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var pp := pl.global_position
		for m: Monster in _near(pp, 1.4):
			if m.state != State.WALK or m.attack_cd > 0.0:
				continue
			var to := pp - m.pos
			if Vector2(to.x, to.z).length() > 1.1 or absf(to.y) > 1.4:
				continue
			m.attack_cd = 1.3
			var dir := Vector3(to.x, 0, to.z).normalized()
			world.server_damage_player(pl, KINDS[m.kind].bite, 0, "monster", pl.body_center(), dir)
			if pl.is_alive():
				world.server_launch_player(pl, dir * 3.5 + Vector3.UP * 1.5, false, 0.0, 0)


func _rebuild_hash() -> void:
	_hash.clear()
	for m in monsters:
		var k := Vector2i(int(floor(m.pos.x * 0.5)), int(floor(m.pos.z * 0.5)))
		if _hash.has(k):
			_hash[k].append(m)
		else:
			_hash[k] = [m]


## Monsters within about r of p (from the 2 m buckets).
func _near(p: Vector3, r: float) -> Array:
	var out := []
	var x0 := int(floor((p.x - r) * 0.5))
	var x1 := int(floor((p.x + r) * 0.5))
	var z0 := int(floor((p.z - r) * 0.5))
	var z1 := int(floor((p.z + r) * 0.5))
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var b = _hash.get(Vector2i(x, z))
			if b:
				out.append_array(b)
	return out


func _send_snapshot() -> void:
	var buf := PackedByteArray()
	var n := 0
	for m in monsters:
		if n == 0:
			buf = PackedByteArray()
			buf.resize(PER_PACKET * 12)
		var o := n * 12
		buf.encode_u16(o, m.id)
		buf.encode_s16(o + 2, clampi(int(m.pos.x * POS_SCALE), -32767, 32767))
		buf.encode_s16(o + 4, clampi(int(m.pos.y * POS_SCALE), -32767, 32767))
		buf.encode_s16(o + 6, clampi(int(m.pos.z * POS_SCALE), -32767, 32767))
		buf.encode_u8(o + 8, int(fposmod(m.yaw, TAU) / TAU * 255.0))
		var flags := (1 if m.state == State.FLY else 0) | (2 if m.flash > 0.3 else 0) | (int(m.walk * 7.0) << 2)
		buf.encode_u8(o + 9, flags)
		buf.encode_u8(o + 10, KIND_IDS.find(m.kind))
		buf.encode_u8(o + 11, int(clampf(m.hp / m.max_hp, 0.0, 1.0) * 255.0))
		n += 1
		if n == PER_PACKET:
			world.server_horde_snapshot(buf)
			n = 0
	if n > 0:
		world.server_horde_snapshot(buf.slice(0, n * 12))
	elif monsters.is_empty():
		world.server_horde_snapshot(PackedByteArray())


# --- Every peer: what's drawn ---------------------------------------------------------------

## A snapshot from the server (clients).
func apply_snapshot(buf: PackedByteArray) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for k in buf.size() / 12:
		var o := k * 12
		var id := buf.decode_u16(o)
		var pos := Vector3(buf.decode_s16(o + 2), buf.decode_s16(o + 4), buf.decode_s16(o + 6)) / POS_SCALE
		var v: Array = _views.get(id, [])
		if v.is_empty():
			v = [pos, pos, Vector3.ZERO, 0.0, 0, now, 0]
			_views[id] = v
		else:
			var dt := clampf(now - float(v[5]), 0.05, 0.5)
			v[2] = (pos - (v[1] as Vector3)) / dt
		v[1] = pos
		v[3] = buf.decode_u8(o + 8) / 255.0 * TAU
		v[4] = buf.decode_u8(o + 9)
		v[5] = now
		v[6] = buf.decode_u8(o + 10)


## Deaths: [id, x, y, z, vx, vy, vz, cause] each (every peer).
func apply_deaths(buf: PackedFloat32Array) -> void:
	var i := 0
	while i + 7 < buf.size():
		var id := int(buf[i])
		var pos := Vector3(buf[i + 1], buf[i + 2], buf[i + 3])
		var vel := Vector3(buf[i + 4], buf[i + 5], buf[i + 6])
		var cause := int(buf[i + 7])
		var yaw := 0.0
		if _views.has(id):
			pos = _views[id][0]
			yaw = _views[id][3]
			_views.erase(id)
		if cause == 10: # (into the Heart: swallowed in a flash)
			world.fx.puffs(pos + Vector3.UP, Vector3.UP, 10, [Color(1.0, 0.3, 0.2, 0.8), Color(0.6, 0.1, 0.1, 0.0)], 0.3, 0.7, 1.0, 3.0, 1.0)
		else:
			_corpse(pos, vel, yaw, cause)
		i += 8


func _process(delta: float) -> void:
	var mm := _mmi.multimesh
	var n := 0
	var buf := _buf
	if is_server():
		n = mini(monsters.size(), MAX_DRAWN)
		for k in n:
			var m := monsters[k]
			_put(buf, k, m.pos, m.yaw, m.id, m.walk, m.flash, m.state == State.FLY)
	else:
		var now := Time.get_ticks_msec() / 1000.0
		var gone := []
		for id in _views:
			var v: Array = _views[id]
			var age := now - float(v[5])
			if age > 1.5:
				gone.append(id)
				continue
			var aim: Vector3 = v[1] + v[2] * minf(age, 0.15)
			v[0] = (v[0] as Vector3).lerp(aim, 1.0 - exp(-14.0 * delta))
			if n < MAX_DRAWN:
				var flags: int = v[4]
				_put(buf, n, v[0], v[3], id, ((flags >> 2) & 7) / 7.0, 1.0 if flags & 2 else 0.0, flags & 1 != 0)
				n += 1
		for id in gone:
			_views.erase(id)
	if n > 0:
		mm.buffer = buf # (all at once; past the count they're hidden)
	mm.visible_instance_count = n
	_groans(delta)


func _put(buf: PackedFloat32Array, k: int, pos: Vector3, yaw: float, id: int, walk: float, flash: float, flying: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	if flying:
		b = b * Basis(Vector3.RIGHT, sin(Time.get_ticks_msec() * 0.006 + id) * 0.9)
	var o := k * 16
	buf[o] = b.x.x
	buf[o + 1] = b.y.x
	buf[o + 2] = b.z.x
	buf[o + 3] = pos.x
	buf[o + 4] = b.x.y
	buf[o + 5] = b.y.y
	buf[o + 6] = b.z.y
	buf[o + 7] = pos.y
	buf[o + 8] = b.x.z
	buf[o + 9] = b.y.z
	buf[o + 10] = b.z.z
	buf[o + 11] = pos.z
	buf[o + 12] = fmod(id * 0.618034, 1.0)
	buf[o + 13] = walk
	buf[o + 14] = flash
	buf[o + 15] = 1.0 if flying else 0.0


## Now and then one of them moans (somewhere near the local Yeet).
func _groans(delta: float) -> void:
	_groan_t -= delta
	if _groan_t > 0.0 or world == null or world.local_player == null:
		return
	_groan_t = randf_range(1.2, 3.0)
	var me: Vector3 = world.local_player.global_position
	var best := Vector3.INF
	if is_server():
		for k in mini(monsters.size(), 40):
			var p := monsters[randi() % monsters.size()].pos
			if p.distance_to(me) < best.distance_to(me):
				best = p
	else:
		for id in _views:
			var p: Vector3 = _views[id][0]
			if p.distance_to(me) < best.distance_to(me):
				best = p
	if best != Vector3.INF and best.distance_to(me) < 30.0:
		Sfx.play3d("voice_die", best + Vector3.UP * 1.6, -6.0, randf_range(0.38, 0.5))


## A body that tumbles where it fell, then sinks away (local, a few dozen at most).
func _corpse(pos: Vector3, vel: Vector3, yaw: float, cause: int) -> void:
	if cause == 5 or cause == 6: # (lava, acid: nothing left)
		world.fx.puffs(pos + Vector3.UP, Vector3.UP, 8, [Color(0.3, 0.3, 0.3, 0.7), Color(0.2, 0.2, 0.2, 0.0)], 0.4, 0.9, 1.0, 2.5, 1.6)
		Sfx.play3d("sizzle", pos, 0.0, randf_range(0.8, 1.0))
		return
	if Game.gore_level > 0:
		world.fx.blood(pos + Vector3.UP * 1.0, Vector3.UP, vel.normalized() if vel.length() > 0.1 else Vector3.UP, 0.6)
	else:
		world.fx.confetti(pos + Vector3.UP * 1.0, Vector3.UP, 0.6)
	Sfx.play3d("smack", pos + Vector3.UP, -2.0, randf_range(0.7, 0.9))
	while _corpses.size() >= MAX_CORPSES:
		var old: Node3D = _corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var rb := RigidBody3D.new()
	rb.collision_layer = Game.L_LIMBS
	rb.collision_mask = Game.L_WORLD | Game.L_LIMBS
	rb.mass = 40.0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 1.7, 0.4)
	cs.shape = sh
	cs.position.y = 0.85
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MonsterLook.mesh("shambler")
	mi.material_override = MonsterLook.material()
	rb.add_child(mi)
	add_child(rb)
	rb.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	rb.linear_velocity = vel + Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1))
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4)) + Vector3(-3, 0, 0)
	_corpses.append(rb)
	var tw := rb.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(mi, "scale", Vector3(1, 0.05, 1), 0.8)
	tw.tween_callback(func():
		_corpses.erase(rb)
		rb.queue_free())
