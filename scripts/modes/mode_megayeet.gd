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
## The breaks between waves are for shopping (buy): repairing gates (MegaYeetGate), building
## traps (TrapSpot), team upgrades at the Heart (MegaYeetUpgrades, UPGRADES), power-ups, all in
## the shop window too (shop_items, shop_buy; ShopWindow), only between waves. What pays is
## the match's Economy (Game.megayeet_rules.economy): "shared", the Fortress meter itself
## (never below a tenth of it); "personal", each Yeet's own Y$, earned by kills (more for
## style and combos), the boss and every wave held, and the meter is only the fortress's life
## (kills put nothing back; Y$ can heal the Heart, dearly).

## (fallbacks with no Heart yet; a FortressHeart sets them: its MegaYeet Rules)
const METER := 1000.0
const STYLE := ["fall", "crushed", "drowned", "lava", "acid", "bowled", "wall", "fire", "light", "bomb", "spikes"]
const FIRST_BREAK := 12.0
const OVER_TIME := 12.0
const RINGS := [32.0, 18.0, 8.0] # (automatic zones' radii, outer to inner)
const COMBOS := [[3, "TRIPLE SPLAT", 10.0], [5, "MONSTER MASH", 20.0], [10, "MEGAYEET", 50.0]]
## [kind, from wave, share of the wave]; the rest are shamblers.
const KIND_MIX := [["runner", 2, 0.18], ["bomber", 2, 0.07], ["climber", 4, 0.14], ["ghost", 5, 0.1]]
const BRUTES_FROM := 3
## Team upgrades at the Heart, bought in this order: [name, cost, what it does].
const UPGRADES := [
	["Mighty pushes", 150, "Everyone's pushes and throws 30% stronger"],
	["Thick skin", 200, "Monster bites hurt 35% less"],
	["Quick return", 120, "Back in the fight twice as fast"],
]
const KEEP := 0.1 # (spending never takes the meter below this much of it)
## Personal Y$: what a Yeet starts with and earns (a wave held: CASH_WAVE and 5 more a wave,
## everyone; the boss: CASH_BOSS for whoever brings it down, half that for the rest).
const CASH_START := 60
const CASH_KILL := 5
const CASH_STYLE := 5
const CASH_WAVE := 30
const CASH_BOSS := 150
## The shop's power-ups (Pickups' kinds) and their prices; bought in a break, a boost lasts
## until POWER_LASTS seconds into the wave.
const POWERS := [
	["health", "First aid", 25, "+50 health, now"],
	["speed", "Speed", 40, "Run 40% faster"],
	["feather", "Feather", 35, "Low gravity, high jumps"],
	["super", "Super Yeet", 60, "Throws and punts 1.8x stronger"],
	["iron", "Iron Yeet", 60, "Can't be grabbed or knocked about; half damage"],
]
const POWER_LASTS := 45.0
const HEAL_COST := 150 # (Y$ only: a tenth of the Heart back)
const HEAL := 0.1
const TABS := ["Traps", "Power-ups", "Team", "Repairs", "Heart"]
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
var ups := 0 # team upgrades bought
var personal := false # (the Economy: each Yeet's own Y$)
var cash := {} # player id -> Y$
var boss # (Horde.Monster) the boss while it lives
var _bosses := 0 # how many have come this game
var _broke_msg := 0.0
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
	if heart:
		apply_rules(heart, Game.megayeet_rules)
	personal = Game.megayeet_rules.get("economy", "shared") == "personal"
	max_meter = heart.health if heart else METER
	meter = max_meter
	started = world.now()
	phase_end = world.now() + (heart.first_break if heart else FIRST_BREAK)


## The host's own rules for this match (the match setup's Custom): onto the Heart, in place of
## the map's MegaYeet Rules. Nothing when they're the map's own.
static func apply_rules(h: FortressHeart, rules: Dictionary) -> void:
	if not rules.get("custom", false):
		return
	for k in ["health", "bite", "kill_refill", "wave_bonus", "first_break", "break_time", "wave_size", "boss_health", "boss_reward"]:
		if rules.has(k):
			h.set(k, float(rules[k]))
	for k in ["max_monsters", "boss_every"]:
		if rules.has(k):
			h.set(k, int(rules[k]))


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
	# Between waves: a repair point on every breakable wall, team upgrades at the Heart.
	var helpers: Array[PuzzleNode] = []
	for d in a.destructibles:
		var g := MegaYeetGate.new()
		g.wall = d
		helpers.append(g)
	var up := MegaYeetUpgrades.new()
	up.heart = a.heart
	helpers.append(up)
	for n in helpers:
		n.world = a.world
		n.puzzle_index = a.puzzle.size()
		a.puzzle.append(n)
		a.add_child(n)
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
	if heart.boss_every > 0 and wave % heart.boss_every == 0:
		_to_spawn = maxi(int(_to_spawn * 0.6), 1) # (the boss is plenty)
		_spawn_boss()
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
		if not _seen.has(kind) and (ANNOUNCE.has(kind) or horde.types.has(kind)):
			_seen[kind] = true
			var text: String = ANNOUNCE[kind] if ANNOUNCE.has(kind) else horde.announcement(kind)
			if kind == "ghost":
				text = text % Controls.key_of("flashlight")
			world.server_message(text, Color(1.0, 0.55, 0.3), true)
	if _spots.is_empty():
		_to_spawn = 0


## What comes out next: a brute now and then (spread through the wave), otherwise the map's
## own monsters (MonsterTypes on the Heart: each its Share, from its From Wave) and the wave's
## mix (KIND_MIX), mostly shamblers.
func _pick_kind() -> String:
	if _brutes > 0 and _spawned > 0 and _spawned % maxi(int(_wave_count() / (_brutes + 1.0)), 1) == 0:
		_brutes -= 1
		return "brute"
	var r: float = world.rng.randf()
	for k in horde.types:
		var t: MonsterType = horde.types[k]
		if wave >= t.from_wave:
			if r < t.share:
				return k
			r -= t.share
	for e in KIND_MIX:
		if wave >= int(e[1]):
			if r < float(e[2]):
				return e[0]
			r -= float(e[2])
	return "shambler"


## The Siege Golem, at a rift: tougher with more Yeets playing and each time it comes back.
func _spawn_boss() -> void:
	if _spots.is_empty():
		return
	var s = _spots[0]
	var at: Vector3 = (s as MonsterSpawn).spot(world.rng) if s is MonsterSpawn else s
	var m = horde.server_spawn(at, "golem")
	var yeets: int = world.players.size()
	m.max_hp = heart.boss_health * (1.0 + 0.35 * maxi(yeets - 1, 0)) * (1.0 + 0.5 * _bosses)
	m.hp = m.max_hp
	_bosses += 1
	boss = m
	world.server_message("WAVE %d: %s!\nBlast it, burn it, throw the iron ball at it" % [wave, Horde.BOSS_NAME], Color(1.0, 0.35, 0.2), true)
	world.server_fx("horn", heart.global_position, Vector3.UP, 1.0)


func _wave_cleared() -> void:
	phase = Phase.BREAK
	phase_end = world.now() + heart.break_time
	meter = minf(meter + heart.wave_bonus, max_meter)
	var pay := ""
	if personal:
		var y := CASH_WAVE + 5 * wave
		for p: Player in world.players.values():
			_earn(p, y)
		pay = "  ·  everyone +%d Y$" % y
	world.server_message("WAVE %d HELD!  +%d%s" % [wave, int(heart.wave_bonus), pay], Color(0.5, 1.0, 0.5), true)
	_send_state()


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


func on_monster_killed(m, cause: String, attacker: int) -> void:
	if m == boss:
		boss = null
		_send_state()
	if phase == Phase.OVER or cause == "heart":
		return
	var pl: Player = world.get_player(attacker) if attacker != 0 else null
	if m.kind == "golem":
		var by := ("  (" + pl.display_name + ")") if pl else ""
		if personal:
			for p: Player in world.players.values():
				_earn(p, CASH_BOSS if p == pl else CASH_BOSS / 2)
			world.server_message("%s FALLS!  +%d Y$%s, +%d Y$ everyone else" % [Horde.BOSS_NAME, CASH_BOSS, by, CASH_BOSS / 2], Color(1.0, 0.85, 0.3), true)
		else:
			meter = minf(meter + heart.boss_reward, max_meter)
			world.server_message("%s FALLS!  +%d%s" % [Horde.BOSS_NAME, int(heart.boss_reward), by], Color(1.0, 0.85, 0.3), true)
	kills += 1
	var style := cause in STYLE
	if not personal:
		meter = minf(meter + heart.kill_refill + (heart.style_refill if style else 0.0), max_meter)
	if pl == null:
		return
	pl.score += 1
	world.server_player_stats(pl)
	if personal:
		_earn(pl, CASH_KILL + (CASH_STYLE if style else 0))
	var now: float = world.now()
	var c: Array = _combo.get(attacker, [0, -10.0])
	c[0] = c[0] + 1 if now - float(c[1]) < 1.5 else 1
	c[1] = now
	_combo[attacker] = c
	for step in COMBOS:
		if c[0] == step[0]:
			if personal:
				_earn(pl, int(step[2]))
			else:
				meter = minf(meter + step[2], max_meter)
			world.server_message("%s: %s!  +%d%s" % [pl.display_name, step[1], int(step[2]), " Y$" if personal else ""], Color(1.0, 0.8, 0.2))


func _earn(pl: Player, y: int) -> void:
	cash[pl.player_id] = int(cash.get(pl.player_id, CASH_START)) + y


func on_monster_reached(m) -> void:
	meter -= heart.bite * (5.0 if m.kind == "golem" else 1.0)
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
	ups = 0
	cash.clear()
	boss = null
	_bosses = 0
	for n in world.arena.puzzle:
		if n is TrapSpot:
			(n as TrapSpot).server_clear()
	started = world.now()
	phase = Phase.BREAK
	phase_end = world.now() + heart.first_break
	world.server_message("The fortress stands again. Get ready!", Color(0.6, 0.9, 1.0), true)


## Server: a Yeet pays `cost` for something (between waves): out of their Y$ (personal), or
## of the Fortress meter (shared; not below KEEP of it). True when it's paid; everyone's told
## what was bought.
func buy(pl: Player, cost: float, what: String) -> bool:
	if phase != Phase.BREAK:
		return false
	if personal:
		var have := int(cash.get(pl.player_id, CASH_START))
		var price := ceili(cost)
		if have < price:
			_tell(pl, "Not enough Y$: %d needed, you have %d" % [price, have])
			return false
		cash[pl.player_id] = have - price
		world.server_message("%s %s  (%d Y$)" % [pl.display_name, what, price], Color(0.7, 0.9, 1.0))
		_send_state()
		return true
	var floor := max_meter * KEEP
	if meter - cost < floor:
		var now: float = world.now()
		if now - _broke_msg > 2.0:
			_broke_msg = now
			world.server_message("Not enough in the Fortress meter: %d needed, %d kept back" % [int(cost), int(floor)], Color(1.0, 0.5, 0.4))
		return false
	meter -= cost
	world.server_message("%s %s  -%d" % [pl.display_name, what, int(cost)], Color(0.7, 0.9, 1.0))
	Sfx.play_ui("pickup")
	_send_state()
	return true


func buy_upgrade(pl: Player) -> void:
	if ups >= UPGRADES.size():
		return
	var up: Array = UPGRADES[ups]
	if buy(pl, up[1], "bought %s for the team (%s)" % [up[0], up[2].to_lower()]):
		ups += 1
		_send_state()


## Server: a purchase from the shop window (checked against what the shop offers this Yeet).
func shop_buy(pl: Player, id: String) -> void:
	var item := {}
	for it: Dictionary in shop_items(world, pl):
		if it.id == id:
			item = it
	if item.is_empty() or not item.ok:
		return
	var parts := id.split(":", true, 1)
	match parts[0]:
		"trap":
			var spot := _free_spot(world, pl, parts[1])
			if spot:
				spot.server_used(pl)
		"power":
			if buy(pl, item.cost, "bought %s" % item.name):
				var until: float = world.net_time() + maxf(phase_end - world.now(), 0.0) + POWER_LASTS
				world.server_shop_power(pl, parts[1], until)
		"up":
			buy_upgrade(pl)
		"fix":
			var walls := _broken_walls(world, pl)
			if parts[1] == "near":
				walls = walls.slice(0, 1)
			if not walls.is_empty() and buy(pl, item.cost, "repaired %s" % ("a gate" if walls.size() == 1 else "%d gates" % walls.size())):
				for d: Destructible in walls:
					world.server_restore_wall(d.wall_id)
				if horde:
					horde.request_gate_refresh()
		"heal":
			if personal and buy(pl, item.cost, "healed the Heart"):
				meter = minf(meter + max_meter * HEAL, max_meter)
				world.server_fx("heal", heart.global_position + Vector3.UP, Vector3.UP, 2.0)
				_send_state()


## The shop's wares for this Yeet as things stand, on any peer (the window lists them, the
## server checks a purchase against them): {id, tab, name, about, cost, ok, why, owned, look}.
## A trap builds the nearest free TrapSpot of its kind; a power-up lasts into the next wave.
static func shop_items(w: Node, pl: Player) -> Array:
	var s: Dictionary = w.mode_state
	var mine := is_personal(w)
	var out := []
	# Traps: by type (the built-in kinds, and the map's own: TrapSpot.type_key), the free spot
	# nearest you.
	var types := {} # key -> [a spot, free, all]
	for n in w.arena.puzzle:
		if n is TrapSpot:
			var key := (n as TrapSpot).type_key()
			if not types.has(key):
				types[key] = [n, 0, 0]
			types[key][1] += 0 if n.active else 1
			types[key][2] += 1
	for key: String in types:
		var any: TrapSpot = types[key][0]
		var spot := _free_spot(w, pl, key)
		out.append({"id": "trap:" + key, "tab": 0, "name": any.title(), "look": "spot:%d" % any.puzzle_index,
			"cost": (spot if spot else any).price(),
			"about": "Built on the free spot nearest you (%d of %d free)" % [types[key][1], types[key][2]],
			"why": "" if spot else "All built"})
	for p: Array in POWERS:
		var why := ""
		if p[0] == "health" and pl.hp >= 100.0:
			why = "You're at full health"
		out.append({"id": "power:" + p[0], "tab": 1, "name": p[1], "look": "power:" + p[0], "cost": p[2],
			"about": p[3] + ("" if p[0] == "health" else "; lasts %d s into the wave" % int(POWER_LASTS)), "why": why})
	var ups := int(s.get("ups", 0))
	for i in UPGRADES.size():
		var up: Array = UPGRADES[i]
		out.append({"id": "up:%d" % i, "tab": 2, "name": up[0], "look": "up:%d" % i, "cost": up[1], "about": up[2] + "; for everyone",
			"owned": i < ups, "why": "Bought" if i < ups else ("" if i == ups else "After " + String(UPGRADES[i - 1][0]))})
	var walls := _broken_walls(w, pl)
	var near := 0.0
	var every := 0.0
	for i in walls.size():
		var c := 10.0 + (walls[i] as Destructible).broken_cells.size() * 3.0
		every += c
		if i == 0:
			near = c
	var none := "No gate is broken" if walls.is_empty() else ""
	out.append({"id": "fix:near", "tab": 3, "name": "Repair a gate", "look": "fix:near", "cost": near if near > 0.0 else 10.0,
		"about": "The broken gate nearest you, whole again", "why": none})
	out.append({"id": "fix:all", "tab": 3, "name": "Repair every gate", "look": "fix:all", "cost": every if every > 0.0 else 10.0,
		"about": ("All %d broken ones, whole again" % walls.size()) if not walls.is_empty() else "Every broken gate, whole again", "why": none})
	if mine:
		var top := float(s.get("max", METER))
		out.append({"id": "heal", "tab": 4, "name": "Heal the Heart", "look": "heal", "cost": HEAL_COST,
			"about": "+%d to the Fortress meter" % int(top * HEAL), "why": "The Heart is whole" if float(s.get("meter", top)) >= top else ""})
	var have := wallet(w, pl)
	var brk := int(s.get("phase", -1)) == Phase.BREAK
	for it: Dictionary in out:
		it.cost = ceili(float(it.cost))
		if it.why == "" and not brk:
			it.why = "Between waves"
		elif it.why == "" and it.cost > have:
			it.why = "Not enough Y$" if mine else "Not enough in the meter"
		it.ok = it.why == ""
		it.owned = it.get("owned", false)
	return out


## Does this match pay in personal Y$ (any peer, from the mode state)?
static func is_personal(w: Node) -> bool:
	return int(w.mode_state.get("eco", 0)) == 1


## What this Yeet can spend: their Y$, or the meter above what's kept back.
static func wallet(w: Node, pl: Player) -> int:
	var s: Dictionary = w.mode_state
	if is_personal(w):
		return int(s.get("cash", {}).get(pl.player_id, CASH_START)) if pl else 0
	return int(float(s.get("meter", 0)) - float(s.get("max", METER)) * KEEP)


## A price as the Use prompts show it: "-120" (the meter) or "120 Y$".
static func price_text(w: Node, cost: float) -> String:
	return ("%d Y$" % ceili(cost)) if is_personal(w) else ("-%d" % int(cost))


## The free trap spot of this type (TrapSpot.type_key) nearest this Yeet.
static func _free_spot(w: Node, pl: Player, key: String) -> TrapSpot:
	var best: TrapSpot = null
	for n in w.arena.puzzle:
		if n is TrapSpot and not n.active and (n as TrapSpot).type_key() == key:
			if best == null or n.global_position.distance_to(pl.global_position) < best.global_position.distance_to(pl.global_position):
				best = n
	return best


## Broken walls, nearest this Yeet first.
static func _broken_walls(w: Node, pl: Player) -> Array:
	var out := []
	for d in w.arena.destructibles:
		if is_instance_valid(d) and not (d as Destructible).broken_cells.is_empty():
			out.append(d)
	out.sort_custom(func(a, b): return a.global_position.distance_to(pl.global_position) < b.global_position.distance_to(pl.global_position))
	return out


## Only this Yeet hears it.
func _tell(pl: Player, text: String) -> void:
	world.server_message_to(pl, text, Color(1.0, 0.5, 0.4))


## Upgrades at work (World, the gun, the Horde ask).
func gun_power(_pl: Player) -> float:
	return 1.3 if ups >= 1 else 1.0


func bite_scale() -> float:
	return 0.65 if ups >= 2 else 1.0


func respawn_scale() -> float:
	return 0.5 if ups >= 3 else 1.0


func _send_state() -> void:
	world.server_mode_state({
		"meter": int(ceil(meter)), "max": int(max_meter), "wave": wave, "phase": phase,
		"next": phase_end if phase != Phase.WAVE else -1.0, "left": _to_spawn + horde.count(),
		"zones": _zone_counts.slice(1), "best": best, "kills": kills, "ups": ups,
		"boss": [Horde.BOSS_NAME, boss.hp / boss.max_hp] if boss and boss.hp > 0.0 else [],
		"eco": 1 if personal else 0, "cash": _cash_state(),
	})


func _cash_state() -> Dictionary:
	if not personal:
		return {}
	var out := {}
	for id in world.players:
		out[id] = int(cash.get(id, CASH_START))
	return out


## Bots: the monsters to go after, nearest the Heart first.
func threats() -> Array:
	return horde.monsters if horde else []
