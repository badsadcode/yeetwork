class_name Horde
extends Node3D
## MegaYeet's monsters. The server runs them: lightweight walkers, not physics bodies, so
## there can be hundreds. Each steps along the FlowField toward the Heart, chases a Yeet that
## comes close and hits them, batters a gate in its way, and keeps its distance from the
## others. Things that hurt them: a gravity-gun push and blasts (they go flying), props
## flung into them (crushed), flying into walls or each other, falls, lava and acid, deep
## water, fire (it spreads through a crowd). The gravity gun can grab most of them, swing
## them into the others and throw them. Kinds (KINDS):
## - shambler: the many. - runner: fast and fragile.
## - brute (Frankenstein's monster): huge, slow, tough; too heavy to grab, barely moved by a
##   push, smashes gates and Yeets. Blast it, burn it, drop it off something, drown it.
## - ghost: drifts straight for the Heart, through walls; nothing touches it but fire and
##   light (a flashlight's beam burns it: everyone carries one in MegaYeet).
## - climber (a skeleton): goes straight at the Heart and climbs any wall in the way.
## - bomber: runs at gates and Yeets with a powder keg and blows up (killed, it blows up
##   where it falls: chain reactions, or throw one into the crowd).
## Every peer draws them from compact snapshots (10 a second, 12 bytes a monster) in one
## MultiMesh per kind, the shader making them shamble; deaths go out reliably (a tumbling
## body). World holds the RPCs (_s_horde, _s_horde_deaths) and calls in here.

const SNAP_RATE := 0.1
const PER_PACKET := 90
const MAX_DRAWN := 600
const MAX_CORPSES := 40
const GRAVITY := 22.0
const HEIGHT := 1.8
const POS_SCALE := 32.0
const HOLD_TIME := 4.0 # (a monster in the gun's grip wriggles free after this)
const LIGHT_BURN := 45.0 # (a flashlight on a ghost, a second)
const LIGHT_RANGE := 16.0
const LIGHT_COS := 0.92
const FIRE_BURN := 12.0 # (burning, a second; times the kind's burn)
const BOMB_RADIUS := 5.5

## Kinds: hit points, speed, damage to a Yeet (bite) and a gate (bash), how far pushes move it
## (knock), whether the gun grabs it, its size (drawn scaled), how far apart they keep
## (radius), how hard fire hits it (burn), and what it does differently.
const KINDS := {
	"shambler": {"hp": 40.0, "speed": 1.7, "bite": 7.0, "bash": 22.0, "knock": 1.0, "grab": true, "size": 1.0, "radius": 0.38, "burn": 1.0},
	"runner": {"hp": 20.0, "speed": 4.0, "bite": 5.0, "bash": 10.0, "knock": 1.25, "grab": true, "size": 0.92, "radius": 0.34, "burn": 1.2},
	"brute": {"hp": 320.0, "speed": 1.15, "bite": 24.0, "bash": 110.0, "knock": 0.15, "grab": false, "size": 1.45, "radius": 0.6, "burn": 1.4},
	"ghost": {"hp": 60.0, "speed": 1.5, "bite": 9.0, "bash": 0.0, "knock": 0.0, "grab": false, "size": 1.0, "radius": 0.3, "burn": 2.5, "ghost": true},
	"climber": {"hp": 30.0, "speed": 2.1, "bite": 6.0, "bash": 12.0, "knock": 1.1, "grab": true, "size": 1.0, "radius": 0.32, "burn": 1.0, "climb": true},
	"bomber": {"hp": 16.0, "speed": 2.9, "bite": 0.0, "bash": 0.0, "knock": 1.2, "grab": true, "size": 0.8, "radius": 0.32, "burn": 1.5, "bomb": true},
}
const KIND_IDS := ["shambler", "runner", "brute", "ghost", "climber", "bomber"]
const CAUSES := ["", "punt", "blast", "crushed", "fall", "lava", "acid", "drowned", "bowled", "wall", "heart", "hit", "fire", "light", "bomb", "spikes"]
const SPIKES := 30.0 # (a second, on spikes)

enum State { WALK, FLY, STUN, CLIMB, HELD }


class Monster:
	var id := 0
	var kind := "shambler"
	var def: Dictionary
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
	var burn := 0.0
	var burn_by := 0
	var climb_to := -1
	var held_by := 0
	var slow := 0.0


var world: Node
var field: FlowField
var monsters: Array[Monster] = [] # (server)
var _by_id := {}
var _next_id := 1
var _hash := {}
var _deaths := PackedFloat32Array()
var _bombs: Array = [] # [position, attacker]: bombers gone off, blown up next tick
var _snap_t := 0.0
var _gate_t := 0.0
var _gates_hit := false
var _fire_t := 0.0
var _light_t := 0.0
var _prop_hits := {} # "monster:prop" -> time
var _heart: Vector3
var _heart_r := 2.5
var _traps: Array[TrapSpot] = []
var _trap_t := 0.0
# Every peer's view of them: id -> [pos, target, vel, yaw, flags, seen, kind]
var _views := {}
var _draw := {} # kind -> [MultiMeshInstance3D, buffer]
var _corpses: Array[Node3D] = []
var _groan_t := 2.0
var _flames_t := 0.0


func _ready() -> void:
	for kind in KIND_IDS:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = MonsterLook.mesh(kind)
		mm.instance_count = MAX_DRAWN
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = MonsterLook.material(kind)
		mmi.extra_cull_margin = 4096.0 # (they're everywhere: one big box)
		if kind == "ghost":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		var buf := PackedFloat32Array()
		buf.resize(MAX_DRAWN * 16)
		_draw[kind] = [mmi, buf]
	if world and world.arena and world.arena.heart:
		_heart = world.arena.heart.global_position
		_heart_r = world.arena.heart.radius
	if world and world.arena:
		for n in world.arena.puzzle:
			if n is TrapSpot:
				_traps.append(n)


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
	m.def = KINDS[kind]
	m.hp = m.def.hp
	m.max_hp = m.def.hp
	m.speed = m.def.speed * randf_range(0.85, 1.15)
	var g := field.ground(pos) if field else pos.y
	m.pos = Vector3(pos.x, g if g < INF else pos.y, pos.z)
	if m.def.has("ghost"):
		m.pos.y = _heart.y + 0.6
	m.yaw = randf() * TAU
	m.think = randf() * 0.5
	monsters.append(m)
	_by_id[m.id] = m
	return m


func get_monster(id: int) -> Monster:
	return _by_id.get(id)


## A gate was repaired: look at the ways to the Heart again in a moment (once its wall's
## collision is back in the physics world).
func request_gate_refresh() -> void:
	_gates_hit = true
	_gate_t = 0.3


func server_clear() -> void:
	for m in monsters: # (gone in a flash, no bodies)
		_deaths.append_array([m.id, m.pos.x, m.pos.y, m.pos.z, 0.0, 0.0, 0.0, float(10 + KIND_IDS.find(m.kind) * 32)])
	monsters.clear()
	_by_id.clear()
	_bombs.clear()


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
		if f > 0.5:
			_ignite(m, 3.0, attacker)


## The gun's grip: the monster nearest along the aim within reach that it can hold.
func server_grab(origin: Vector3, dir: Vector3, reach: float) -> Monster:
	var best: Monster = null
	var best_t := INF
	for m: Monster in _near(origin + dir * reach * 0.5, reach * 0.5 + 1.5):
		if not m.def.grab or m.state == State.HELD or m.hp <= 0.0:
			continue
		var c: Vector3 = m.pos + Vector3.UP * 0.9 * float(m.def.size)
		var t: float = (c - origin).dot(dir)
		if t < 0.3 or t > reach:
			continue
		if (c - (origin + dir * t)).length() > 0.9:
			continue
		if t < best_t:
			best = m
			best_t = t
	return best


## Held in the gun's grip, toward `target` (its middle).
func server_hold(m: Monster, target: Vector3, delta: float, holder: int) -> void:
	m.state = State.HELD
	m.held_by = holder
	m.attacker = holder
	m.attacker_t = world.now()
	var to := target - (m.pos + Vector3.UP * 0.9)
	var step := to * (1.0 - exp(-16.0 * delta))
	m.vel = step / maxf(delta, 0.001)
	m.pos += step
	m.walk = 0.0


## Let go of (dropped, or thrown with vel).
func server_let_go(m: Monster, vel: Vector3) -> void:
	if m.state != State.HELD:
		return
	m.state = State.FLY
	m.held_by = 0
	m.stun = 0.0
	m.vel = vel
	m.attacker_t = world.now()


func _hit(m: Monster, amount: float, push: Vector3, attacker: int, cause: String) -> void:
	if attacker != 0:
		m.attacker = attacker
		m.attacker_t = world.now()
	m.flash = 1.0
	if m.def.has("ghost") and cause not in ["fire", "light"]:
		return # (it goes right through it)
	push *= m.def.knock
	if push.length() > 0.8 and m.state != State.HELD:
		m.vel = push
		m.state = State.FLY
		m.pos.y += 0.05
	_damage(m, amount, cause)


func _damage(m: Monster, amount: float, cause: String) -> void:
	if m.hp <= 0.0:
		return
	if m.def.has("ghost") and cause not in ["fire", "light", "heart"]:
		return
	m.hp -= amount
	m.cause = cause
	if m.hp <= 0.0:
		_kill(m, cause)


func _ignite(m: Monster, seconds: float, by: int) -> void:
	if m.wet > 0.0:
		return
	if m.burn <= 0.0:
		m.burn_by = by
	m.burn = maxf(m.burn, seconds)


func _kill(m: Monster, cause: String) -> void:
	m.hp = 0.0
	var idx := monsters.find(m)
	if idx >= 0:
		monsters[idx] = monsters[monsters.size() - 1]
		monsters.pop_back()
	_by_id.erase(m.id)
	var attacker := m.attacker if world.now() - m.attacker_t < 8.0 else 0
	if attacker == 0 and m.burn > 0.0:
		attacker = m.burn_by
	if m.def.has("bomb") and cause not in ["lava", "acid", "drowned", "heart"]:
		_bombs.append([m.pos + Vector3.UP * 0.8, attacker]) # (it goes off where it fell)
	var code := maxi(CAUSES.find(cause), 0)
	_deaths.append_array([m.id, m.pos.x, m.pos.y, m.pos.z, m.vel.x, m.vel.y, m.vel.z, float(code + KIND_IDS.find(m.kind) * 32)])
	if world.mode_logic and world.mode_logic.has_method("on_monster_killed"):
		world.mode_logic.on_monster_killed(m, cause, attacker)


func _physics_process(delta: float) -> void:
	if not is_server() or field == null:
		return
	var now: float = world.now()
	# Bombers that went off last tick (not mid-blast: a blast that sets one off waits a tick).
	if not _bombs.is_empty():
		var go := _bombs.duplicate()
		_bombs.clear()
		for b: Array in go:
			world.server_explode_at(b[0], BOMB_RADIUS, b[1])
	_rebuild_hash()
	_props_hit(now)
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = 0.25
		_spread_fire()
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.1
		_flashlights()
	_trap_t -= delta
	if _trap_t <= 0.0:
		_trap_t = 0.1
		_trap_tick(0.1)
	for m: Monster in monsters.duplicate():
		if m.hp <= 0.0:
			continue
		m.flash = maxf(m.flash - delta * 4.0, 0.0)
		m.attack_cd -= delta
		m.slow = maxf(m.slow - delta, 0.0)
		if m.burn > 0.0:
			m.burn -= delta
			_damage(m, FIRE_BURN * float(m.def.burn) * delta, "fire")
			if m.hp <= 0.0:
				continue
		match m.state:
			State.FLY:
				_fly(m, delta)
			State.STUN:
				m.stun -= delta
				m.walk = 0.0
				if m.stun <= 0.0:
					m.state = State.WALK
			State.CLIMB:
				_climb(m, delta)
			State.HELD:
				_held(m, delta)
			_:
				if m.def.has("ghost"):
					_ghost(m, delta)
				else:
					_walk(m, delta, now)
		if m.hp > 0.0 and not m.def.has("ghost"):
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


func _think_chase(m: Monster, delta: float, reach: float) -> void:
	m.think -= delta
	if m.think > 0.0:
		return
	m.think = 0.5
	m.chase = null
	var best := reach
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var d := pl.global_position.distance_to(m.pos)
		if d < best and absf(pl.global_position.y - m.pos.y) < 2.0:
			best = d
			m.chase = pl


func _walk(m: Monster, delta: float, _now: float) -> void:
	var bomb: bool = m.def.has("bomb")
	var climber: bool = m.def.has("climb")
	_think_chase(m, delta, 10.0 if bomb else 7.0)
	var dir := field.direction(m.pos)
	var here := field.cell_of(m.pos)
	if climber and here >= 0:
		# Straight at the Heart, up and over whatever's in the way: the next place it can
		# stand along that line (past a wall's edge, a battlement) is where it climbs to.
		var straight := Vector2(_heart.x - m.pos.x, _heart.z - m.pos.z)
		if straight.length() > 1.0:
			var s := straight.normalized()
			var next := field.cell_of(m.pos + Vector3(s.x, 0, s.y) * 0.6)
			var stand := -1
			for k in range(1, 6):
				var c := field.cell_of(m.pos + Vector3(s.x, 0, s.y) * (0.6 * k))
				if c < 0 or field.walk[c] == 2:
					break
				if c != here and field.walk[c] == 1:
					stand = c
					break
			if stand >= 0:
				dir = s
				var blocked := next != here and (next < 0 or field.walk[next] != 1 or absf(field.height[next] - m.pos.y) > FlowField.STEP_UP)
				if blocked and absf(field.height[stand] - m.pos.y) > FlowField.STEP_UP:
					m.state = State.CLIMB # (up a wall, or down off one)
					m.climb_to = stand
					m.yaw = atan2(-s.x, -s.y)
					return
	if m.chase and is_instance_valid(m.chase) and m.chase.is_alive():
		var to := m.chase.global_position - m.pos
		var flat := Vector2(to.x, to.z)
		dir = flat.normalized() if flat.length() > 0.8 else Vector2.ZERO
	var step := Vector3(dir.x, 0, dir.y) * m.speed * (0.45 if m.wet > 0.0 else 1.0) * (0.4 if m.slow > 0.0 else 1.0)
	var push := _apart(m)
	var move := (step + push) * delta
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
		if bomb:
			_detonate(m)
			return
		_bash(m)
	if here >= 0 and field.dist[here] == 0:
		_reached(m)


## Keeping apart from the others nearby.
func _apart(m: Monster) -> Vector3:
	var push := Vector3.ZERO
	var r: float = m.def.radius
	for o: Monster in _near(m.pos, r * 2.0 + 0.4):
		if o == m:
			continue
		var away := m.pos - o.pos
		away.y = 0.0
		var d := away.length()
		var keep: float = r + float(o.def.radius)
		if d < keep and d > 0.001:
			push += away / d * (keep - d) * 4.0
		elif d <= 0.001:
			push += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return push


func _reached(m: Monster) -> void:
	if world.mode_logic and world.mode_logic.has_method("on_monster_reached"):
		world.mode_logic.on_monster_reached(m)
	m.attacker = 0
	m.burn = 0.0
	_kill(m, "heart")


func _can_enter(_m: Monster, from: int, to: int) -> bool:
	if to < 0 or field.walk[to] != 1:
		return false
	if from < 0:
		return true
	return field.height[to] - field.height[from] <= FlowField.STEP_UP


func _bash(m: Monster) -> void:
	m.attack_cd = 1.6 if m.kind == "brute" else 1.4
	var wall = field.gate_wall.get(m.bash_at)
	if wall == null or not is_instance_valid(wall):
		_gates_hit = true
		return
	var c := field.center(m.bash_at)
	var at := Vector3(c.x, field.height[m.bash_at] + 1.0, c.y)
	var dir := (at - m.pos).normalized()
	world.server_damage_destructible(wall, at, 0.9 if m.kind == "brute" else 0.7, m.def.bash, dir * 3.0, 0, 1.0)
	if m.kind == "brute":
		world.server_fx("impact:metal", at, dir * 6.0, 1.5, -dir)
	_gates_hit = true


## A bomber at a gate or a Yeet: off it goes.
func _detonate(m: Monster) -> void:
	m.attacker = 0
	m.burn = 0.0
	_kill(m, "bomb")


## Up a wall (or down off one) to its next cell's height, then onto it.
func _climb(m: Monster, delta: float) -> void:
	if m.climb_to < 0:
		m.state = State.WALK
		return
	var target := field.height[m.climb_to]
	m.walk = 1.0
	m.pos.y = move_toward(m.pos.y, target, delta * 1.8)
	if absf(m.pos.y - target) < 0.02:
		var c := field.center(m.climb_to) # (over the edge, onto it)
		m.pos.x = c.x
		m.pos.z = c.y
		m.climb_to = -1
		m.state = State.WALK


## In a gravity gun's grip: the gun moves it (World: the gun's server tick). Swung fast, it
## bowls over the others; it wriggles free in a while.
func _held(m: Monster, delta: float) -> void:
	m.stun += delta
	if m.stun > HOLD_TIME or world.get_player(m.held_by) == null:
		m.stun = 0.0
		m.state = State.FLY
		m.held_by = 0
		return
	if m.vel.length() > 7.0:
		_bowl(m)


## Straight for the Heart through anything (or for a Yeet close by), floating, bobbing.
func _ghost(m: Monster, delta: float) -> void:
	_think_chase(m, delta, 6.0)
	var to := Vector2(_heart.x - m.pos.x, _heart.z - m.pos.z)
	if m.chase and is_instance_valid(m.chase) and m.chase.is_alive():
		var c := m.chase.global_position
		to = Vector2(c.x - m.pos.x, c.z - m.pos.z)
	var d := to.length()
	var step := Vector3(to.x, 0, to.y) / d * m.speed if d > 0.6 else Vector3.ZERO
	var move := (step + _apart(m) * 0.5) * delta
	m.pos.x += move.x
	m.pos.z += move.z
	var hover := _heart.y + 0.5 + sin(world.now() * 1.7 + m.id) * 0.25
	m.pos.y = move_toward(m.pos.y, hover, delta * 2.0)
	m.walk = 0.35
	if step.length() > 0.05:
		m.yaw = lerp_angle(m.yaw, atan2(-step.x, -step.z), 1.0 - exp(-4.0 * delta))
	if Vector2(_heart.x - m.pos.x, _heart.z - m.pos.z).length() < _heart_r:
		_reached(m)


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
	if speed > 6.0:
		_bowl(m)
	var g := field.ground(m.pos)
	if g < INF and m.pos.y <= g and m.vel.y < 0.0 and m.pos.y > g - 1.5:
		m.pos.y = g
		_land(m, -m.vel.y)
	elif m.pos.y < world.arena.kill_y:
		_kill(m, "fall")


## Flying (or swung) into the others knocks them over too.
func _bowl(m: Monster) -> void:
	for o: Monster in _near(m.pos, 1.2):
		if o == m or o.state == State.FLY or o.state == State.HELD:
			continue
		if (o.pos - m.pos).length() < float(m.def.radius) + float(o.def.radius) + 0.3:
			o.attacker = m.attacker
			o.attacker_t = m.attacker_t
			_hit(o, 10.0, m.vel * 0.55 + Vector3.UP * 3.0, 0, "bowled")
			m.vel *= 0.8


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
	if depth > 0.4:
		m.burn = 0.0 # (water puts it out)
	if depth > 1.5:
		m.wet += delta
		if m.wet > 3.0:
			_kill(m, "drowned")
	else:
		m.wet = 0.01 if depth > 0.4 else 0.0


## Fire: burning things and burning places set monsters alight; burning monsters set the
## ones packed round them alight.
func _spread_fire() -> void:
	for id in world._burning_props.keys():
		var p: Prop = world.get_prop(id)
		if p == null:
			continue
		var by: int = world._burning_props[id][1] if world._burning_props[id] is Array else 0
		for m: Monster in _near(p.global_position, 1.8):
			if (m.pos + Vector3.UP * 0.9).distance_to(p.global_position) < 1.6:
				_ignite(m, 5.0, by)
	for area: Array in world.arena.fire_areas:
		var xf: Transform3D = area[0]
		var half: Vector3 = area[1] * 0.5
		var inv := xf.affine_inverse()
		for m: Monster in _near(xf.origin, half.length() + 1.0):
			var l := inv * (m.pos + Vector3.UP * 0.5)
			if absf(l.x) <= half.x and absf(l.y) <= half.y + 0.5 and absf(l.z) <= half.z:
				_ignite(m, 4.0, 0)
	for m: Monster in monsters:
		if m.burn <= 0.0:
			continue
		for o: Monster in _near(m.pos, 1.0):
			if o != m and o.burn <= 0.0 and randf() < 0.3 and (o.pos - m.pos).length() < 0.95:
				_ignite(o, 4.0, m.burn_by)


## Built traps (TrapSpot) at work on the monsters in them: spikes hurt and slow, a fire grate
## sets them alight, a mine goes off under the first to step on it (and is gone). Ghosts
## float over spikes and mines; nothing flying or held is caught.
func _trap_tick(dt: float) -> void:
	for t in _traps:
		if not t.built:
			continue
		var c := t.global_position
		for m: Monster in _near(c, Vector2(t.size.x, t.size.z).length() * 0.5 + 1.0):
			if m.hp <= 0.0 or m.state == State.FLY or m.state == State.HELD:
				continue
			if m.def.has("ghost") and t.kind != "fire":
				continue
			if not t.has_point(m.pos + Vector3.UP * 0.3):
				continue
			match t.kind:
				"spikes":
					if t.owner_id != 0:
						m.attacker = t.owner_id
						m.attacker_t = world.now()
					m.slow = 0.3
					m.flash = maxf(m.flash, 0.5)
					_damage(m, SPIKES * dt, "spikes")
				"fire":
					_ignite(m, 4.0, t.owner_id)
				"mine":
					t.server_clear()
					world.server_explode_at(c + Vector3.UP * 0.5, 6.0, t.owner_id)
					break


## Everyone's flashlight burns the ghosts in its beam.
func _flashlights() -> void:
	if not world.arena.flashlights:
		return
	var space := get_world_3d().direct_space_state
	for pl: Player in world.players.values():
		if not pl.is_alive() or (pl.flags & Player.F_TORCH_OFF) != 0:
			continue
		var eye := pl.eye_position()
		var aim := pl.aim_direction()
		for m: Monster in _near(eye + aim * LIGHT_RANGE * 0.5, LIGHT_RANGE * 0.5 + 1.0):
			if not m.def.has("ghost"):
				continue
			var c := m.pos + Vector3.UP * 1.2
			var to := c - eye
			var d := to.length()
			if d > LIGHT_RANGE or d < 0.1 or aim.dot(to / d) < LIGHT_COS:
				continue
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, c, Game.L_WORLD)).is_empty():
				continue
			_hit(m, LIGHT_BURN * 0.1, Vector3.ZERO, pl.player_id, "light")


## Props flung into them: crushed (and sent flying), the prop slowed a little.
func _props_hit(now: float) -> void:
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.freeze or p.held_by != 0:
			continue
		var v := p.linear_velocity
		var speed := v.length()
		if speed < 6.0:
			continue
		var r := maxf(p.size.x, maxf(p.size.y, p.size.z)) * 0.5 + 0.4
		var at := p.global_position
		for m: Monster in _near(at, r + 1.0):
			if m.state == State.HELD:
				continue
			var low := m.pos.y
			var top := m.pos.y + HEIGHT * float(m.def.size)
			var closest := Vector3(m.pos.x, clampf(at.y, low, top), m.pos.z)
			if closest.distance_to(at) > r + float(m.def.radius) - 0.38:
				continue
			var key := "%d:%d" % [m.id, p.prop_id]
			if now - float(_prop_hits.get(key, -10.0)) < 0.4:
				continue
			_prop_hits[key] = now
			var energy := 0.5 * p.mass * speed * speed
			var attacker: int = p.last_thrower if now - p.last_thrown_time < 6.0 else 0
			_hit(m, clampf(energy / 30.0, 6.0, 500.0), v * 0.6 + Vector3.UP * 4.0, attacker, "crushed")
			if world.is_burning(p):
				_ignite(m, 5.0, attacker)
			p.linear_velocity = v * (0.85 if m.kind != "brute" else 0.4)
	if _prop_hits.size() > 2000:
		_prop_hits.clear()


## Monsters next to a Yeet hit them (a brute sends them flying; a bomber goes off).
func _bite_players(_now: float) -> void:
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var pp := pl.global_position
		for m: Monster in _near(pp, 1.8):
			if m.state != State.WALK or m.attack_cd > 0.0:
				continue
			var to := pp - m.pos
			var reach := 1.1 + float(m.def.radius) - 0.38
			if Vector2(to.x, to.z).length() > reach or absf(to.y) > 1.4 + (0.6 if m.def.has("ghost") else 0.0):
				continue
			if m.def.has("bomb"):
				_detonate(m)
				continue
			m.attack_cd = 1.3
			var dir := Vector3(to.x, 0, to.z).normalized()
			var bite: float = m.def.bite * (world.mode_logic.bite_scale() if world.mode_logic.has_method("bite_scale") else 1.0)
			world.server_damage_player(pl, bite, 0, "monster", pl.body_center(), dir)
			if pl.is_alive():
				var brute := m.kind == "brute"
				world.server_launch_player(pl, dir * (11.0 if brute else 3.5) + Vector3.UP * (5.0 if brute else 1.5), false, 0.8 if brute else 0.0, 0)


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


func _flags(m: Monster) -> int:
	var flying := m.state == State.FLY or m.state == State.HELD
	return (1 if flying else 0) | (2 if m.flash > 0.3 else 0) | (int(m.walk * 7.0) << 2) | (32 if m.burn > 0.0 else 0) | (64 if m.state == State.CLIMB else 0)


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
		buf.encode_u8(o + 9, _flags(m))
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


## Where a monster is now (the gun's beam to one it holds): INF when it's gone.
func monster_point(id: int) -> Vector3:
	if is_server():
		var m := get_monster(id)
		return m.pos + Vector3.UP * 0.9 if m else Vector3.INF
	return (_views[id][0] as Vector3) + Vector3.UP * 0.9 if _views.has(id) else Vector3.INF


## Deaths: [id, x, y, z, vx, vy, vz, cause + kind * 32] each (every peer).
func apply_deaths(buf: PackedFloat32Array) -> void:
	var i := 0
	while i + 7 < buf.size():
		var id := int(buf[i])
		var pos := Vector3(buf[i + 1], buf[i + 2], buf[i + 3])
		var vel := Vector3(buf[i + 4], buf[i + 5], buf[i + 6])
		var code := int(buf[i + 7])
		var cause := code % 32
		var kind: String = KIND_IDS[clampi(code / 32, 0, KIND_IDS.size() - 1)]
		var yaw := 0.0
		if _views.has(id):
			pos = _views[id][0]
			yaw = _views[id][3]
			_views.erase(id)
		_death_fx(pos, vel, yaw, cause, kind)
		i += 8


func _process(delta: float) -> void:
	var counts := {}
	for kind in KIND_IDS:
		counts[kind] = 0
	var t := Time.get_ticks_msec() / 1000.0
	_flames_t -= delta
	var flames := _flames_t <= 0.0
	if flames:
		_flames_t = 0.2
	var lit := 0
	if is_server():
		for m in monsters:
			var k: int = counts[m.kind]
			if k >= MAX_DRAWN:
				continue
			_put(_draw[m.kind][1], k, m.pos, m.yaw, m.id, m.walk, m.flash, m.state == State.FLY or m.state == State.HELD, m.def.size)
			counts[m.kind] = k + 1
			if flames and m.burn > 0.0 and lit < 30:
				lit += 1
				_flame(m.pos, m.def.size)
	else:
		var gone := []
		for id in _views:
			var v: Array = _views[id]
			var age := t - float(v[5])
			if age > 1.5:
				gone.append(id)
				continue
			var aim: Vector3 = v[1] + v[2] * minf(age, 0.15)
			v[0] = (v[0] as Vector3).lerp(aim, 1.0 - exp(-14.0 * delta))
			var kind: String = KIND_IDS[clampi(v[6], 0, KIND_IDS.size() - 1)]
			var k: int = counts[kind]
			if k >= MAX_DRAWN:
				continue
			var flags: int = v[4]
			var size: float = KINDS[kind].size
			_put(_draw[kind][1], k, v[0], v[3], id, ((flags >> 2) & 7) / 7.0, 1.0 if flags & 2 else 0.0, flags & 1 != 0, size)
			counts[kind] = k + 1
			if flames and flags & 32 and lit < 30:
				lit += 1
				_flame(v[0], size)
		for id in gone:
			_views.erase(id)
	for kind in KIND_IDS:
		var mm: MultiMesh = _draw[kind][0].multimesh
		var n: int = counts[kind]
		if n > 0:
			mm.buffer = _draw[kind][1] # (all at once; past the count they're hidden)
		mm.visible_instance_count = n
	_groans(delta)


func _flame(pos: Vector3, size: float) -> void:
	world.fx.puffs(pos + Vector3.UP * 1.1 * size, Vector3.UP, 2, [Color(1.0, 0.6, 0.15, 0.9), Color(1.0, 0.25, 0.05, 0.5), Color(0.2, 0.2, 0.2, 0.0)], 0.25 * size, 0.5 * size, 1.0, 2.2, 0.55, 30.0, Vector3(0, 2.0, 0), 1.0, 1.0, 0.3)


func _put(buf: PackedFloat32Array, k: int, pos: Vector3, yaw: float, id: int, walk: float, flash: float, flying: bool, size: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	if flying:
		b = b * Basis(Vector3.RIGHT, sin(Time.get_ticks_msec() * 0.006 + id) * 0.9)
	b = b.scaled(Vector3.ONE * size)
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


## What's left when one dies: a body that tumbles and sinks away (a few dozen at most), or
## smoke (lava, acid), a flash (into the Heart), wisps (a ghost); a bomber's blast is its own.
func _death_fx(pos: Vector3, vel: Vector3, yaw: float, cause: int, kind: String) -> void:
	if cause == 10: # (into the Heart: swallowed in a flash)
		world.fx.puffs(pos + Vector3.UP, Vector3.UP, 10, [Color(1.0, 0.3, 0.2, 0.8), Color(0.6, 0.1, 0.1, 0.0)], 0.3, 0.7, 1.0, 3.0, 1.0)
		return
	if kind == "ghost":
		world.fx.puffs(pos + Vector3.UP * 1.2, Vector3.UP, 14, [Color(0.8, 0.95, 1.0, 0.7), Color(0.5, 0.8, 1.0, 0.0)], 0.3, 0.8, 1.0, 3.0, 1.2)
		Sfx.play3d("whoosh", pos + Vector3.UP, -2.0, 1.6)
		return
	if cause == 5 or cause == 6: # (lava, acid: nothing left)
		world.fx.puffs(pos + Vector3.UP, Vector3.UP, 8, [Color(0.3, 0.3, 0.3, 0.7), Color(0.2, 0.2, 0.2, 0.0)], 0.4, 0.9, 1.0, 2.5, 1.6)
		Sfx.play3d("sizzle", pos, 0.0, randf_range(0.8, 1.0))
		return
	if kind == "bomber":
		return # (the blast says it all)
	var size: float = KINDS[kind].size
	if Game.gore_level > 0:
		world.fx.blood(pos + Vector3.UP * size, Vector3.UP, vel.normalized() if vel.length() > 0.1 else Vector3.UP, 0.6 * size)
	else:
		world.fx.confetti(pos + Vector3.UP * size, Vector3.UP, 0.6)
	Sfx.play3d("metal" if kind == "climber" else "smack", pos + Vector3.UP, -2.0, randf_range(0.7, 0.9) / size)
	while _corpses.size() >= MAX_CORPSES:
		var old: Node3D = _corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var rb := RigidBody3D.new()
	rb.collision_layer = Game.L_LIMBS
	rb.collision_mask = Game.L_WORLD | Game.L_LIMBS
	rb.mass = 40.0 * size * size
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 1.7, 0.4) * size
	cs.shape = sh
	cs.position.y = 0.85 * size
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = MonsterLook.mesh(kind)
	mi.material_override = MonsterLook.material(kind)
	mi.scale = Vector3.ONE * size
	if cause == 12: # (burnt: charred)
		mi.transparency = 0.0
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.12, 0.1, 0.09)
		dark.roughness = 1.0
		mi.material_override = dark
	rb.add_child(mi)
	add_child(rb)
	rb.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	rb.linear_velocity = vel + Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1))
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4)) + Vector3(-3, 0, 0)
	_corpses.append(rb)
	var tw := rb.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(mi, "scale", Vector3(size, 0.05, size), 0.8)
	tw.tween_callback(func():
		_corpses.erase(rb)
		rb.queue_free())
