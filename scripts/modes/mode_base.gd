class_name ModeBase
extends RefCounted
## Server-side rules for a game mode. The default is the free-for-all sandbox.

var world: Node
var score_limit := 0


func setup(p_world: Node) -> void:
	world = p_world


func mode_name() -> String:
	return "Sandbox"


func is_team_mode() -> bool:
	return false


func pick_team(players: Dictionary) -> int:
	if not is_team_mode():
		return Game.TEAM_NONE
	var red := 0
	var blue := 0
	for p in players.values():
		if p.team == Game.TEAM_RED:
			red += 1
		elif p.team == Game.TEAM_BLUE:
			blue += 1
	return Game.TEAM_RED if red <= blue else Game.TEAM_BLUE


func player_color(team: int, index: int) -> Color:
	if team != Game.TEAM_NONE:
		return Game.team_color(team)
	return Game.FFA_COLORS[index % Game.FFA_COLORS.size()]


func spawn_point(pl: Player) -> Vector3:
	return world.arena.random_spawn(pl.team if is_team_mode() else Game.TEAM_NONE, world.rng)


func spawn_mode_props() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func on_kill(_victim: Player, _killer: Player, _cause: String) -> void:
	pass


## Return true to replace the default prop damage. rel: the prop's velocity relative to the
## player as they met (the prop may have bounced off by now).
func on_prop_hit_player(_prop: Prop, _pl: Player, _attacker: Player, _rel := Vector3.ZERO) -> bool:
	return false


func on_prop_caught(_prop: Prop, _pl: Player) -> void:
	pass


func on_prop_broken(_prop: Prop) -> void:
	pass


func on_prop_fell_out(_prop: Prop) -> bool:
	return false


## Server: run statistics (the Puzzle mode keeps score with these).
func on_player_launched(_pl: Player, _vel: Vector3, _attacker: int) -> void:
	pass


func on_explosion(_pos: Vector3) -> void:
	pass


func on_prop_thrown(_p: Prop, _thrower: Player) -> void:
	pass


func on_prop_impact(_p: Prop) -> void:
	pass


## Server: a puzzle piece just switched (after it changed on every peer).
func on_puzzle_changed(_n: PuzzleNode) -> void:
	pass


func allow_build() -> bool:
	return true


## False: this player's gravity gun can't grab or pull this prop (YeetVolley: the ball on the
## other side of the net).
func allow_grab(_pl: Player, _p: Prop) -> bool:
	return true


## False: this kind of pickup isn't used in this mode (it stays hidden).
func allows_pickup(_kind: String) -> bool:
	return true


## False: no bots join (the Puzzle mode).
func allows_bots() -> bool:
	return true


## Return false to cancel damage to a player (before it's applied).
func allow_damage(_pl: Player, _attacker: int, _cause: String) -> bool:
	return true


func hold_time_limit(a: Player, b: Player) -> float:
	if a.team != Game.TEAM_NONE and a.team == b.team:
		return 6.0
	return 2.5 if not is_team_mode() else 1.3


func award_team(team: int, points: int, text: String) -> void:
	world.team_scores[team] = world.team_scores.get(team, 0) + points
	world.server_team_scores_changed()
	world.server_message(text, Game.team_color(team))
	if score_limit > 0 and world.team_scores[team] >= score_limit:
		world.server_message("%s TEAM WINS! Scores reset." % Game.TEAM_NAMES[team].to_upper(), Game.team_color(team), true)
		world.team_scores = {1: 0, 2: 0}
		world.server_team_scores_changed()
