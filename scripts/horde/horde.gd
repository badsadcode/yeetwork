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
## - golem (the boss, ModeMegaYeet's boss waves): three times a Yeet's height; gates crumble
##   under it; pushes, grabs, falls and water do nothing; it stomps (Yeets near it go flying,
##   its own minions get flattened), hurls boulders at anyone up on the walls (real props:
##   throw them back), and now and then calls a pack out of the ground round it. Blasts,
##   fire and heavy things hurt it: the iron ball most of all.
## - ram (the other boss, taking turns with the golem: the Heart's Bosses): picks a Yeet it can
##   see, paws the ground, and charges in a straight line, smashing gates, scattering props,
##   bowling over its own and flinging any Yeet in the way. Into something solid, it's dazed
##   for a while, and everything hurts it double. Otherwise as the golem: pushes, grabs, falls
##   and water do nothing.
## Monsters of your own (MonsterType, on the map's FortressHeart) join them as kinds of their
## own (kind_ids: the built-in ones, then the map's, the same on every peer: they all load
## the same map), behaving like the built-in kind they pick; a map theme's monster slots give
## the built-in kinds new looks (MonsterLook.from_model).
## An Encounter (the Adventure and Puzzle modes) runs them too (begin_fight): they go for its Goal,
## or hunt the Yeets, reaching it doesn't use them up, and they only chase a Yeet they can see.
## Every peer draws them from compact snapshots (10 a second, 12 bytes a monster) in one
## MultiMesh per kind, the shader making them shamble; deaths go out reliably (a tumbling
## body). World holds the RPCs (_s_horde, _s_horde_deaths) and calls in here.

const SNAP_RATE := 0.1
const PER_PACKET := 90
const MAX_DRAWN := 600
const MAX_CORPSES := 40
const MAX_CORPSES_LOW := 16 # (the Low graphics preset: the Steam Deck)
const BURST_BODIES := 5 # (deaths at once that get a body: the rest of a blast's just go up in dust)
const BURST_BODIES_LOW := 2
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
	# The boss: hp is ModeMegaYeet's to set (how many Yeets, which time it comes).
	"golem": {"hp": 3000.0, "speed": 1.0, "bite": 30.0, "bash": 400.0, "knock": 0.0, "grab": false, "size": 3.0, "radius": 1.5, "burn": 0.5, "boss": true},
	"ram": {"hp": 2250.0, "speed": 1.4, "bite": 26.0, "bash": 320.0, "knock": 0.0, "grab": false, "size": 2.4, "radius": 1.2, "burn": 0.5, "boss": true, "charges": true},
}
const KIND_IDS := ["shambler", "runner", "brute", "ghost", "climber", "bomber", "golem", "ram"]
## A MonsterType's kind id: CUSTOM and its place in the Heart's list ("custom0").
const CUSTOM := "custom"
## The bosses: the name on the HUD, what its wave says, its health against the Heart's Boss
## Health. Boss waves take turns through the Heart's Bosses.
const BOSSES := {
	"golem": {"name": "THE SIEGE GOLEM", "hint": "Blast it, burn it, throw the iron ball at it", "health": 1.0},
	"ram": {"name": "THE WRECKING RAM", "hint": "Dodge its charge: into a wall, it's dazed and hurts double", "health": 0.75},
}
const WINDUP_TIME := 1.3 # (the ram paws the ground, turning to its Yeet...)
const AIM_LOCK := 0.35 # (...for all but the end of that: time to dodge)
const CHARGE_SPEED := 13.0
const CHARGE_TIME := 3.0 # (the longest it runs)
const CHARGE_EVERY := 7.0
const CHARGE_DAMAGE := 30.0
const DAZE_TIME := 5.0
const DAZE_HURTS := 2.0
const RESCAN_CELLS := 60 # (an Encounter's map of the ground, looked at again, a physics tick)
const LOST_AFTER := 30.0
const CAUSES := ["", "punt", "blast", "crushed", "fall", "lava", "acid", "drowned", "bowled", "wall", "heart", "hit", "fire", "light", "bomb", "spikes"]

enum State { WALK, FLY, STUN, CLIMB, HELD, WINDUP, CHARGE }


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
	var slow_to := 0.4 # (how fast it goes while slowed)
	var stomp_cd := 3.0 # (the boss's: stomp, throw, call)
	var throw_cd := 5.0
	var call_cd := 12.0
	var charge_cd := 4.0 # (the ram's)
	var windup := 0.0
	var charge_left := 0.0
	var charge_dir := Vector3.FORWARD
	var charge_at: Player
	var charge_hits := {} # (the Yeets this charge has flung)
	var smash_cd := 0.0
	var daze := 0.0
	var lost := 0.0 # (an Encounter's: seconds with no way to go)


var world: Node
var field: FlowField
var bot_field := BotField.new() # (the bots' map to the monsters: BotField)
var _bot_field_t := 0.0
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
var _boulders: Array[int] = [] # (the boss's, the oldest cleared past a few)
var _trap_t := 0.0
# Every peer's view of them: id -> [pos, target, vel, yaw, flags, seen, kind]
var _views := {}
var _draw := {} # kind -> [MultiMeshInstance3D, buffer]
var _corpses: Array[Node3D] = []
var _groan_t := 2.0
var _flames_t := 0.0
## This map's kinds: the built-in ones, then its own (MonsterTypes); each one's numbers and
## what it does (KINDS', with "like": the built-in kind it behaves like), its model of your
## own (a MonsterType's, a theme's slot) and its MonsterType.
var kind_ids: Array = KIND_IDS.duplicate()
var defs := {}
var _models := {} # kind -> PackedScene
var types := {} # kind -> MonsterType
var _warm_spot := Vector3.ZERO
var _warm_t := 0.0
var fight := false # (an Encounter's on, or has been: no Heart here)
var _chase_range := 0.0 # (a fight's: how near a Yeet it can see gets chased)


func _ready() -> void:
	_setup_kinds()
	for kind in kind_ids:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh_of(kind)
		mm.instance_count = MAX_DRAWN
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = _material_of(kind)
		mmi.extra_cull_margin = 4096.0 # (they're everywhere: one big box)
		if defs[kind].has("ghost"):
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


## The built-in kinds (with the map theme's monster slots), then the map's MonsterTypes.
func _setup_kinds() -> void:
	var theme: MapTheme = MapTheme.of(world.arena) if world and world.arena else null
	for k in KIND_IDS:
		defs[k] = KINDS[k].duplicate()
		defs[k].like = k
		defs[k].name = k
		var slot := theme.monster_model(k) if theme else null
		if slot:
			_models[k] = slot
	var own := _own_types()
	for i in own.size():
		var t: MonsterType = own[i]
		if t == null:
			continue
		var k := CUSTOM + str(i)
		kind_ids.append(k)
		types[k] = t
		defs[k] = t.def()
		if t.model:
			_models[k] = t.model


## The map's own monsters, in the same order on every peer: the Heart's in MegaYeet, else what
## its Encounters bring.
func _own_types() -> Array[MonsterType]:
	var out: Array[MonsterType] = []
	if world == null or world.arena == null:
		return out
	if world.mode == Game.Mode.MEGAYEET:
		return world.arena.heart.monster_types if world.arena.heart else out
	for n in world.arena.puzzle:
		if n is Encounter:
			for t in (n as Encounter).own_types():
				if not out.has(t):
					out.append(t)
	return out


## The kind name of one of the map's own monsters.
func kind_of_type(t: MonsterType) -> String:
	for k in types:
		if types[k] == t:
			return k
	return "shambler"


## An Encounter starts: the monsters use this map of the ground, heading for this point, and go
## for any Yeet in sight within reach. Reaching the point doesn't use them up.
func begin_fight(f: FlowField, at: Vector3, chase_range: float) -> void:
	if field:
		field.finish()
	field = f
	_heart = at
	_heart_r = 1.5
	_chase_range = chase_range
	fight = true


## No Goal: the way leads to wherever the Yeets are (FlowField.aim_at); ghosts and climbers,
## going straight, head for the first.
func aim_at(points: Array[Vector3]) -> void:
	if field == null or points.is_empty():
		return
	_heart = points[0]
	field.aim_at(points)


## A kind's mesh: its model of your own, else the built-in look (of the kind it behaves like).
## The warm-up (Effects.warm_up): one of each kind drawn here for a moment.
func warm_at(p: Vector3) -> void:
	_warm_spot = p
	_warm_t = 0.6


func mesh_of(kind: String) -> Mesh:
	if _models.has(kind):
		return MonsterLook.from_model(_models[kind], defs[kind].has("ghost"))
	return MonsterLook.mesh(defs[kind].like)


## (null for a model of your own: its surfaces carry their own materials)
func _material_of(kind: String) -> Material:
	return null if _models.has(kind) else MonsterLook.material(defs[kind].like)


## What the wave announces the first time a kind comes ("" for none).
func announcement(kind: String) -> String:
	return (types[kind] as MonsterType).announcement() if types.has(kind) else ""


func _exit_tree() -> void:
	if field:
		field.finish()
	bot_field.finish()


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
	m.def = defs[kind]
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


## The bots' map (BotField), from every monster: those nearer the Heart pull harder (their
## head start is half their own way left to the Heart); round the big props lying about.
func _update_bot_field() -> void:
	var sources := {}
	for m in monsters:
		var c := BotField.standable(field, m.pos)
		if c < 0:
			continue
		var here := field.cell_of(m.pos)
		var start: int = (field.dist[here] / 2) if here >= 0 and field.dist[here] < FlowField.INF_COST else 2000
		if not sources.has(c) or start < int(sources[c]):
			sources[c] = start
	if sources.is_empty(): # (no monsters about: the way back to the Heart, round the walls)
		for c in field.targets:
			sources[c] = 0
	bot_field.update(field, world.arena.jump_links, sources, _prop_cells())


## The cells big props stand on (crates, an iron ball): bots go round them, not over (one
## that walks into one ends up on top of it, or rolling it about).
func _prop_cells() -> Dictionary:
	var out := {}
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0 or p.lift_count > 0:
			continue
		var r := maxf(p.size.x, maxf(p.size.y, p.size.z)) * (1.0 if p.kind == "iron_ball" else 0.5)
		if r < 0.45 or p.linear_velocity.length() > 2.0:
			continue
		var c := p.global_position
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var q := field.cell_of(c + Vector3(dx, 0, dz) * 0.7)
				if q >= 0 and Vector2(dx, dz).length() * 0.7 <= r + 0.4:
					out[q] = true
	return out


## A gate was repaired: look at the ways to the Heart again in a moment (once its wall's
## collision is back in the physics world).
func request_gate_refresh() -> void:
	_gates_hit = true
	_gate_t = 0.3


func server_clear() -> void:
	for m in monsters: # (gone in a flash, no bodies)
		_deaths.append_array([m.id, m.pos.x, m.pos.y, m.pos.z, 0.0, 0.0, 0.0, float(10 + kind_ids.find(m.kind) * 32)])
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
	if m.def.has("boss") and cause in ["fall", "bowled", "wall", "light", "drowned"]:
		return # (it doesn't care)
	if m.daze > 0.0:
		amount *= DAZE_HURTS
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
	_deaths.append_array([m.id, m.pos.x, m.pos.y, m.pos.z, m.vel.x, m.vel.y, m.vel.z, float(code + kind_ids.find(m.kind) * 32)])
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
		if m.daze > 0.0:
			m.daze -= delta
			if fmod(m.daze, 0.5) < 0.2: # (it blinks: now's the time)
				m.flash = maxf(m.flash, 0.6)
		if m.burn > 0.0:
			m.burn -= delta
			_damage(m, FIRE_BURN * float(m.def.burn) * delta, "fire")
			if m.hp <= 0.0:
				continue
		if m.def.has("boss") and m.state == State.WALK:
			_boss(m, delta)
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
			State.WINDUP:
				_windup(m, delta)
			State.CHARGE:
				_charge(m, delta)
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
	bot_field.poll()
	_bot_field_t -= delta
	if _bot_field_t <= 0.0:
		_bot_field_t = 1.0
		if fight:
			_clear_the_lost()
		else:
			_update_bot_field()
	if fight and not monsters.is_empty() and field.rescan(RESCAN_CELLS):
		field.solve_async()
	if not _deaths.is_empty():
		world.server_horde_deaths(_deaths)
		_deaths = PackedFloat32Array()
	_snap_t -= delta
	if _snap_t <= 0.0:
		_snap_t = SNAP_RATE
		_send_snapshot()


## An Encounter's monster with no way to go for half a minute (shut in, flung onto a roof) goes:
## it can't be left holding up the fight for good.
func _clear_the_lost() -> void:
	for m: Monster in monsters.duplicate():
		if m.def.has("ghost") or m.state == State.FLY or m.state == State.HELD:
			continue
		if field.distance(m.pos) >= FlowField.INF_COST:
			m.lost += 1.0
			if m.lost >= LOST_AFTER:
				m.attacker = 0
				m.burn = 0.0
				_kill(m, "")
		else:
			m.lost = 0.0


func _think_chase(m: Monster, delta: float, reach: float) -> void:
	m.think -= delta
	if m.think > 0.0:
		return
	m.think = 0.5
	m.chase = null
	var best := maxf(reach, _chase_range)
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var d := pl.global_position.distance_to(m.pos)
		if d < best and absf(pl.global_position.y - m.pos.y) < 2.0 and _can_see(m, pl):
			best = d
			m.chase = pl


## In a fight, a monster only goes straight for a Yeet it can see (the way round is the map's);
## MegaYeet's never needed to ask.
func _can_see(m: Monster, pl: Player) -> bool:
	if not fight or m.def.has("ghost"):
		return true
	var q := PhysicsRayQueryParameters3D.create(m.pos + Vector3.UP * 1.0, pl.body_center(), Game.L_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


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
	var step := Vector3(dir.x, 0, dir.y) * m.speed * (0.45 if m.wet > 0.0 else 1.0) * (m.slow_to if m.slow > 0.0 else 1.0)
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
	if fight:
		return # (it's there: it waits, for a Yeet to come near)
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
	m.attack_cd = 1.6 if m.def.like == "brute" else 1.4
	var wall = field.gate_wall.get(m.bash_at)
	if wall == null or not is_instance_valid(wall):
		_gates_hit = true
		return
	var c := field.center(m.bash_at)
	var at := Vector3(c.x, field.height[m.bash_at] + 1.0, c.y)
	var dir := (at - m.pos).normalized()
	var reach := 1.8 if m.def.has("boss") else (0.9 if m.def.like == "brute" else 0.7)
	world.server_damage_destructible(wall, at, reach, m.def.bash * _up("gate_scale"), dir * 3.0, 0, 1.0)
	if m.def.like == "brute" or m.def.has("boss"):
		world.server_fx("impact:metal", at, dir * 6.0, 1.5, -dir)
	_gates_hit = true


## The boss's moves: a stomp when Yeets come close, a boulder at anyone it can see up on the
## walls (or out of reach), a pack called out of the ground now and then.
func _boss(m: Monster, delta: float) -> void:
	if m.def.has("charges"):
		_ram(m, delta)
		return
	m.stomp_cd -= delta
	m.throw_cd -= delta
	m.call_cd -= delta
	var near: Player = null
	var far: Player = null
	var far_d := 36.0
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var to := pl.global_position - m.pos
		var flat := Vector2(to.x, to.z).length()
		if flat < 6.5 and absf(to.y) < 3.5:
			near = pl
		elif (to.y > 2.5 or flat > 12.0) and flat < far_d:
			far = pl
			far_d = flat
	if near and m.stomp_cd <= 0.0:
		m.stomp_cd = 4.0
		_stomp(m)
	elif far and m.throw_cd <= 0.0:
		var from := m.pos + Vector3.UP * 4.6
		var space := get_world_3d().direct_space_state
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(from, far.body_center(), Game.L_WORLD)).is_empty():
			m.throw_cd = 7.0
			_throw_boulder(m, far)
	if m.call_cd <= 0.0:
		m.call_cd = 18.0
		for k in 5:
			var a := k * TAU / 5.0 + randf()
			server_spawn(m.pos + Vector3(cos(a), 0, sin(a)) * 3.5, "shambler")
		world.server_fx("crack", m.pos, Vector3.UP, 2.0)
		world.server_fx("horn", m.pos, Vector3.UP, 1.0)


## The ram: now and then it picks the nearest Yeet it can see on its own level (a gate doesn't
## hide them: it goes through gates) and winds up.
func _ram(m: Monster, delta: float) -> void:
	m.charge_cd -= delta
	if m.charge_cd > 0.0:
		return
	var best: Player = null
	var best_d := 30.0
	var space := get_world_3d().direct_space_state
	var from := m.pos + Vector3.UP * 2.0
	for pl: Player in world.players.values():
		if not pl.is_alive() or absf(pl.global_position.y - m.pos.y) > 3.0:
			continue
		var flat := Vector2(pl.global_position.x - m.pos.x, pl.global_position.z - m.pos.z).length()
		if flat < 4.0 or flat >= best_d:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, pl.body_center(), Game.L_WORLD))
		if hit.is_empty() or hit.collider.has_meta("destructible"):
			best = pl
			best_d = flat
	if best == null:
		m.charge_cd = 0.5
		return
	m.charge_at = best
	m.windup = WINDUP_TIME
	m.state = State.WINDUP
	world.server_fx("horn", m.pos, Vector3.UP, 1.0)


## Pawing the ground, turning to its Yeet; the last moment it's set on where it's going.
func _windup(m: Monster, delta: float) -> void:
	var before := m.windup
	m.windup -= delta
	m.walk = 0.4
	if m.charge_at and is_instance_valid(m.charge_at) and m.windup > AIM_LOCK:
		var to := m.charge_at.global_position - m.pos
		m.yaw = lerp_angle(m.yaw, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
	if int(before / 0.3) != int(m.windup / 0.3):
		world.server_fx("impact:concrete", m.pos + Vector3.UP * 0.2, Vector3.UP * 3.0, 1.0)
	if m.windup > 0.0:
		return
	m.charge_dir = Vector3(-sin(m.yaw), 0, -cos(m.yaw))
	m.charge_left = CHARGE_TIME
	m.charge_hits.clear()
	m.smash_cd = 0.0
	m.vel = m.charge_dir * CHARGE_SPEED
	m.state = State.CHARGE
	world.server_fx("throw", m.pos + Vector3.UP * 2.0, m.charge_dir, 2.0)


## Flat out, in a straight line: through gates, over whatever's in the way; into anything
## solid, it's dazed; run out of breath, it stops a moment.
func _charge(m: Monster, delta: float) -> void:
	var dir := m.charge_dir
	var reach := float(m.def.radius)
	m.walk = 1.0
	m.charge_left -= delta
	m.smash_cd -= delta
	if not fight and Vector2(_heart.x - m.pos.x, _heart.z - m.pos.z).length() < _heart_r + reach * 0.5:
		_reached(m)
		return
	var ahead := field.cell_of(m.pos + dir * (CHARGE_SPEED * delta + reach * 0.7))
	var ground: float = field.height[ahead] if ahead >= 0 else INF
	var gate: Variant = field.gate_wall.get(ahead)
	if gate != null and is_instance_valid(gate):
		if m.smash_cd <= 0.0:
			m.smash_cd = 0.25
			var at := m.pos + dir * reach + Vector3.UP * 2.0
			world.server_damage_destructible(gate, at, 2.6, m.def.bash * 3.0 * _up("gate_scale"), dir * 14.0, 0, 3.0)
			world.server_fx("impact:metal", at, dir * 6.0, 2.0, -dir)
			_gates_hit = true
	elif ahead < 0 or ground == INF or field.walk[ahead] == 0 or ground - m.pos.y > FlowField.STEP_UP * 2.0:
		_crash(m)
		return
	_trample(m, dir, reach)
	m.pos += dir * CHARGE_SPEED * delta
	var here := field.cell_of(m.pos)
	if here >= 0 and field.height[here] != INF:
		m.pos.y = move_toward(m.pos.y, field.height[here], 16.0 * delta)
	if m.charge_left <= 0.0:
		m.vel = Vector3.ZERO
		m.charge_cd = CHARGE_EVERY
		m.stun = 1.0
		m.state = State.STUN


## What a charge runs into: Yeets flung (each once a charge), its own bowled over, props
## scattered.
func _trample(m: Monster, dir: Vector3, reach: float) -> void:
	for pl: Player in world.players.values():
		if not pl.is_alive() or m.charge_hits.has(pl.player_id):
			continue
		var to := pl.global_position - m.pos
		if Vector2(to.x, to.z).length() > reach + 0.8 or absf(to.y) > 3.5:
			continue
		m.charge_hits[pl.player_id] = true
		world.server_damage_player(pl, CHARGE_DAMAGE * _up("bite_scale"), 0, "monster", pl.body_center(), dir)
		if pl.is_alive():
			world.server_launch_player(pl, dir * 20.0 + Vector3.UP * 8.0, false, 1.2, 0)
	for o: Monster in _near(m.pos, reach + 1.0):
		if o != m and not o.def.has("boss") and o.state != State.FLY:
			_hit(o, 50.0, dir * 14.0 + Vector3.UP * 6.0, 0, "bowled")
	for p: Prop in world.props.values():
		if is_instance_valid(p) and not p.freeze and p.held_by == 0 and p.linear_velocity.length() < 12.0 and p.global_position.distance_to(m.pos + Vector3.UP) < reach + 1.5:
			p.linear_velocity += dir * 16.0 + Vector3.UP * 5.0
			p.sleeping = false


## Head first into something solid: dazed, and everything hurts it double for a while.
func _crash(m: Monster) -> void:
	m.vel = Vector3.ZERO
	m.charge_cd = CHARGE_EVERY
	m.stun = DAZE_TIME
	m.daze = DAZE_TIME
	m.state = State.STUN
	var at := m.pos + m.charge_dir * float(m.def.radius) + Vector3.UP * 2.0
	world.server_fx("impact:concrete", at, -m.charge_dir * 8.0, 3.0)
	world.server_fx("crack", at, -m.charge_dir, 2.0)
	var boss_name: String = BOSSES[m.kind].name if BOSSES.has(m.kind) else "IT"
	world.server_message("%s IS DAZED!
Everything hurts it double" % boss_name, Color(1.0, 0.85, 0.3), true)


## A team upgrade's effect (ModeMegaYeet's): how much of something to apply.
func _up(method: String) -> float:
	return float(world.mode_logic.call(method)) if world.mode_logic and world.mode_logic.has_method(method) else 1.0


## The ground shakes: Yeets near it go flying, its own minions get flattened, things fly.
func _stomp(m: Monster) -> void:
	var at := m.pos
	world.server_fx("impact:concrete", at + Vector3.UP * 0.2, Vector3.UP * 6.0, 3.0)
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var to := pl.global_position - at
		var d := Vector2(to.x, to.z).length()
		if d > 7.0 or absf(to.y) > 3.5:
			continue
		var away := Vector3(to.x, 0, to.z).normalized() if d > 0.1 else Vector3.FORWARD
		world.server_damage_player(pl, 15.0, 0, "monster", pl.body_center(), away)
		if pl.is_alive():
			world.server_launch_player(pl, away * 12.0 + Vector3.UP * 7.0, false, 1.0, 0)
	for o: Monster in _near(at, 5.0):
		if o == m or o.def.has("boss"):
			continue
		var away := o.pos - at
		away.y = 0.0
		_hit(o, 25.0, away.normalized() * 10.0 + Vector3.UP * 6.0, 0, "bowled")
	for p: Prop in world.props.values():
		if is_instance_valid(p) and not p.freeze and p.held_by == 0 and p.global_position.distance_to(at) < 7.0:
			var away := p.global_position - at
			away.y = 0.0
			p.linear_velocity += away.normalized() * 8.0 + Vector3.UP * 6.0
			p.sleeping = false


## A boulder lobbed at a Yeet (a real prop: it can be caught and thrown back).
func _throw_boulder(m: Monster, pl: Player) -> void:
	var dir := pl.global_position - m.pos
	m.yaw = atan2(-dir.x, -dir.z)
	var from := m.pos + Vector3.UP * 4.6 + Vector3(dir.x, 0, dir.z).normalized() * 1.2
	var target := pl.body_center() + pl.velocity * 0.4
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
	var t := clampf(from.distance_to(target) / 20.0, 0.5, 1.6)
	var vel := (target - from) / t + Vector3.UP * 0.5 * g * t
	var rock: Prop = world.server_spawn_prop("boulder", Transform3D(Basis.IDENTITY, from), Vector3.ZERO, Color(0, 0, 0, 0), 0, vel)
	if rock:
		_boulders.append(rock.prop_id)
		while _boulders.size() > 6:
			var old: Prop = world.get_prop(_boulders.pop_front())
			if old and old.held_by == 0:
				world.server_despawn_prop(old)
	world.server_fx("throw", from, vel.normalized(), 2.0)


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
	if fight:
		var g := field.ground(m.pos)
		if g == INF or g > m.pos.y + 2.0: # (knocked off the fight's ground: out of it)
			m.attacker_t = world.now()
			_kill(m, "fall")
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
		if m.def.has("boss"):
			_damage(m, 80.0 * delta, liq.kind) # (it wades through, burning)
		else:
			_kill(m, liq.kind)
		return
	var depth := liq.height_at(m.pos.x, m.pos.z) - m.pos.y
	if depth > 0.4:
		m.burn = 0.0 # (water puts it out)
	if depth > 1.5 and not m.def.has("boss"):
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


## Built traps (TrapSpot) at work on the monsters in them, by their numbers (TrapSpot.stat):
## spikes hurt and slow, a fire grate sets them alight, a mine goes off under the first to
## step on it (and is gone); a trap of your own does what its numbers say. Ghosts float over
## all but fire; nothing flying or held is caught.
func _trap_tick(dt: float) -> void:
	for t in _traps:
		if not t.built:
			continue
		var c := t.global_position
		var sharper := _up("trap_scale")
		var hurt := t.stat("damage") * sharper
		var slows := t.stat("slows_to")
		var burns := t.stat("burn") * sharper
		var blast := t.stat("blast") * (1.0 + (sharper - 1.0) * 0.6)
		for m: Monster in _near(c, Vector2(t.size.x, t.size.z).length() * 0.5 + 1.0):
			if m.hp <= 0.0 or m.state == State.FLY or m.state == State.HELD:
				continue
			if m.def.has("ghost") and burns <= 0.0:
				continue
			if not t.has_point(m.pos + Vector3.UP * 0.3):
				continue
			if blast > 0.0:
				t.server_clear()
				world.server_explode_at(c + Vector3.UP * 0.5, blast, t.owner_id)
				break
			if t.owner_id != 0:
				m.attacker = t.owner_id
				m.attacker_t = world.now()
			if slows < 1.0:
				m.slow = 0.3
				m.slow_to = slows
			if hurt > 0.0:
				m.flash = maxf(m.flash, 0.5)
				_damage(m, hurt * dt, "spikes")
			if burns > 0.0:
				_ignite(m, burns, t.owner_id)


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
			var big: bool = m.def.has("boss")
			_hit(m, clampf(energy / 30.0, 6.0, 900.0 if big else 500.0), v * 0.6 + Vector3.UP * 4.0, attacker, "crushed")
			if world.is_burning(p):
				_ignite(m, 5.0, attacker)
			p.linear_velocity = v * (0.25 if big else (0.4 if m.def.like == "brute" else 0.85))
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
				var brute: bool = m.def.like == "brute" or m.def.has("boss")
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
	return (1 if flying else 0) | (2 if m.flash > 0.3 else 0) | (int(m.walk * 7.0) << 2) | (32 if m.burn > 0.0 else 0) | (64 if m.state == State.CLIMB else 0) | (128 if m.state == State.CHARGE else 0)


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
		buf.encode_u8(o + 10, kind_ids.find(m.kind))
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
	var bodies: int = BURST_BODIES_LOW if Game.graphics == 0 else BURST_BODIES
	while i + 7 < buf.size():
		var id := int(buf[i])
		var pos := Vector3(buf[i + 1], buf[i + 2], buf[i + 3])
		var vel := Vector3(buf[i + 4], buf[i + 5], buf[i + 6])
		var code := int(buf[i + 7])
		var cause := code % 32
		var kind: String = kind_ids[clampi(code / 32, 0, kind_ids.size() - 1)]
		var yaw := 0.0
		if _views.has(id):
			pos = _views[id][0]
			yaw = _views[id][3]
			_views.erase(id)
		var size: float = defs[kind].size
		if bodies > 0 or defs[kind].has("boss") or cause == 10 or defs[kind].like in ["ghost", "bomber"]:
			bodies -= 1
			_death_fx(pos, vel, yaw, cause, kind)
		else:
			world.fx.puffs(pos + Vector3.UP * size, Vector3.UP, 4, [Color(0.5, 0.45, 0.4, 0.7), Color(0.4, 0.38, 0.36, 0.0)], 0.3 * size, 0.7 * size, 1.0, 2.5, 0.7)
		i += 8


func _process(delta: float) -> void:
	var counts := {}
	for kind in kind_ids:
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
			_put(_draw[m.kind][1], k, m.pos, m.yaw, m.id, m.walk, m.flash, m.state == State.FLY or m.state == State.HELD, m.def.size, m.state == State.CHARGE)
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
			var kind: String = kind_ids[clampi(v[6], 0, kind_ids.size() - 1)]
			var k: int = counts[kind]
			if k >= MAX_DRAWN:
				continue
			var flags: int = v[4]
			var size: float = defs[kind].size
			_put(_draw[kind][1], k, v[0], v[3], id, ((flags >> 2) & 7) / 7.0, 1.0 if flags & 2 else 0.0, flags & 1 != 0, size, flags & 128 != 0)
			counts[kind] = k + 1
			if flames and flags & 32 and lit < 30:
				lit += 1
				_flame(v[0], size)
		for id in gone:
			_views.erase(id)
	for kind in kind_ids:
		var mm: MultiMesh = _draw[kind][0].multimesh
		var n: int = counts[kind]
		if _warm_t > 0.0 and n == 0:
			_put(_draw[kind][1], 0, _warm_spot, 0.0, 1, 1.0, 0.0, false, 1.0)
			n = 1
		if n > 0:
			mm.buffer = _draw[kind][1] # (all at once; past the count they're hidden)
		mm.visible_instance_count = n
	_warm_t -= delta
	_groans(delta)


func _flame(pos: Vector3, size: float) -> void:
	world.fx.puffs(pos + Vector3.UP * 1.1 * size, Vector3.UP, 2, [Color(1.0, 0.6, 0.15, 0.9), Color(1.0, 0.25, 0.05, 0.5), Color(0.2, 0.2, 0.2, 0.0)], 0.25 * size, 0.5 * size, 1.0, 2.2, 0.55, 30.0, Vector3(0, 2.0, 0), 1.0, 1.0, 0.3)


func _put(buf: PackedFloat32Array, k: int, pos: Vector3, yaw: float, id: int, walk: float, flash: float, flying: bool, size: float, charging := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	if flying:
		b = b * Basis(Vector3.RIGHT, sin(Time.get_ticks_msec() * 0.006 + id) * 0.9)
	elif charging:
		b = b * Basis(Vector3.RIGHT, -0.3) # (head down)
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
	buf[o + 15] = 1.0 if flying or charging else 0.0 # (limbs going like mad)


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
	var like: String = defs[kind].like
	if defs[kind].has("dust"):
		world.fx.dust(pos + Vector3.UP * float(defs[kind].size) * 0.5, Color(0.6, 0.58, 0.56), float(defs[kind].size))
		Sfx.play3d("whoosh", pos + Vector3.UP, -6.0, randf_range(1.3, 1.7))
		return
	if like == "ghost":
		world.fx.puffs(pos + Vector3.UP * 1.2, Vector3.UP, 14, [Color(0.8, 0.95, 1.0, 0.7), Color(0.5, 0.8, 1.0, 0.0)], 0.3, 0.8, 1.0, 3.0, 1.2)
		Sfx.play3d("whoosh", pos + Vector3.UP, -2.0, 1.6)
		return
	if cause == 5 or cause == 6: # (lava, acid: nothing left)
		world.fx.puffs(pos + Vector3.UP, Vector3.UP, 8, [Color(0.3, 0.3, 0.3, 0.7), Color(0.2, 0.2, 0.2, 0.0)], 0.4, 0.9, 1.0, 2.5, 1.6)
		Sfx.play3d("sizzle", pos, 0.0, randf_range(0.8, 1.0))
		return
	if like == "bomber":
		return # (the blast says it all)
	if defs[kind].has("boss"): # (it comes down in a cloud of rock)
		world.fx.explosion(pos + Vector3.UP * 2.5, 4.0)
		world.fx.puffs(pos + Vector3.UP * 2.0, Vector3.UP, 30, [Color(0.5, 0.48, 0.45, 0.9), Color(0.4, 0.38, 0.36, 0.0)], 1.0, 2.2, 2.0, 6.0, 2.5)
		Sfx.play3d("boom", pos, 8.0, 0.5)
	var size: float = defs[kind].size
	if Game.gore_level > 0:
		world.fx.blood(pos + Vector3.UP * size, Vector3.UP, vel.normalized() if vel.length() > 0.1 else Vector3.UP, 0.6 * size)
	else:
		world.fx.confetti(pos + Vector3.UP * size, Vector3.UP, 0.6)
	Sfx.play3d("metal" if like == "climber" else "smack", pos + Vector3.UP, -2.0, randf_range(0.7, 0.9) / size)
	while _corpses.size() >= (MAX_CORPSES_LOW if Game.graphics == 0 else MAX_CORPSES):
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
	mi.mesh = mesh_of(kind)
	mi.material_override = _material_of(kind)
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
