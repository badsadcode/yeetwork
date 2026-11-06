@tool
class_name Encounter
extends PuzzleNode
## A set-piece fight, for the Adventure and Puzzle modes. When its Inputs come on (with none, as
## the level starts) its rifts (MonsterSpawn) open and its Waves come through, each once the one
## before is dead. On once they're all dead, so it can open the way on.
##
## If everyone's down at once, they're all back at the last checkpoint and it starts again: a
## StoryZone that set it off can be walked into again (and a door it slammed opens again). If its
## Inputs are still on, it starts again by itself after Restart After.
##
## One fight at a time: another whose Inputs come on waits for this one to end.

## What comes, in order (New EncounterWave for each).
@export var waves: Array[EncounterWave] = []
## The MonsterSpawns they come through. Empty: every rift on the map. They only walk on ground from
## about the height of these and the Goal upward, so a fight can be up on a shelf or a balcony:
## one knocked off falls (hard), and doesn't climb back.
@export var rifts: Array[NodePath] = []
## Where they head for until a Yeet's near: any node (a Marker3D). Empty: they hunt the Yeets,
## wherever they go.
@export var goal: NodePath
## Seconds from its Inputs coming on to the first monster.
@export_range(0.0, 60.0, 0.1) var start_delay := 1.0
## Seconds between one wave dying and the next coming.
@export_range(0.0, 60.0, 0.5) var wave_gap := 3.0
## How close a Yeet they can see has to be before they go straight for them, metres.
@export_range(2.0, 60.0, 0.5) var chase_range := 12.0
## The most monsters at once (the rest of a wave waits for room). Mind the Steam Deck.
@export_range(5, 200, 5) var max_at_once := 40
## Seconds a fallen Yeet is out of it while the fight's on (back at the checkpoint after that).
@export_range(3.0, 120.0, 1.0) var respawn_after := 15.0
## Seconds after everyone's fallen before it can start again.
@export_range(1.0, 120.0, 1.0) var restart_after := 5.0

const HUNT_EVERY := 1.0 # (how often the monsters' way is worked out again as the Yeets move)
const MARGIN := 25.0 # (metres of ground round the rifts, the goal and the Yeets that they can use)
const BELOW_RIFTS := 2.0 # (how far below its rifts or its Goal the fight's ground goes)

var wave := 0 # (server: which one's on, from 1)
var boss # (server: Horde.Monster, while it lives)
var _won := false
var _running := false
var _rest_until := 0.0
var _next_at := 0.0 # (when the next wave's due, or the first)
var _waiting_wave := true
var _to_spawn: Array[String] = []
var _gap := 0.5
var _spawn_t := 0.0
var _spawn_i := 0
var _spots: Array[MonsterSpawn] = []
var _hunt_t := 0.0
var _seen := {}
var _open_wave := -1 # (every peer: which wave's rifts are showing, -1 none)
var _marker: MeshInstance3D


func _ready() -> void:
	_rebuild()


func evaluate() -> bool:
	return _won


func running() -> bool:
	return _running


## Server: its Inputs are on (or it has none), it isn't won and it isn't resting.
func wants_to_start(now: float) -> bool:
	return not _won and not _running and now >= _rest_until and not waves.is_empty() and (inputs.is_empty() or inputs_on())


## Every monster type its waves bring (for the Horde to know them, on every peer).
func own_types() -> Array[MonsterType]:
	var out: Array[MonsterType] = []
	for w in waves:
		if w:
			for t in w.own_monsters:
				if t and not out.has(t):
					out.append(t)
	return out


## Server: off it goes. The monsters' map of the ground is made now, with the doors as they are.
func server_begin() -> void:
	var h: Horde = world.horde
	_spots.clear()
	for np in rifts:
		var s := get_node_or_null(np) as MonsterSpawn
		if s:
			_spots.append(s)
	if _spots.is_empty():
		_spots = world.arena.monster_spawns.duplicate()
	var target := _goal_node()
	var at: Vector3 = target.global_position if target else _first_yeet()
	var f := FlowField.new()
	var t0 := Time.get_ticks_msec()
	var bounds := _ground_rect(at)
	# (only ground from the rifts' height upward: on a shelf, the room's floor below isn't theirs,
	# and one knocked off falls)
	var low := at.y if target else INF
	var high := at.y
	for s in _spots:
		low = minf(low, s.global_position.y)
		high = maxf(high, s.global_position.y)
	if low == INF:
		low = at.y
	f.build(world.get_world_3d().direct_space_state, bounds, low - BELOW_RIFTS, high + 40.0, at, 1.5)
	print("Encounter %s: the ground over %d x %d cells in %d ms" % [name, f.nx, f.nz, Time.get_ticks_msec() - t0])
	h.begin_fight(f, at, chase_range)
	_running = true
	wave = 0
	boss = null
	_to_spawn.clear()
	_waiting_wave = true
	_next_at = world.now() + start_delay
	_hunt_t = 0.0
	world.server_fx("horn", global_position, Vector3.UP, 1.0)


## Server, every tick of the fight: true once it's won.
func server_tick(delta: float) -> bool:
	var h: Horde = world.horde
	_hunt(delta, h)
	if _waiting_wave:
		if world.now() >= _next_at:
			_start_wave(h)
		return false
	_spawn(delta, h)
	if _to_spawn.is_empty() and h.count() == 0:
		if wave >= waves.size():
			_running = false
			_won = true
			boss = null
			return true
		_waiting_wave = true
		_next_at = world.now() + wave_gap
	return false


## Server: everyone fell. The monsters go; ready to start again, a zone that set it off too.
func server_reset() -> void:
	world.horde.server_clear()
	_running = false
	boss = null
	_to_spawn.clear()
	wave = 0
	_rest_until = world.now() + restart_after
	_rearm(self, {})


## The StoryZones that set this off, through any logic in between, can be walked into again.
func _rearm(n: PuzzleNode, seen: Dictionary) -> void:
	seen[n] = true
	for np in n.inputs:
		var q := n.get_node_or_null(np) as PuzzleNode
		if q == null or seen.has(q):
			continue
		if q is StoryZone:
			(q as StoryZone).rearm()
		_rearm(q, seen)


func _start_wave(h: Horde) -> void:
	_waiting_wave = false
	wave += 1
	var w: EncounterWave = waves[wave - 1]
	_to_spawn = w.plan(h.kind_of_type)
	_to_spawn.shuffle()
	_gap = w.spawn_gap
	_spawn_t = 0.0
	if waves.size() > 1:
		world.server_message("Wave %d of %d" % [wave, waves.size()], Color(1.0, 0.45, 0.3), true)
	if w.boss != "none" and Horde.BOSSES.has(w.boss) and not _spots.is_empty():
		var info: Dictionary = Horde.BOSSES[w.boss]
		var m = h.server_spawn(_spots[0].spot(world.rng), w.boss)
		m.max_hp = w.boss_health * float(info.health) * (1.0 + 0.35 * maxi(world.players.size() - 1, 0))
		m.hp = m.max_hp
		boss = m
		world.server_message("%s!\n%s" % [info.name, info.hint], Color(1.0, 0.35, 0.2), true)
		world.server_fx("horn", global_position, Vector3.UP, 1.0)


func _spawn(delta: float, h: Horde) -> void:
	if _spots.is_empty():
		_to_spawn.clear() # (nowhere for them to come from: the map check says so too)
		return
	_spawn_t -= delta
	while _spawn_t <= 0.0 and not _to_spawn.is_empty() and h.count() < max_at_once:
		_spawn_t += _gap
		var at := Vector3.ZERO
		var found := false
		for k in _spots.size():
			_spawn_i = (_spawn_i + 1) % _spots.size()
			var s := _spots[_spawn_i]
			if s.from_wave <= wave:
				at = s.spot(world.rng)
				found = true
				break
		if not found:
			at = _spots[0].spot(world.rng)
		var kind: String = _to_spawn.pop_back()
		h.server_spawn(at, kind)
		if not _seen.has(kind) and (ModeMegaYeet.ANNOUNCE.has(kind) or h.types.has(kind)):
			_seen[kind] = true
			var text: String = ModeMegaYeet.ANNOUNCE[kind] if ModeMegaYeet.ANNOUNCE.has(kind) else h.announcement(kind)
			if kind == "ghost":
				text = text % Controls.key_of("flashlight")
			world.server_message(text, Color(1.0, 0.55, 0.3), true)


## No Goal: every second, the monsters' way leads to wherever the living Yeets are now.
func _hunt(delta: float, h: Horde) -> void:
	if _goal_node() != null:
		return
	_hunt_t -= delta
	if _hunt_t > 0.0:
		return
	_hunt_t = HUNT_EVERY
	var points: Array[Vector3] = []
	for pl: Player in world.players.values():
		if pl.is_alive():
			points.append(pl.global_position)
	if not points.is_empty():
		h.aim_at(points)


func _goal_node() -> Node3D:
	return get_node_or_null(goal) as Node3D if not goal.is_empty() else null


func _first_yeet() -> Vector3:
	for pl: Player in world.players.values():
		if pl.is_alive():
			return pl.global_position
	return global_position


## The ground the fight can use: round the rifts, the goal, this piece and every Yeet.
func _ground_rect(at: Vector3) -> Rect2:
	var r := Rect2(Vector2(at.x, at.z), Vector2.ZERO).expand(Vector2(global_position.x, global_position.z))
	for s in _spots:
		r = r.expand(Vector2(s.global_position.x, s.global_position.z))
	for pl: Player in world.players.values():
		r = r.expand(Vector2(pl.global_position.x, pl.global_position.z))
	return r.grow(MARGIN)


## Every peer: its rifts open while it's running, from the wave they open at (World's mode state).
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or world == null:
		return
	var s: Dictionary = world.mode_state
	var now_wave: int = int(s.get("wave", 0)) if int(s.get("fight", -1)) == puzzle_index else -1
	if now_wave == _open_wave:
		return
	var was := _open_wave
	_open_wave = now_wave
	for sp in _rift_nodes():
		var on: bool = now_wave >= 0 and sp.from_wave <= maxi(now_wave, 1)
		if on != sp.visible:
			sp.visible = on
			if on:
				world.fx.zap(sp.global_position + Vector3.UP * 0.5)
			elif was >= 0:
				world.fx.puff(sp.global_position + Vector3.UP * 0.2, Vector3.UP)


func _rift_nodes() -> Array:
	var out := []
	for np in rifts:
		var s := get_node_or_null(np) as MonsterSpawn
		if s:
			out.append(s)
	if out.is_empty() and world and world.arena:
		out = world.arena.monster_spawns.duplicate()
	return out


func problems() -> Array[String]:
	var out := super.problems()
	if waves.is_empty():
		out.append("%s: it has no waves." % name)
	for i in waves.size():
		if waves[i] == null or waves[i].total() == 0:
			out.append("%s: wave %d brings nothing." % [name, i + 1])
	for np in rifts:
		if not get_node_or_null(np) is MonsterSpawn:
			out.append("%s: rift %s is not a MonsterSpawn." % [name, np])
	if not goal.is_empty() and not get_node_or_null(goal) is Node3D:
		out.append("%s: its goal %s is not a place." % [name, goal])
	if rifts.is_empty():
		var top: Node = owner if owner else get_parent()
		if top and top.find_children("*", "MonsterSpawn", true, false).is_empty():
			out.append("%s: there's no MonsterSpawn on the map for them to come through." % name)
	return out


## In the editor only: where it is.
func _rebuild() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint():
		return
	if _marker:
		_marker.queue_free()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.3, 0.2, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker = PuzzleNode.box_mesh(Vector3(1, 1, 1), m, Vector3(0, 0.5, 0))
	add_child(_marker, false, Node.INTERNAL_MODE_FRONT)
