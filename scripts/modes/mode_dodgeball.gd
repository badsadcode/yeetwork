class_name ModeDodgeball
extends ModeBase
## Team dodgeball with gravity guns. A live ball (thrown or punted, not yet bounced) that
## hits an enemy knocks them out. Catching an enemy's live ball knocks out the thrower.

const BALL_COUNT := 14

var _ball_ids: Array[int] = []


func mode_name() -> String:
	return "Dodgeball"


func is_team_mode() -> bool:
	return true


func setup(p_world: Node) -> void:
	super.setup(p_world)
	score_limit = 15


func allow_build() -> bool:
	return false


func spawn_mode_props() -> void:
	for i in BALL_COUNT:
		_spawn_ball(i)


func _spawn_ball(i: int) -> void:
	# Two rows of balls along the pit's north and south rims.
	var pos := Vector3(-12.0 + (i / 2) * 4.0, 1.0, 18.0 if i % 2 == 0 else -18.0)
	var p: Prop = world.server_spawn_prop("ball", Transform3D(Basis.IDENTITY, pos))
	_ball_ids.append(p.prop_id)


func tick(_delta: float) -> void:
	for i in range(_ball_ids.size() - 1, -1, -1):
		if world.get_prop(_ball_ids[i]) == null:
			_ball_ids.remove_at(i)
	while _ball_ids.size() < BALL_COUNT:
		_spawn_ball(world.rng.randi() % BALL_COUNT)


func on_prop_hit_player(prop: Prop, pl: Player, attacker: Player, _rel := Vector3.ZERO) -> bool:
	if prop.kind != "ball" or not prop.live or attacker == null:
		return false
	prop.live = false
	if attacker.team == pl.team:
		return true # friendly balls just bonk
	world.server_damage_player(pl, 1000.0, attacker.player_id, "dodgeball", prop.global_position, prop.linear_velocity)
	award_team(attacker.team, 1, "%s dodgeballed %s!" % [attacker.display_name, pl.display_name])
	return true


func on_prop_caught(prop: Prop, pl: Player) -> void:
	if prop.kind != "ball" or not prop.live:
		return
	prop.live = false
	var thrower := world.get_player(prop.last_thrower) as Player
	if thrower == null or thrower.team == pl.team or not thrower.is_alive():
		return
	world.server_damage_player(thrower, 1000.0, pl.player_id, "caught", thrower.body_center(), Vector3.UP * 10.0)
	award_team(pl.team, 1, "%s CAUGHT %s's ball!" % [pl.display_name, thrower.display_name])
