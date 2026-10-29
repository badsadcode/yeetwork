class_name BotBrain
extends RefCounted
## Simple server-side AI: grab nearby junk, chase someone, lob it at them, punt anyone
## who gets close, bunny hop around, and occasionally do something dumb.

var pl: Player
var world: Node
var _rng := RandomNumberGenerator.new()
var _goal := Vector3.ZERO
var _goal_timer := 0.0
var _target_prop: Prop
var _enemy: Player
var _think := 0.0
var _hold_timer := 0.0
var _stuck := 0.0
var _strafe := 0.0
var _strafe_timer := 0.0
var _aim_yaw := 0.0
var _aim_pitch := 0.0
var _grabbing := false
var _punt_cd := 0.0
var _jump_held := false


func _init(p_pl: Player, p_world: Node) -> void:
	pl = p_pl
	world = p_world
	_rng.randomize()
	_goal = pl.global_position


func think(delta: float) -> void:
	var cmd := pl.cmd
	cmd.jump_pressed = false
	if not pl.is_alive():
		cmd.move = Vector2.ZERO
		cmd.jump = false
		_grabbing = false
		return
	_think -= delta
	_punt_cd -= delta
	if _think <= 0.0:
		_think = 0.25 + _rng.randf() * 0.2
		_reconsider()

	var holding := pl.gun.held_kind != GravityGun.Kind.NONE
	var eye := pl.eye_position()
	var look_at := _goal + Vector3.UP
	var want_move := true

	if holding:
		_hold_timer += delta
		if _carrying_flag():
			look_at = _goal + Vector3.UP
		elif _enemy and is_instance_valid(_enemy) and _enemy.is_alive():
			var d := eye.distance_to(_enemy.body_center())
			var lead := _enemy.velocity * clampf(d / 35.0, 0.0, 0.8)
			look_at = _enemy.body_center() + lead + Vector3.UP * d * 0.02
			if d < 32.0 and _hold_timer > 0.4 and _can_see(_enemy.body_center()) and _aim_error(look_at) < 0.12:
				_throw()
		elif _hold_timer > 4.0:
			_throw()
	else:
		_hold_timer = 0.0
		if _target_prop and is_instance_valid(_target_prop):
			var tp := _target_prop.global_position
			var d := eye.distance_to(tp)
			var visible := d < 22.0 and _can_see(tp)
			if visible:
				look_at = tp
				want_move = d > 8.0
				if not _grabbing and _aim_error(tp) < 0.15:
					world.gun_action(pl, GravityGun.Action.GRAB_START)
					_grabbing = true
			elif _grabbing:
				world.gun_action(pl, GravityGun.Action.GRAB_END)
				_grabbing = false
		elif _grabbing:
			world.gun_action(pl, GravityGun.Action.GRAB_END)
			_grabbing = false
		# Punt enemies that get too close.
		if _enemy and is_instance_valid(_enemy) and _enemy.is_alive() and _punt_cd <= 0.0:
			var d := eye.distance_to(_enemy.body_center())
			if d < 5.5:
				look_at = _enemy.body_center()
				if _aim_error(look_at) < 0.3:
					world.gun_action(pl, GravityGun.Action.THROW)
					_punt_cd = 1.0 + _rng.randf()
	_aim(look_at, delta)
	_steer(delta, want_move)


func _throw() -> void:
	world.gun_action(pl, GravityGun.Action.THROW)
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	_grabbing = false
	_hold_timer = 0.0
	_target_prop = null


func _carrying_flag() -> bool:
	if pl.gun.held_kind != GravityGun.Kind.PROP:
		return false
	var p := world.get_prop(pl.gun.held_id) as Prop
	return p != null and p.kind == "flag"


func _reconsider() -> void:
	_enemy = _find_enemy()
	var holding := pl.gun.held_kind != GravityGun.Kind.NONE
	if world.mode == Game.Mode.CTF:
		var flag := _enemy_flag()
		if _carrying_flag():
			_goal = world.arena.flag_stands[pl.team]
			return
		if flag and flag.held_by == 0 and not holding and _rng.randf() < 0.7:
			_target_prop = flag
			_goal = flag.global_position
			return
	if not holding:
		if _target_prop == null or not is_instance_valid(_target_prop) or _target_prop.held_by != 0 or _target_prop.freeze:
			_target_prop = _find_prop()
		if _target_prop:
			_goal = _target_prop.global_position
			return
	if _enemy:
		_goal = _enemy.global_position
		return
	_goal_timer -= 0.3
	if _goal_timer <= 0.0 or pl.global_position.distance_to(_goal) < 3.0:
		_goal_timer = 5.0
		_goal = world.arena.random_spawn(0, _rng)


func _enemy_flag() -> Prop:
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.kind == "flag" and p.team != pl.team:
			return p
	return null


func _find_enemy() -> Player:
	var best: Player = null
	var best_d := 60.0
	for o: Player in world.players.values():
		if o == pl or not o.is_alive() or world.are_teammates(o, pl):
			continue
		var d := pl.global_position.distance_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func _find_prop() -> Prop:
	var best: Prop = null
	var best_d := 30.0
	var dodgeball: bool = world.mode == Game.Mode.DODGEBALL
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0 or p.freeze or p.kind == "flag":
			continue
		if dodgeball and p.kind != "ball":
			continue
		if p.mass > 120.0:
			continue
		var d := pl.global_position.distance_to(p.global_position) + _rng.randf() * 4.0
		if d < best_d:
			best_d = d
			best = p
	return best


func _can_see(point: Vector3) -> bool:
	var space := pl.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pl.eye_position(), point, Game.L_WORLD, [pl.get_rid()])
	return space.intersect_ray(q).is_empty()


func _aim(point: Vector3, delta: float) -> void:
	var to := point - pl.eye_position()
	if to.length() < 0.1:
		return
	_aim_yaw = atan2(-to.x, -to.z)
	_aim_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	var k := 1.0 - exp(-7.0 * delta)
	pl.yaw = lerp_angle(pl.yaw, _aim_yaw, k)
	pl.pitch = lerpf(pl.pitch, clampf(_aim_pitch, -1.4, 1.4), k)


func _aim_error(point: Vector3) -> float:
	var to := (point - pl.eye_position()).normalized()
	return 1.0 - pl.aim_direction().dot(to)


func _steer(delta: float, want_move: bool) -> void:
	var cmd := pl.cmd
	var pos := pl.global_position
	var goal := _route(pos, _goal)
	var to := goal - pos
	to.y = 0.0
	if not want_move or to.length() < 1.5:
		cmd.move = Vector2.ZERO
		cmd.jump = false
		return
	# Move in world space toward the goal regardless of where we are looking.
	var dir := to.normalized()
	var ledge := false
	if pl.is_on_floor() and not _ground_ahead(pos, dir):
		ledge = true
		# Ledge! Head back toward the middle of the map instead of walking off it.
		var back := Vector3(-pos.x * 0.2, 0, -pos.z).normalized()
		dir = back if back.length() > 0.1 else -dir
	var basis := Basis(Vector3.UP, pl.yaw)
	var local := basis.inverse() * dir
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = 0.6 + _rng.randf()
		_strafe = _rng.randf_range(-0.6, 0.6)
	cmd.move = Vector2(local.x + _strafe * 0.3, -local.z).limit_length(1.0)
	# Bunny hop on long runs, jump when stuck.
	var hs := pl.horizontal_speed()
	if hs < 1.0:
		_stuck += delta
	else:
		_stuck = 0.0
	var hop := to.length() > 12.0 and _rng.randf() < 0.7
	if _stuck > 0.5:
		cmd.jump_pressed = true
		_stuck = 0.0
		_strafe = _rng.randf_range(-1, 1)
	cmd.jump = hop and not ledge
	cmd.crouch = hs > 11.0 and _rng.randf() < 0.02


func _ground_ahead(pos: Vector3, dir: Vector3) -> bool:
	var probe := pos + dir * 2.5 + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 8.0, Game.L_WORLD)
	return not pl.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Detour around the acid pit unless we actually want to go down there.
func _route(from: Vector3, to: Vector3) -> Vector3:
	if from.y < -1.0 or to.y < -1.0:
		return to
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for r: Rect2 in world.arena.avoid_rects:
		if not _segment_hits(a, b, r):
			continue
		var g := r.grow(2.0)
		var corners := [g.position, g.position + Vector2(g.size.x, 0), g.position + Vector2(0, g.size.y), g.end]
		var best: Vector2 = corners[0]
		var best_cost := INF
		for c: Vector2 in corners:
			if _segment_hits(a, c, r):
				continue
			var cost := a.distance_to(c) + c.distance_to(b)
			if cost < best_cost:
				best_cost = cost
				best = c
		return Vector3(best.x, from.y, best.y)
	return to


func _segment_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for i in 9:
		if r.has_point(a.lerp(b, i / 8.0)):
			return true
	return false
