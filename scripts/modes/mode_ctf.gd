class_name ModeCTF
extends ModeBase
## Capture the Flag where the flag is a physics prop: carry it with the gravity gun, throw
## it across the map, launch a teammate holding it. A capture happens when the enemy flag
## touches your stand while your own flag is home.

const CAPTURE_RADIUS := 3.2
const RETURN_IDLE_TIME := 18.0

var flags := {} # team -> Prop id
var _idle := {} # team -> seconds the flag has been away and untouched


func mode_name() -> String:
	return "Capture the Flag"


func is_team_mode() -> bool:
	return true


func setup(p_world: Node) -> void:
	super.setup(p_world)
	score_limit = 5


func allow_build() -> bool:
	return false


func spawn_mode_props() -> void:
	for team in [Game.TEAM_RED, Game.TEAM_BLUE]:
		var stand: Vector3 = world.arena.flag_pos(team)
		var p: Prop = world.server_spawn_prop("flag", Transform3D(Basis.IDENTITY, stand + Vector3(0, 1.25, 0)), Vector3.ZERO, Color(0, 0, 0, 0), team)
		flags[team] = p.prop_id
		_idle[team] = 0.0


func _flag(team: int) -> Prop:
	return world.get_prop(flags.get(team, -1)) as Prop


func _is_home(team: int) -> bool:
	var f := _flag(team)
	if f == null:
		return false
	return f.global_position.distance_to(world.arena.flag_pos(team) + Vector3(0, 1.25, 0)) < CAPTURE_RADIUS


func return_flag(team: int, text := "") -> void:
	var f := _flag(team)
	if f == null:
		return
	if f.held_by != 0:
		var holder := world.get_player(f.held_by) as Player
		if holder:
			holder.gun.release(false)
	f.freeze = false
	f.linear_velocity = Vector3.ZERO
	f.angular_velocity = Vector3.ZERO
	f.global_transform = world.arena.xf_world(f.home_transform)
	_idle[team] = 0.0
	if text != "":
		world.server_message(text, Game.team_color(team))


func tick(delta: float) -> void:
	for team in [Game.TEAM_RED, Game.TEAM_BLUE]:
		var f := _flag(team)
		if f == null:
			continue
		if _is_home(team):
			_idle[team] = 0.0
		elif f.held_by == 0 and f.linear_velocity.length() < 0.5:
			_idle[team] += delta
			if _idle[team] > RETURN_IDLE_TIME:
				return_flag(team, "%s flag returned" % Game.TEAM_NAMES[team])
		else:
			_idle[team] = 0.0
	# Captures: enemy flag at my stand while mine is home.
	for team in [Game.TEAM_RED, Game.TEAM_BLUE]:
		var enemy := Game.TEAM_BLUE if team == Game.TEAM_RED else Game.TEAM_RED
		var ef := _flag(enemy)
		if ef == null or not _is_home(team):
			continue
		var stand: Vector3 = world.arena.flag_pos(team) + Vector3(0, 1.25, 0)
		if ef.global_position.distance_to(stand) < CAPTURE_RADIUS:
			var capper := world.get_player(ef.held_by if ef.held_by != 0 else ef.last_thrower) as Player
			if capper:
				capper.score += 1
				world.server_player_stats(capper)
			var who: String = capper.display_name if capper else "Physics"
			return_flag(enemy)
			award_team(team, 1, "%s captured the %s flag!" % [who, Game.TEAM_NAMES[enemy]])
			world.server_fx("score", stand, Vector3.UP, 1.0)


func on_prop_caught(prop: Prop, pl: Player) -> void:
	if prop.kind != "flag":
		return
	if prop.team == pl.team and not _is_home(prop.team):
		# Touching your own flag sends it home (classic CTF return).
		return_flag(prop.team, "%s returned the %s flag" % [pl.display_name, Game.TEAM_NAMES[prop.team]])
	elif prop.team != pl.team and _is_home(prop.team):
		world.server_message("%s grabbed the %s flag!" % [pl.display_name, Game.TEAM_NAMES[prop.team]], Game.team_color(pl.team))


func on_prop_fell_out(prop: Prop) -> bool:
	if prop.kind == "flag":
		return_flag(prop.team, "%s flag returned" % Game.TEAM_NAMES[prop.team])
		return true
	return false
