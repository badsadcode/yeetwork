class_name ModeYeetball
extends ModeBase
## Yeetball: football with gravity guns (docs/design/YEETWORK_SPORTS_MODE_CONCEPT.md). Two
## teams, one big ball, two goals (GoalZone). Punt it, throw it, pass it, catch it, bank it
## off the walls; the whole ball over the line is a goal.
## - Kickoff: the ball waits on its spot for a countdown, everyone in their own half (whoever
##   crosses the halfway line before the whistle is put back).
## - The match: a clock (Game.match_minutes; it runs only while the ball is in play) and the
##   team ahead at full time wins; level at full time, the next goal wins (golden goal).
##   Five goals win early; without a clock, first to five.
## - The gun holds the ball for a moment at most (no carrying it into the net); the ball never
##   hurts anyone. Lost, stuck or abandoned balls come back to the spot; nobody camps in
##   their own net.
## - Rulesets (Game.yeetball_rules): Classic Chaos keeps it recognisable; TOTAL YEET holds
##   longer, lets the ball fly faster and bowl people over, and brings multi-ball and
##   exploding barrels from the sky.
## - A commentator who gets far too excited.

const GOALS_TO_WIN := 5
const HOLD_LIMIT := [2.5, 4.0] # per ruleset
const MAX_SPEED := [30.0, 42.0]
const COUNTDOWN := 3.0
const CELEBRATE := 3.5
const FULL_TIME := 7.0
const IDLE_RESET := 25.0 # the ball lying still that long comes back
const LONELY_RESET := 10.0 # ...or lying still with nobody near it
const LONELY_RANGE := 12.0
const CAMP_TIME := 5.0 # in your own net longer than this, out you go
const MULTIBALL_EVERY := 45.0 # TOTAL YEET
const MULTIBALL_LAST := 25.0
const BARREL_EVERY := 20.0
const KNOCK_SPEED := 12.0 # TOTAL YEET: a ball faster than this bowls people over
const LONG_RANGE := 24.0

const VOICE := Color(1.0, 0.86, 0.55) # the commentator's lines
const GOAL_LINES := [
	"WHAT A STRIKE!", "OH, YOU BEAUTY!", "THE NET IS BULGING!", "SCENES! ABSOLUTE SCENES!",
	"THE KEEPER HAD NO CHANCE!", "PURE PHYSICS! PURE POETRY!",
	"THEY'LL BE TALKING ABOUT THAT ONE FOR WEEKS!", "GET IN THERE!",
]
const OWN_GOAL_LINES := [
	"Oh no. Oh NO. Into their own net!", "A gift! Wrapped and delivered!",
	"Somebody check their compass!", "That's... the wrong goal.",
]
const LONG_LINES := ["FROM DOWNTOWN! %d METRES!", "A %d-METRE ROCKET!", "FROM %d METRES OUT! UNBELIEVABLE!"]
const QUICK_LINES := ["STRAIGHT FROM THE KICKOFF!", "%d SECONDS! THAT'S ALL IT TOOK!"]
const LATE_LINES := ["AT THE DEATH!", "WITH SECONDS ON THE CLOCK!"]
const LEVEL_LINES := ["IT'S ALL SQUARE!", "LEVEL! GAME ON!"]
const MULTIBALL_LINES := ["MULTI-BALL! Who ordered extra balls?!", "MORE BALLS! THIS IS CHAOS!"]
const BARREL_LINES := ["Incoming barrel!", "Is that... a barrel?!", "Heads up! Something's falling!"]

enum Phase { KICKOFF, PLAY, GOAL, FULL_TIME }
enum Rules { CLASSIC, TOTAL }

var phase: int = Phase.KICKOFF
var rules: int = Rules.CLASSIC
var minutes := 0
var clock_left := INF # seconds of play left (INF: no clock)
var overtime := false
var _t := 0.0
var _ball_id := -1
var _extra: Array[int] = [] # TOTAL YEET's extra balls
var _extra_until := 0.0
var _held_for := {} # ball id -> seconds held
var _kicked := {} # ball id -> [where it was last kicked or thrown from, when]
var _idle := 0.0
var _count := -1
var _since_go := 0.0
var _warned := 0 # 60 s and 10 s warnings given (bit flags)
var _camp := {} # player id -> seconds in their own net
var _knocked := {} # player id -> time of the last bowl-over
var _goals_by := {} # player id -> goals this match
var _multiball_t := MULTIBALL_EVERY
var _barrel_t := BARREL_EVERY
var _rng := RandomNumberGenerator.new()


func mode_name() -> String:
	return "TOTAL YEETBALL" if rules == Rules.TOTAL else "Yeetball"


func is_team_mode() -> bool:
	return true


func setup(p_world: Node) -> void:
	super.setup(p_world)
	score_limit = GOALS_TO_WIN
	rules = clampi(Game.yeetball_rules, 0, 1)
	minutes = maxi(Game.match_minutes, 0)
	_rng.randomize()
	_new_match()


func allow_build() -> bool:
	return false


func hold_time_limit(a: Player, b: Player) -> float:
	if rules == Rules.TOTAL and a.team != b.team:
		return 2.5
	return super.hold_time_limit(a, b)


func spawn_mode_props() -> void:
	var p: Prop = world.server_spawn_prop("yeetball", Transform3D(Basis.IDENTITY, world.arena.ball_spot))
	_ball_id = p.prop_id
	_kickoff(false)


func ball() -> Prop:
	return world.get_prop(_ball_id) as Prop


## Every ball in play: the match ball and any extra ones.
func balls() -> Array[Prop]:
	var out: Array[Prop] = []
	for id in [_ball_id] + _extra:
		var p := world.get_prop(id) as Prop
		if p and not p.is_queued_for_deletion():
			out.append(p)
	return out


func nearest_ball(pos: Vector3) -> Prop:
	var best: Prop = null
	for p in balls():
		if best == null or p.global_position.distance_squared_to(pos) < best.global_position.distance_squared_to(pos):
			best = p
	return best


## The goal a team defends.
func goal_of(team: int) -> GoalZone:
	for g in world.arena.goals:
		if (g as GoalZone).team == team:
			return g
	return null


func _new_match() -> void:
	clock_left = minutes * 60.0 if minutes > 0 else INF
	overtime = false
	_warned = 0
	_goals_by.clear()
	_multiball_t = MULTIBALL_EVERY
	_barrel_t = BARREL_EVERY


## What every peer's HUD shows: the clock (running only in play), overtime, the ruleset.
func _publish() -> void:
	var timed := clock_left != INF
	var left := maxf(clock_left, 0.0) if timed else -1.0
	world.server_mode_state({
		"rules": rules,
		"timed": timed,
		"clock_left": left,
		"clock_end": world.net_time() + left if timed and phase == Phase.PLAY and not overtime else -1.0,
		"overtime": overtime,
		"phase": phase,
	})


## Seconds of play left as the HUD shows it ("" without a clock).
static func clock_text(state: Dictionary, now: float) -> String:
	if state.get("overtime", false):
		return "GOLDEN GOAL"
	if not state.get("timed", false):
		return ""
	var end: float = state.get("clock_end", -1.0)
	var left: float = end - now if end > 0.0 else state.get("clock_left", 0.0)
	var s := ceili(maxf(left, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


## The ball back on its spot, still, for a countdown; after a goal, everyone back to their half.
func _kickoff(line_up: bool) -> void:
	var b := ball()
	if b == null:
		return
	for id in _extra:
		var x := world.get_prop(id) as Prop
		if x:
			world.server_fx("spawn", x.global_position, Vector3.UP, 1.0)
			world.server_despawn_prop(x)
	_extra.clear()
	if b.held_by != 0:
		var holder := world.get_player(b.held_by) as Player
		if holder:
			holder.gun.release(false)
	b.freeze = true
	b.set_meta("no_grab", true)
	b.global_transform = Transform3D(Basis.IDENTITY, world.arena.ball_spot)
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	b.last_thrower = 0
	if line_up:
		for pl: Player in world.players.values():
			world.server_place_player(pl)
	phase = Phase.KICKOFF
	_t = COUNTDOWN
	_count = -1
	_idle = 0.0
	_held_for.clear()
	_kicked.clear()
	_publish()


func tick(delta: float) -> void:
	var b := ball()
	if b == null:
		spawn_mode_props()
		return
	match phase:
		Phase.KICKOFF:
			_t -= delta
			_own_halves()
			var n := ceili(_t)
			if n != _count and n > 0:
				_count = n
				world.server_message(str(n), Color(1, 0.9, 0.4), true)
			if _t <= 0.0:
				b.freeze = false
				b.remove_meta("no_grab")
				b.linear_velocity = Vector3(0, 4, 0)
				b.sleeping = false
				phase = Phase.PLAY
				_since_go = 0.0
				world.server_message("GO!", Color(0.5, 1, 0.5), true)
				world.server_fx("whistle", b.global_position, Vector3.UP, 0.5)
				_publish()
		Phase.PLAY:
			_play(b, delta)
		Phase.GOAL:
			_t -= delta
			if _t <= 0.0:
				_kickoff(true)
		Phase.FULL_TIME:
			_t -= delta
			if _t <= 0.0:
				world.team_scores = {1: 0, 2: 0}
				world.server_team_scores_changed()
				_new_match()
				world.server_message("New match!", Color(1, 0.9, 0.4), true)
				_kickoff(true)


## Before the whistle everyone stays in their own half: over the halfway line, back you go.
func _own_halves() -> void:
	var red := goal_of(Game.TEAM_RED)
	var blue := goal_of(Game.TEAM_BLUE)
	if red == null or blue == null:
		return
	var axis := blue.global_position - red.global_position
	axis.y = 0.0
	axis = axis.normalized()
	for pl: Player in world.players.values():
		if not pl.is_alive() or pl.team == Game.TEAM_NONE:
			continue
		var side: float = (pl.global_position - world.arena.ball_spot).dot(axis) * (-1.0 if pl.team == Game.TEAM_RED else 1.0)
		if side < -0.5:
			world.server_place_player(pl)


func _play(b: Prop, delta: float) -> void:
	_since_go += delta
	for p in balls():
		_ball_rules(p, delta)
		for g in world.arena.goals:
			if (g as GoalZone).contains_ball(p.global_position, p.size.x):
				_goal(g as GoalZone, p)
				return
	_anti_stall(b, delta)
	_no_camping(delta)
	if rules == Rules.TOTAL:
		_chaos(b, delta)
	if clock_left != INF and not overtime:
		clock_left -= delta
		if clock_left <= 60.0 and not (_warned & 1) and minutes > 1:
			_warned |= 1
			world.server_message("ONE MINUTE LEFT!", Color(1, 0.8, 0.3))
		if clock_left <= 10.0 and not (_warned & 2):
			_warned |= 2
			world.server_message("10 SECONDS!", Color(1, 0.5, 0.3), true)
		if clock_left <= 5.0 and ceili(clock_left) != ceili(clock_left + delta):
			world.server_fx("beep", b.global_position, Vector3.UP, 1.4)
		if clock_left <= 0.0:
			_time_up()


## The hold limit (no carrying it into the net), the speed cap, and where it was kicked from.
func _ball_rules(p: Prop, delta: float) -> void:
	if p.held_by != 0:
		_held_for[p.prop_id] = _held_for.get(p.prop_id, 0.0) + delta
		if _held_for[p.prop_id] > HOLD_LIMIT[rules]:
			var holder := world.get_player(p.held_by) as Player
			if holder:
				holder.gun.force_release(1.2)
				world.server_fx("punt", p.global_position, Vector3.UP, 0.5)
			_held_for[p.prop_id] = 0.0
	else:
		_held_for[p.prop_id] = 0.0
	if p.linear_velocity.length() > MAX_SPEED[rules]:
		p.linear_velocity = p.linear_velocity.normalized() * MAX_SPEED[rules]
	var k: Array = _kicked.get(p.prop_id, [Vector3.ZERO, -1.0])
	if p.last_thrower != 0 and p.last_thrown_time != k[1]:
		_kicked[p.prop_id] = [p.global_position, p.last_thrown_time]


## The match ball lying still too long (or with nobody near it) comes back to the spot.
func _anti_stall(b: Prop, delta: float) -> void:
	if b.held_by != 0 or b.linear_velocity.length() > 0.3:
		_idle = 0.0
		return
	_idle += delta
	var lonely := true
	for pl: Player in world.players.values():
		if pl.is_alive() and pl.global_position.distance_to(b.global_position) < LONELY_RANGE:
			lonely = false
			break
	if _idle > IDLE_RESET or (lonely and _idle > LONELY_RESET):
		world.server_message("Ball back to the middle", Color(0.9, 0.9, 1))
		_kickoff(false)


## Standing in your own net for more than a few seconds gets you bounced out of it.
func _no_camping(delta: float) -> void:
	for pl: Player in world.players.values():
		var home := goal_of(pl.team) if pl.team != Game.TEAM_NONE else null
		if home == null or not pl.is_alive() or not home.contains_ball(pl.global_position + Vector3.UP * 0.5, 0.0):
			_camp.erase(pl.player_id)
			continue
		_camp[pl.player_id] = _camp.get(pl.player_id, 0.0) + delta
		if _camp[pl.player_id] > CAMP_TIME:
			_camp.erase(pl.player_id)
			var out := home.global_transform.basis.z * 14.0 + Vector3.UP * 7.0
			world.server_launch_player(pl, out, true, 0.6, 0)
			world.server_message("No camping in the net, %s!" % pl.display_name, VOICE)


## TOTAL YEET: multi-ball now and then, and exploding barrels falling near the ball.
func _chaos(b: Prop, delta: float) -> void:
	_multiball_t -= delta
	if _multiball_t <= 0.0:
		_multiball_t = MULTIBALL_EVERY + _rng.randf_range(-8.0, 8.0)
		if _extra.is_empty():
			for i in 2:
				var at: Vector3 = world.arena.ball_spot + Vector3(_rng.randf_range(-6, 6), 12.0 + i * 2.0, _rng.randf_range(-6, 6))
				var x: Prop = world.server_spawn_prop("yeetball", Transform3D(Basis.IDENTITY, at), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, -2, 0))
				_extra.append(x.prop_id)
				world.server_fx("spawn", at, Vector3.UP, 1.0)
			world.server_message(MULTIBALL_LINES[_rng.randi() % MULTIBALL_LINES.size()], VOICE, true)
			_extra_until = MULTIBALL_LAST
	if not _extra.is_empty():
		_extra_until -= delta
		if _extra_until <= 0.0:
			for id in _extra:
				var x := world.get_prop(id) as Prop
				if x:
					world.server_fx("spawn", x.global_position, Vector3.UP, 1.0)
					world.server_despawn_prop(x)
			_extra.clear()
			world.server_message("Back to one ball.", Color(0.9, 0.9, 1))
	_barrel_t -= delta
	if _barrel_t <= 0.0:
		_barrel_t = BARREL_EVERY + _rng.randf_range(-5.0, 5.0)
		var a := _rng.randf() * TAU
		var at: Vector3 = b.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 8.0)
		at.y = b.global_position.y + 18.0
		world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, at), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, -6, 0))
		if _rng.randf() < 0.6:
			world.server_message(BARREL_LINES[_rng.randi() % BARREL_LINES.size()], VOICE)


func _time_up() -> void:
	clock_left = 0.0
	var red: int = world.team_scores.get(Game.TEAM_RED, 0)
	var blue: int = world.team_scores.get(Game.TEAM_BLUE, 0)
	if red == blue:
		overtime = true
		world.server_fx("whistle", world.arena.ball_spot, Vector3.UP, 2.0)
		world.server_message("GOLDEN GOAL! Next goal wins!", Color(1, 0.85, 0.3), true)
		_publish()
		return
	_full_time(Game.TEAM_RED if red > blue else Game.TEAM_BLUE)


func _full_time(team: int) -> void:
	phase = Phase.FULL_TIME
	_t = FULL_TIME
	var who: String = Game.TEAM_NAMES[team].to_upper()
	world.server_fx("horn", world.arena.ball_spot, Vector3.UP, 1.0)
	world.server_fx("cheer", world.arena.ball_spot, Vector3.UP, 1.0)
	world.server_message("FULL TIME! %s TEAM WINS %d : %d!" % [who, world.team_scores.get(1, 0), world.team_scores.get(2, 0)], Game.team_color(team), true)
	var best := 0
	var star: Player = null
	for id in _goals_by:
		var pl := world.get_player(id) as Player
		if pl and _goals_by[id] > best:
			best = _goals_by[id]
			star = pl
	if star:
		world.server_message("Player of the match: %s (%d goal%s)" % [star.display_name, best, "" if best == 1 else "s"], VOICE)
	for g in world.arena.goals:
		world.server_fx("confetti", (g as GoalZone).mouth() + Vector3.UP * 2.0, Vector3.UP, 4.0)
	clock_left = 0.0 if minutes > 0 else INF
	_publish()


func _goal(g: GoalZone, b: Prop) -> void:
	var team := Game.TEAM_BLUE if g.team == Game.TEAM_RED else Game.TEAM_RED
	var scorer := world.get_player(b.held_by if b.held_by != 0 else b.last_thrower) as Player
	var who: String = Game.TEAM_NAMES[team].to_upper()
	var own := scorer != null and scorer.team != team
	var text := "GOOOOOOAL! for %s" % who
	if scorer and not own:
		text = "GOOOOOOOYEET! %s scores for %s" % [scorer.display_name, who]
		scorer.score += 1
		world.server_player_stats(scorer)
		_goals_by[scorer.player_id] = _goals_by.get(scorer.player_id, 0) + 1
	elif scorer:
		text = "%s scored an OWN GOAL! (%s's point)" % [scorer.display_name, who]
	world.server_fx("score", g.mouth(), Vector3.UP, 1.0)
	world.server_fx("confetti", g.mouth(), g.global_transform.basis.z, 2.0)
	world.server_fx("cheer", g.mouth(), Vector3.UP, 1.0)
	world.server_message(text, Game.team_color(team), true)
	world.team_scores[team] = world.team_scores.get(team, 0) + 1
	world.server_team_scores_changed()
	_commentate(g, b, scorer, own)
	if overtime or world.team_scores[team] >= score_limit:
		_full_time(team)
		return
	phase = Phase.GOAL
	_t = CELEBRATE
	_publish()


## One line from the commentator, for the most remarkable thing about the goal.
func _commentate(g: GoalZone, b: Prop, scorer: Player, own: bool) -> void:
	var line := ""
	var k: Array = _kicked.get(b.prop_id, [Vector3.ZERO, -1.0])
	var from := Vector2(k[0].x - g.mouth().x, k[0].z - g.mouth().z).length() if k[1] >= 0.0 else 0.0
	var red: int = world.team_scores.get(Game.TEAM_RED, 0)
	var blue: int = world.team_scores.get(Game.TEAM_BLUE, 0)
	if own:
		line = OWN_GOAL_LINES[_rng.randi() % OWN_GOAL_LINES.size()]
	elif overtime:
		line = "GOLDEN GOAL! IT'S ALL OVER!"
	elif scorer and _goals_by.get(scorer.player_id, 0) == 3:
		line = "HAT-TRICK for %s!" % scorer.display_name
	elif clock_left != INF and clock_left < 10.0:
		line = LATE_LINES[_rng.randi() % LATE_LINES.size()]
	elif from > LONG_RANGE:
		line = LONG_LINES[_rng.randi() % LONG_LINES.size()] % int(from)
	elif _since_go < 8.0:
		line = QUICK_LINES[_rng.randi() % QUICK_LINES.size()]
		if line.contains("%d"):
			line = line % maxi(ceili(_since_go), 1)
	elif red == blue:
		line = LEVEL_LINES[_rng.randi() % LEVEL_LINES.size()]
	else:
		line = GOAL_LINES[_rng.randi() % GOAL_LINES.size()]
	world.server_message(line, VOICE)


func on_prop_fell_out(prop: Prop) -> bool:
	if prop.prop_id == _ball_id:
		world.server_message("Ball back to the middle", Color(0.9, 0.9, 1))
		_kickoff(false)
		return true
	_extra.erase(prop.prop_id)
	return false


## The ball bonks; it never hurts. In TOTAL YEET a fast one bowls you over.
func on_prop_hit_player(prop: Prop, pl: Player, attacker: Player) -> bool:
	if prop.kind != "yeetball":
		return false
	var v := prop.linear_velocity
	if rules == Rules.TOTAL and v.length() > KNOCK_SPEED and pl.player_id != prop.held_by:
		var t: float = world.now()
		if t - _knocked.get(pl.player_id, -10.0) > 1.0:
			_knocked[pl.player_id] = t
			world.server_launch_player(pl, v.normalized() * 11.0 + Vector3.UP * 5.0, false, 0.8, attacker.player_id if attacker else 0)
	return true
