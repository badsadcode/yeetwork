class_name ModeVolley
extends ModeYeetball
## YeetVolley: keep the big, floaty volleyball off your side's floor and send it over the
## net (a VolleyNet: its two halves are the "goals"). Built on Yeetball's match flow: the
## clock and next-point-wins, the rulesets, the knockdown option, the full-time screen.
## - A point: the ball touches the floor inside a half (a point for the other team), or
##   lands outside the lines or in the sea ("OUT!": a point against whoever touched it last).
## - Rally scoring: whoever wins the point serves; the serve floats in over the back of their
##   half. First to 15.
## - Classic: three touches a side at most (a fourth is a fault), the gun only reaches the
##   ball on your own side, catches are brief (1 s). Everyone stays on their side of the net.
## - TOTAL YEET: unlimited touches, grab it anywhere, 2 s catches, multi-ball and barrels,
##   and the net climbs a little with every point.

const POINTS_TO_WIN := 15
const HOLD := [1.0, 2.0] # per ruleset
const MAX_TOUCHES := 3
const NET_STEP := 0.15 # TOTAL YEET: the net rises this much per point...
const NET_MAX := 1.8 # ...up to this

const POINT_LINES := ["KILL!", "PUT AWAY!", "STRAIGHT INTO THE SAND!", "NO CHANCE!", "THAT'S A POINT!", "WHAT A HIT!"]
const SPIKE_LINES := ["SPIKE! WHAT A SPIKE!", "HAMMERED DOWN!", "THEY'LL FEEL THAT ONE TOMORROW!"]
const ACE_LINES := ["ACE!", "SERVICE ACE! UNTOUCHED!", "NOBODY EVEN MOVED!"]
const OUT_LINES := ["OUT! Way out!", "That's long!", "Into the crowd... well, the sea."]
const TOUCH_LINES := ["FOUR TOUCHES! That's a fault!", "Too many touches!", "Pass it over already!"]
const NET_FAULT_LINES := ["Couldn't get it over the net!", "Into their own sand!", "The net says no."]
const RALLY_LINES := ["WHAT A RALLY!", "BACK AND FORTH AND BACK AND FORTH!", "WILL IT EVER LAND?!"]

var _serve_team := 1
var _touch_team := 0
var _touches := 0
var _rally := 0 # touches since the serve
var _touched_by := {} # team -> true: who touched it since the serve (an ace: the receivers didn't)
var _last_side := {} # ball id -> the side it was on
var _last_throw := {} # ball id -> the last throw/punt time seen
var _fault := "" # why the last point was given ("OUT!", "FOUR TOUCHES!"), "" for a landing
var _land_speed := 0.0
var _net_raise := 0.0
var _side_warned := {} # player id -> time of the last "stay on your side" push


func mode_name() -> String:
	return "TOTAL YEETVOLLEY" if rules == Rules.TOTAL else "YeetVolley"


func ball_kind() -> String:
	return "volleyball"


func unit() -> String:
	return "point"


func hold_limit() -> float:
	return HOLD[rules]


func setup(p_world: Node) -> void:
	super.setup(p_world)
	score_limit = POINTS_TO_WIN
	countdown = 2.5
	_serve_team = Game.TEAM_RED if _rng.randf() < 0.5 else Game.TEAM_BLUE


func _new_match() -> void:
	super._new_match()
	_net_raise = 0.0


func _golden_label() -> String:
	return "NEXT POINT WINS"


func _extra_state() -> Dictionary:
	return {"net_raise": _net_raise}


func net() -> VolleyNet:
	return world.arena.nets[0] if not world.arena.nets.is_empty() else null


## Classic: the gun only reaches the ball on your own side of the net.
func allow_grab(pl: Player, p: Prop) -> bool:
	var n := net()
	if rules == Rules.TOTAL or n == null or p.kind != ball_kind():
		return true
	return n.side_of(p.global_position) == pl.team


## The serve: the ball floats in over the back of the serving team's half.
func _kickoff(line_up: bool) -> void:
	super._kickoff(line_up)
	var n := net()
	var b := ball()
	if n and b:
		var back := (n.court.y * 0.5 - 2.5) * (-1.0 if _serve_team == Game.TEAM_RED else 1.0)
		b.global_position = n.global_transform * Vector3(0, 3.2, back)
	_touches = 0
	_touch_team = 0
	_rally = 0
	_touched_by.clear()
	_last_side.clear()
	_last_throw.clear()
	if phase == Phase.KICKOFF and line_up:
		world.server_message("%s serves" % Game.TEAM_NAMES[_serve_team].to_upper(), Game.team_color(_serve_team))


func _play(b: Prop, delta: float) -> void:
	super._play(b, delta)
	_keep_sides()


## Everyone stays on their own side of the net: over the line, you're put back on your side
## (a push would only pin you against the net).
func _keep_sides() -> void:
	var n := net()
	if n == null:
		return
	var t: float = world.now()
	for pl: Player in world.players.values():
		if not pl.is_alive() or pl.team == Game.TEAM_NONE:
			continue
		var z := (n.global_transform.affine_inverse() * pl.global_position).z
		var over := z > 0.4 if pl.team == Game.TEAM_RED else z < -0.4
		if over:
			world.server_place_player(pl)
			if t - _side_warned.get(pl.player_id, -10.0) > 5.0:
				world.server_message("Stay on your side, %s!" % pl.display_name, VOICE)
			_side_warned[pl.player_id] = t


func _scored(p: Prop) -> Array:
	var n := net()
	if n == null:
		return []
	var id := p.prop_id
	var pos := p.global_position
	# Over the net: a fresh set of touches.
	var side := n.side_of(pos)
	var prev: int = _last_side.get(id, side)
	if side != 0 and side != prev:
		_touches = 0
		_touch_team = 0
	if side != 0:
		_last_side[id] = side
	# A touch: a throw or a punt.
	if p.last_thrower != 0 and p.last_thrown_time != _last_throw.get(id, -1.0):
		_last_throw[id] = p.last_thrown_time
		var hitter := world.get_player(p.last_thrower) as Player
		if hitter:
			_rally += 1
			_touched_by[hitter.team] = true
			if hitter.team == _touch_team:
				_touches += 1
			else:
				_touch_team = hitter.team
				_touches = 1
			if rules == Rules.CLASSIC and _touches > MAX_TOUCHES:
				_fault = "touches"
				return [goal_of(hitter.team), 1]
	# Down: on the floor (in a half, or out).
	if p.held_by == 0 and pos.y - p.size.x <= n.global_position.y + 0.12 and p.linear_velocity.y < 1.0:
		_land_speed = p.linear_velocity.length()
		if n.inside(pos):
			_fault = ""
			var landed := n.side_of(pos)
			if landed == 0: # (right on the line under the net: the side it was last on)
				landed = _last_side.get(id, _serve_team)
			return [goal_of(landed), 1]
		_fault = "out"
		return [goal_of(_blamed(p, pos)), 1]
	return []


## Whose fault it is that this ball went out: whoever touched it last (else the side it
## left from).
func _blamed(p: Prop, pos: Vector3) -> int:
	var hitter := world.get_player(p.last_thrower) as Player if p.last_thrower != 0 else null
	if hitter and hitter.team != Game.TEAM_NONE:
		return hitter.team
	var side: int = _last_side.get(p.prop_id, net().side_of(pos))
	return side if side != 0 else _serve_team


func _goal(g: GoalZone, b: Prop, points := 1) -> void:
	if g == null:
		return
	var winner := Game.TEAM_BLUE if g.team == Game.TEAM_RED else Game.TEAM_RED
	_serve_team = winner
	if rules == Rules.TOTAL:
		_net_raise = minf(_net_raise + NET_STEP, NET_MAX)
	super._goal(g, b, points)


## A volleyball point has no "distance" worth showing.
func _kick_distance(_g: GoalZone, _b: Prop) -> float:
	return 0.0


func _score_text(scorer: Player, team: int, own: bool, _points: int, _b: Prop) -> String:
	var who: String = Game.TEAM_NAMES[team].to_upper()
	if _fault == "out":
		return "OUT! Point %s" % who
	if _fault == "touches":
		return "FOUR TOUCHES! Point %s" % who
	if scorer and not own:
		return "POINT %s! %s puts it away" % [who, scorer.display_name]
	if scorer:
		return "Point %s (%s couldn't get it over)" % [who, scorer.display_name]
	return "POINT %s!" % who


func _commentate(_g: GoalZone, _b: Prop, scorer: Player, own: bool) -> void:
	var line := ""
	var winner := _serve_team # (set to the point's winner in _goal)
	var red: int = world.team_scores.get(Game.TEAM_RED, 0)
	var blue: int = world.team_scores.get(Game.TEAM_BLUE, 0)
	if _fault == "out":
		line = OUT_LINES[_rng.randi() % OUT_LINES.size()]
	elif _fault == "touches":
		line = TOUCH_LINES[_rng.randi() % TOUCH_LINES.size()]
	elif overtime:
		line = "NEXT POINT WINS... AND THAT'S THE MATCH!"
	elif own:
		line = NET_FAULT_LINES[_rng.randi() % NET_FAULT_LINES.size()]
	elif not _touched_by.has(Game.TEAM_BLUE if winner == Game.TEAM_RED else Game.TEAM_RED) and _rally <= 1:
		line = ACE_LINES[_rng.randi() % ACE_LINES.size()]
	elif _rally >= 8:
		line = RALLY_LINES[_rng.randi() % RALLY_LINES.size()]
	elif _land_speed > 14.0:
		line = SPIKE_LINES[_rng.randi() % SPIKE_LINES.size()]
	elif red == blue:
		line = LEVEL_LINES[_rng.randi() % LEVEL_LINES.size()]
	else:
		line = POINT_LINES[_rng.randi() % POINT_LINES.size()]
	world.server_message(line, VOICE)


## Into the sea (or off the map): out, against whoever touched it last.
func on_prop_fell_out(prop: Prop) -> bool:
	if prop.prop_id != _ball_id and not _extra.has(prop.prop_id):
		return false
	if phase == Phase.PLAY and net():
		_fault = "out"
		var g := goal_of(_blamed(prop, prop.global_position))
		prop.linear_velocity = Vector3.ZERO
		prop.global_position = world.arena.ball_spot + Vector3.UP * 6.0
		_goal(g, prop, 1)
		return true
	return super.on_prop_fell_out(prop)
