class_name ModeMegaYeet
extends ModeBase
## MegaYeet (co-op survival): waves of monsters come for the fortress; everyone defends it
## together (bots too). The Fortress meter is the team's life: every monster inside a zone
## drains it each second (DefenseZone: more the deeper it gets), one that reaches the Heart
## takes a bite. Kills put points back, more for a fall, a crush, a drowning or lava (style),
## and a burst of kills by one Yeet is a combo with a bonus. Clearing a wave tops it up. At
## zero the fortress falls: how many waves you held, then it all starts again (walls rebuilt,
## props back, wave 1). On a map without a FortressHeart, DefenseZones or MonsterSpawns the
## game puts a Heart amid the spawn points, rings of zones round it and rifts far out
## (prepare_arena, every peer). Waves mix the kinds of monster as they go on (KIND_MIX, brutes
## a few a wave from wave 3), each announced the first time it comes, with how to beat it.

## (fallbacks with no Heart yet; a FortressHeart sets them: its MegaYeet Rules)
const METER := 1000.0
const STYLE := ["fall", "crushed", "drowned", "lava", "acid", "bowled", "wall", "fire", "light", "bomb"]
const FIRST_BREAK := 12.0
const OVER_TIME := 12.0
const RINGS := [32.0, 18.0, 8.0] # (automatic zones' radii, outer to inner)
const COMBOS := [[3, "TRIPLE SPLAT", 10.0], [5, "MONSTER MASH", 20.0], [10, "MEGAYEET", 50.0]]
## [kind, from wave, share of the wave]; the rest are shamblers.
const KIND_MIX := [["runner", 2, 0.18], ["bomber", 2, 0.07], ["climber", 4, 0.14], ["ghost", 5, 0.1]]
const BRUTES_FROM := 3
const ANNOUNCE := {
	"runner": "RUNNERS!  Fast, but they fall apart",
	"bomber": "BOMBERS!  Keep them off the gates, or throw them into the crowd",
	"brute": "A BRUTE!  Too heavy to grab: blast it, burn it, drop it, drown it",
	"climber": "CLIMBERS!  They scale the walls",
	"ghost": "GHOSTS!  Only light and fire hurt them: shine your flashlight (%s)",
}

enum Phase { BREAK, WAVE, OVER }

var horde: Horde
var heart: FortressHeart
var meter := METER
var max_meter := METER # (the Heart's rules: health)
var wave := 0
var best := 0
var phase := Phase.BREAK
var phase_end := 0.0
var started := 0.0
var kills := 0
var heart_hits := 0
var _to_spawn := 0
var _spawn_gap := 1.0
var _spawn_t := 0.0
var _spawn_i := 0
var _drain_t := 1.0
var _state_t := 0.0
var _zone_counts := [0, 0, 0, 0]
var _alerted := [0.0, 0.0, 0.0, 0.0]
var _heart_msg := 0.0
var _combo := {} # attacker -> [count, last time]
var _spots: Array = [] # monster spawn points (MonsterSpawns, or found far out)
var _ready_to_play := false
var _seen := {} # kinds announced this game
var _spawned := 0 # this wave
var _brutes := 0 # still to come this wave
var _frames := 0


func mode_name() -> String:
	return "MegaYeet"


func setup(p_world: Node) -> void:
	super(p_world)
	horde = world.horde
	heart = world.arena.heart
	max_meter = heart.health if heart else METER
	meter = max_meter
	started = world.now()
	phase_end = world.now() + (heart.first_break if heart else FIRST_BREAK)


## Every peer: a Heart and zones if the map has none (the same everywhere: from its spawns).
static func prepare_arena(a: Arena) -> void:
	if a.heart == null:
		var pts: Array = a.spawn_points[0] + a.spawn_points[1] + a.spawn_points[2]
		var c := Vector3.ZERO
		for p: Vector3 in pts:
			c += p
		c = c / maxf(pts.size(), 1.0) if not pts.is_empty() else Vector3.ZERO
		var h := FortressHeart.new()
		h.position = c - Vector3(0, 0.2, 0) # (spawn points stand 0.2 m over the ground)
		a.add_child(h)
		a.heart = h
	a.all_flashlights = true # (light burns ghosts)
	if a.defense_zones.is_empty():
		for i in RINGS.size():
			var z := DefenseZone.new()
			z.level = i + 1
			var r: float = RINGS[i]
			z.size = Vector3(r * 2.0, 30.0, r * 2.0)
			z.position = a.heart.position - Vector3(0, 8.0, 0)
			z.show_edge = false
			a.add_child(z)
			a.defense_zones.append(z)


func is_team_mode() -> bool:
	return false


func pick_team(_players: Dictionary) -> int:
	return Game.TEAM_NONE


## Near the Heart (the map's own spawn points if it has them: they're inside the fortress).
func spawn_point(pl: Player) -> Vector3:
	var pts: Array = world.arena.spawn_points[0]
	if not pts.is_empty():
		return super(pl)
	var a: float = world.rng.randf() * TAU
	return heart.global_position + Vector3(cos(a), 0.5, sin(a)) * 4.0


## No hurting each other: monsters and the map hurt you, your friends don't.
func allow_damage(pl: Player, attacker: int, _cause: String) -> bool:
	return attacker == 0 or attacker == pl.player_id


func on_prop_hit_player(_prop: Prop, pl: Player, attacker: Player, _rel := Vector3.ZERO) -> bool:
	return attacker != null and attacker != pl # (a friend's throw: no damage)


func tick(delta: float) -> void:
	if horde == null or heart == null:
		return
	if not _ready_to_play:
		# (once the map's collision is in the physics world: the ways to the Heart)
		_frames += 1
		if _frames < 3:
			return
		_build_field()
		_ready_to_play = true
	var now: float = world.now()
	match phase:
		Phase.BREAK:
			if now >= phase_end:
				_start_wave()
		Phase.WAVE:
			_spawn(delta)
			if _to_spawn <= 0 and horde.count() == 0:
				_wave_cleared()
		Phase.OVER:
			if now >= phase_end:
				_restart()
	if phase != Phase.OVER:
		_drain_t -= delta
		if _drain_t <= 0.0:
			_drain_t = 1.0
			_drain()
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 0.5
		_send_state()


func _build_field() -> void:
	var a: Arena = world.arena
	var hp := heart.global_position
	for s: MonsterSpawn in a.monster_spawns:
		_spots.append(s)
	var bounds := Rect2(Vector2(hp.x, hp.z), Vector2.ZERO)
	for z: DefenseZone in a.defense_zones:
		var half := Vector2(z.size.x, z.size.z) * 0.5
		var c := Vector2(z.global_position.x, z.global_position.z)
		bounds = bounds.expand(c - half).expand(c + half)
	for s: MonsterSpawn in a.monster_spawns:
		bounds = bounds.expand(Vector2(s.global_position.x, s.global_position.z))
	if a.monster_spawns.is_empty():
		bounds = bounds.grow(25.0)
	bounds = bounds.grow(12.0)
	var f := FlowField.new()
	var t0 := Time.get_ticks_msec()
	f.build(world.get_world_3d().direct_space_state, bounds, hp.y - 30.0, hp.y + 40.0, hp, heart.radius)
	print("MegaYeet: ways to the Heart over %d x %d cells in %d ms" % [f.nx, f.nz, Time.get_ticks_msec() - t0])
	horde.field = f
	if _spots.is_empty():
		_spots = _far_spots(f, hp)


## No MonsterSpawns: the farthest reachable ground in six directions round the Heart.
func _far_spots(f: FlowField, hp: Vector3) -> Array:
	var best := []
	best.resize(6)
	var far := []
	far.resize(6)
	far.fill(0)
	for i in f.nx * f.nz:
		if f.walk[i] != 1 or f.dist[i] >= FlowField.INF_COST:
			continue
		var c := f.center(i)
		var to := c - Vector2(hp.x, hp.z)
		if to.length() < 22.0:
			continue
		var sector := int(fposmod(to.angle(), TAU) / TAU * 6.0) % 6
		if f.dist[i] > far[sector]:
			far[sector] = f.dist[i]
			best[sector] = Vector3(c.x, f.height[i], c.y)
	return best.filter(func(p): return p != null)


## How many monsters this wave brings (the Heart's wave size).
func _wave_count() -> int:
	return maxi(int(round((14 + wave * 10) * heart.wave_size)), 1)


func _start_wave() -> void:
	wave += 1
	phase = Phase.WAVE
	_to_spawn = _wave_count()
	_spawn_gap = (18.0 + wave * 1.5) / _to_spawn
	_spawned = 0
	_brutes = 0 if wave < BRUTES_FROM else 1 + (wave - BRUTES_FROM) / 2
	_spawn_t = 0.0
	world.server_message("WAVE %d" % wave, Color(1.0, 0.4, 0.3), true)
	world.server_fx("horn", heart.global_position, Vector3.UP, 1.0)


func _spawn(delta: float) -> void:
	_spawn_t -= delta
	while _spawn_t <= 0.0 and _to_spawn > 0 and horde.count() < heart.max_monsters and not _spots.is_empty():
		_spawn_t += _spawn_gap
		_to_spawn -= 1
		var at: Vector3
		for k in _spots.size():
			_spawn_i = (_spawn_i + 1) % _spots.size()
			var s = _spots[_spawn_i]
			if s is MonsterSpawn and (s as MonsterSpawn).from_wave > wave:
				continue
			at = (s as MonsterSpawn).spot(world.rng) if s is MonsterSpawn else s + Vector3(world.rng.randf_range(-2, 2), 0, world.rng.randf_range(-2, 2))
			break
		var kind := _pick_kind()
		horde.server_spawn(at, kind)
		_spawned += 1
		if not _seen.has(kind) and ANNOUNCE.has(kind):
			_seen[kind] = true
			var text: String = ANNOUNCE[kind]
			if kind == "ghost":
				text = text % Controls.key_of("flashlight")
			world.server_message(text, Color(1.0, 0.55, 0.3), true)
	if _spots.is_empty():
		_to_spawn = 0


## What comes out next: a brute now and then (spread through the wave), otherwise the wave's
## mix (KIND_MIX), mostly shamblers.
func _pick_kind() -> String:
	if _brutes > 0 and _spawned > 0 and _spawned % maxi(int(_wave_count() / (_brutes + 1.0)), 1) == 0:
		_brutes -= 1
		return "brute"
	var r: float = world.rng.randf()
	for e in KIND_MIX:
		if wave >= int(e[1]):
			if r < float(e[2]):
				return e[0]
			r -= float(e[2])
	return "shambler"


func _wave_cleared() -> void:
	phase = Phase.BREAK
	phase_end = world.now() + heart.break_time
	meter = minf(meter + heart.wave_bonus, max_meter)
	world.server_message("WAVE %d HELD!  +%d" % [wave, int(heart.wave_bonus)], Color(0.5, 1.0, 0.5), true)


func _drain() -> void:
	var counts := [0, 0, 0, 0]
	var loss := 0.0
	for m in horde.monsters:
		var deepest: DefenseZone = null
		for z: DefenseZone in world.arena.defense_zones:
			if (deepest == null or z.level > deepest.level) and z.has_point(m.pos):
				deepest = z
		if deepest:
			counts[deepest.level] += 1
			loss += deepest.drain_rate()
	meter -= loss
	var now: float = world.now()
	for lv in range(1, 4):
		if counts[lv] > 0 and _zone_counts[lv] == 0 and now - _alerted[lv] > 8.0:
			_alerted[lv] = now
			var text: String = DefenseZone.ALERTS[lv]
			for z: DefenseZone in world.arena.defense_zones:
				if z.level == lv:
					text = z.alert()
			world.server_message(text, DefenseZone.COLORS[lv])
	_zone_counts = counts
	if meter <= 0.0:
		_fallen()


func on_monster_killed(_m, cause: String, attacker: int) -> void:
	if phase == Phase.OVER or cause == "heart":
		return
	kills += 1
	var gain := heart.kill_refill + (heart.style_refill if cause in STYLE else 0.0)
	meter = minf(meter + gain, max_meter)
	var pl: Player = world.get_player(attacker) if attacker != 0 else null
	if pl == null:
		return
	pl.score += 1
	world.server_player_stats(pl)
	var now: float = world.now()
	var c: Array = _combo.get(attacker, [0, -10.0])
	c[0] = c[0] + 1 if now - float(c[1]) < 1.5 else 1
	c[1] = now
	_combo[attacker] = c
	for step in COMBOS:
		if c[0] == step[0]:
			meter = minf(meter + step[2], max_meter)
			world.server_message("%s: %s!  +%d" % [pl.display_name, step[1], int(step[2])], Color(1.0, 0.8, 0.2))


func on_monster_reached(_m) -> void:
	meter -= heart.bite
	heart_hits += 1
	world.server_heart_hurt()
	var now: float = world.now()
	if now - _heart_msg > 4.0:
		_heart_msg = now
		world.server_message("The Heart is hit!  -%d" % int(heart.bite), Color(1.0, 0.25, 0.2))
	if meter <= 0.0:
		_fallen()


func _fallen() -> void:
	if phase == Phase.OVER:
		return
	meter = 0.0
	var held := maxi(wave - 1, 0)
	best = maxi(best, held)
	phase = Phase.OVER
	phase_end = world.now() + OVER_TIME
	var t := int(world.now() - started)
	world.server_message("THE FORTRESS HAS FALLEN\nYou held %d wave%s in %d:%02d  ·  %d monsters down  ·  best %d" % [held, "" if held == 1 else "s", t / 60, t % 60, kills, best], Color(1.0, 0.35, 0.3), true)
	_send_state()


func _restart() -> void:
	horde.server_clear()
	world.server_restore_walls()
	world.server_reset_area(Transform3D(Basis.IDENTITY, heart.global_position), Vector3(4000, 4000, 4000))
	if horde.field and horde.field.refresh_gates():
		horde.field.solve_async()
	meter = max_meter
	wave = 0
	kills = 0
	_seen.clear()
	started = world.now()
	phase = Phase.BREAK
	phase_end = world.now() + heart.first_break
	world.server_message("The fortress stands again. Get ready!", Color(0.6, 0.9, 1.0), true)


func _send_state() -> void:
	world.server_mode_state({
		"meter": int(ceil(meter)), "max": int(max_meter), "wave": wave, "phase": phase,
		"next": phase_end if phase != Phase.WAVE else -1.0, "left": _to_spawn + horde.count(),
		"zones": _zone_counts.slice(1), "best": best, "kills": kills,
	})


## Bots: the monsters to go after, nearest the Heart first.
func threats() -> Array:
	return horde.monsters if horde else []
