class_name ModeYeetball
extends ModeBase
## Yeetball: football with gravity guns (docs/design/YEETWORK_SPORTS_MODE_CONCEPT.md, the first
## prototype). Two teams, one big ball, two goals (GoalZone). Punt it, throw it, pass it,
## catch it, bank it off the walls; the whole ball over the line is a goal. Kickoff: the
## ball waits on its spot for a countdown, everyone in their own half (whoever crosses the
## halfway line before the whistle is put back). The gun holds the ball
## for 2.5 s at most (no carrying it into the net); the ball never hurts anyone. Lost or
## stuck balls come back to the spot. First to 5 goals wins.

const GOALS_TO_WIN := 5
const HOLD_LIMIT := 2.5
const COUNTDOWN := 3.0
const CELEBRATE := 3.5
const IDLE_RESET := 25.0
const MAX_SPEED := 30.0

enum Phase { KICKOFF, PLAY, GOAL }

var phase: int = Phase.KICKOFF
var held_for := 0.0
var _t := 0.0
var _ball_id := -1
var _idle := 0.0
var _count := -1


func mode_name() -> String:
	return "Yeetball"


func is_team_mode() -> bool:
	return true


func setup(p_world: Node) -> void:
	super.setup(p_world)
	score_limit = GOALS_TO_WIN


func allow_build() -> bool:
	return false


func spawn_mode_props() -> void:
	var p: Prop = world.server_spawn_prop("yeetball", Transform3D(Basis.IDENTITY, world.arena.ball_spot))
	_ball_id = p.prop_id
	_kickoff(false)


func ball() -> Prop:
	return world.get_prop(_ball_id) as Prop


## The goal a team defends.
func goal_of(team: int) -> GoalZone:
	for g in world.arena.goals:
		if (g as GoalZone).team == team:
			return g
	return null


## The ball back on its spot, still, for a countdown; after a goal, everyone back to their half.
func _kickoff(line_up: bool) -> void:
	var b := ball()
	if b == null:
		return
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
	held_for = 0.0


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
				world.server_message("GO!", Color(0.5, 1, 0.5), true)
		Phase.PLAY:
			_play(b, delta)
		Phase.GOAL:
			_t -= delta
			if _t <= 0.0:
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
	# No carrying it into the net.
	if b.held_by != 0:
		held_for += delta
		if held_for > HOLD_LIMIT:
			var holder := world.get_player(b.held_by) as Player
			if holder:
				holder.gun.force_release(1.2)
				world.server_fx("punt", b.global_position, Vector3.UP, 0.5)
			held_for = 0.0
	else:
		held_for = 0.0
	if b.linear_velocity.length() > MAX_SPEED:
		b.linear_velocity = b.linear_velocity.normalized() * MAX_SPEED
	for g in world.arena.goals:
		if (g as GoalZone).contains_ball(b.global_position, b.size.x):
			_goal(g as GoalZone, b)
			return
	if b.held_by == 0 and b.linear_velocity.length() < 0.3:
		_idle += delta
		if _idle > IDLE_RESET:
			world.server_message("Ball back to the middle", Color(0.9, 0.9, 1))
			_kickoff(false)
	else:
		_idle = 0.0


func _goal(g: GoalZone, b: Prop) -> void:
	var team := Game.TEAM_BLUE if g.team == Game.TEAM_RED else Game.TEAM_RED
	var scorer := world.get_player(b.held_by if b.held_by != 0 else b.last_thrower) as Player
	var who: String = Game.TEAM_NAMES[team].to_upper()
	var text := "GOOOOOOAL! for %s" % who
	if scorer and scorer.team == team:
		text = "GOOOOOOOYEET! %s scores for %s" % [scorer.display_name, who]
		scorer.score += 1
		world.server_player_stats(scorer)
	elif scorer:
		text = "%s scored an OWN GOAL! (%s's point)" % [scorer.display_name, who]
	world.server_fx("score", g.mouth(), Vector3.UP, 1.0)
	world.server_message(text, Game.team_color(team), true)
	phase = Phase.GOAL
	_t = CELEBRATE
	world.team_scores[team] = world.team_scores.get(team, 0) + 1
	world.server_team_scores_changed()
	if world.team_scores[team] >= score_limit:
		world.server_message("%s TEAM WINS %d : %d!" % [who, world.team_scores.get(1, 0), world.team_scores.get(2, 0)], Game.team_color(team), true)
		world.team_scores = {1: 0, 2: 0}
		world.server_team_scores_changed()


func on_prop_fell_out(prop: Prop) -> bool:
	if prop.kind == "yeetball":
		world.server_message("Ball back to the middle", Color(0.9, 0.9, 1))
		_kickoff(false)
		return true
	return false


## The ball bonks; it never hurts.
func on_prop_hit_player(prop: Prop, _pl: Player, _attacker: Player) -> bool:
	return prop.kind == "yeetball"
