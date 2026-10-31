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
var _release_in := 0.0
var _hopping := false
var _miss := Vector3.ZERO # per-target aim error, re-rolled each think

# Per Game.bot_skill (easy, normal, hard). Hard is the original, merciless bot.
const TURN_RATE := [2.5, 4.0, 7.0]
const AIM_SLOP := [3.2, 1.8, 0.0] # metres of miss at the target
const LEAD := [0.0, 0.5, 1.0]
const THROW_DELAY := [1.6, 1.0, 0.4]
const SIGHT := [28.0, 42.0, 60.0]
const PUNT_REST := [3.0, 1.8, 1.0]
const HOP := [0.15, 0.4, 0.7]
const CHARGE := [0.0, 0.6, 1.0]


func _skill() -> int:
	return clampi(Game.bot_skill, 0, 2)


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
	if world.mode == Game.Mode.HOOPS:
		_think_hoops(delta)
		return
	if world.mode == Game.Mode.YEETBALL:
		_think_yeetball(delta)
		return
	if _think <= 0.0:
		_think = 0.25 + _rng.randf() * 0.2 + (2 - _skill()) * 0.1
		_miss = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 1), _rng.randf_range(-1, 1)) * AIM_SLOP[_skill()]
		_hopping = _rng.randf() < HOP[_skill()]
		_reconsider()

	var holding := pl.gun.held_kind != GravityGun.Kind.NONE
	var eye := pl.eye_position()
	var look_at := _goal + Vector3.UP
	var want_move := true

	if _release_in > 0.0:
		_release_in -= delta
		if _release_in <= 0.0 or not holding:
			_finish_throw()
	if holding:
		_hold_timer += delta
		if _carrying_flag():
			look_at = _goal + Vector3.UP
		elif _enemy and is_instance_valid(_enemy) and _enemy.is_alive():
			var d := eye.distance_to(_enemy.body_center())
			var lead: Vector3 = _enemy.velocity * clampf(d / 35.0, 0.0, 0.8) * LEAD[_skill()]
			look_at = _enemy.body_center() + lead + Vector3.UP * d * 0.02 + _miss * clampf(d / 15.0, 0.7, 1.5)
			# Weaker bots hang back to throw instead of bulldozing you with the prop.
			if _skill() < 2:
				want_move = d > 7.0 + (1 - _skill()) * 4.0
			if d < 40.0 and _hold_timer > THROW_DELAY[_skill()] and _can_see(_enemy.body_center()) and _aim_error(look_at) < 0.12:
				_throw(d)
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
					_punt_cd = PUNT_REST[_skill()] + _rng.randf()
	_aim(look_at, delta)
	_steer(delta, want_move)


## Yeetball: get behind the ball (on the far side from the goal we attack) and punt it at
## the goal; the nearest teammate goes for it, the others hang back between it and home.
func _think_yeetball(delta: float) -> void:
	var mode := world.mode_logic as ModeYeetball
	var b: Prop = mode.nearest_ball(pl.global_position) if mode else null
	var target: GoalZone = mode.goal_of(Game.TEAM_BLUE if pl.team == Game.TEAM_RED else Game.TEAM_RED) if mode else null
	var home: GoalZone = mode.goal_of(pl.team) if mode else null
	if b == null or target == null or home == null:
		_aim(pl.eye_position() + Vector3.FORWARD, delta)
		_steer(delta, false)
		return
	var bp := b.global_position
	var to_goal := target.mouth() - bp
	to_goal.y = 0.0
	var dir := to_goal.normalized()
	# Am I the closest of my team to the ball?
	var mine := pl.global_position.distance_to(bp)
	var chaser := true
	for q: Player in world.players.values():
		if q != pl and q.team == pl.team and q.is_alive() and q.global_position.distance_to(bp) < mine - 0.5:
			chaser = false
	var look_at := bp
	if chaser:
		var behind := bp - dir * 2.0
		behind.y = pl.global_position.y
		var lined_up := (bp - pl.global_position).normalized().dot(dir) > 0.6
		_goal = bp if lined_up else behind
		if mine < 6.0 and lined_up:
			# Aim at the goal mouth (a punt goes where you look) with the ball in the punt cone.
			look_at = target.mouth() + _miss * 0.4
			var eye := pl.eye_position()
			# (within 1.5 m a punt takes anything, wherever it is; farther out, it must be in the cone)
			var in_cone := eye.distance_to(bp) < 1.5 or pl.aim_direction().dot((bp - eye).normalized()) > GravityGun.PUNT_COS + 0.05
			if in_cone and _punt_cd <= 0.0 and _aim_error(look_at) < 0.2:
				world.gun_action(pl, GravityGun.Action.THROW)
				_punt_cd = PUNT_REST[_skill()] * 0.6 + _rng.randf() * 0.4
	else:
		# Hang back: between the ball and our goal.
		_goal = bp.lerp(home.global_position, 0.55)
		look_at = bp
	_hopping = _rng.randf() < HOP[_skill()] * 0.3
	_aim(look_at, delta)
	_steer(delta, pl.global_position.distance_to(_goal) > 1.0)


## YeetHoops: the nearest of a team goes for the ball (the gun pulls it in from afar); with
## it, close in on the hoop we attack and lob it in, on a high arc worked out for the throw
## speed (charged when the hoop is far). Better bots shoot from farther out and sometimes
## try a three. A teammate with the ball: get under the hoop for the rebound. An enemy with
## it: go and punt them.
const SHOOT_RANGE := [5.0, 6.0, 7.0]
const SHOT_SLOP := [0.06, 0.03, 0.012] # radians of aim error on a shot


func _think_hoops(delta: float) -> void:
	var mode := world.mode_logic as ModeHoops
	var b: Prop = mode.nearest_ball(pl.global_position) if mode else null
	var target: GoalZone = mode.goal_of(Game.TEAM_BLUE if pl.team == Game.TEAM_RED else Game.TEAM_RED) if mode else null
	var home: GoalZone = mode.goal_of(pl.team) if mode else null
	if b == null or target == null or home == null:
		_aim(pl.eye_position() + Vector3.FORWARD, delta)
		_steer(delta, false)
		return
	var held := world.get_prop(pl.gun.held_id) as Prop if pl.gun.held_kind == GravityGun.Kind.PROP else null
	var look_at := b.global_position
	var move := true
	_shot_cool -= delta
	if _release_in > 0.0:
		_release_in -= delta
		if _release_in <= 0.0 or held == null:
			_finish_throw()
			_shot_cool = 1.6 # let the shot fly (the gun would pull it straight back)
	if held and held.kind == mode.ball_kind():
		_hold_timer += delta
		var rim := target.mouth()
		var flat := Vector2(rim.x - pl.global_position.x, rim.z - pl.global_position.z).length()
		if _think <= 0.0:
			_think = 1.0
			# Sometimes (better bots more often) step back for a three.
			_shot_range = SHOOT_RANGE[_skill()] + (5.0 if _rng.randf() < 0.15 * _skill() else 0.0)
		# (aim a touch past the middle: off the back of the rim drops in, short never does)
		var dir := _lob(held.global_position, rim + Vector3.UP * 0.15 - target.global_transform.basis.z * 0.2)
		# Shoot from in front of the hoop (never from behind the board or right under it).
		var front := target.global_transform.basis.z
		var rel := pl.global_position - rim
		rel.y = 0.0
		var ahead := rel.dot(front)
		var side := rel.normalized() if ahead > 0.0 else front
		var spot := rim + (front * 0.6 + side * 0.4).normalized() * _shot_range * 0.85
		spot.y = pl.global_position.y
		# (closer than ~4 m the arc would have to be steeper than the aim allows; holding it a
		# while, take the long shot rather than lose it to the hold limit)
		var placed := ahead > 1.5 and flat > 4.0 and (flat < _shot_range + 0.5 or _hold_timer > 0.9)
		if _release_in > 0.0:
			move = false # winding up: keep the shot as it was aimed
			_set_aim(_shot_dir)
			look_at = pl.eye_position() + _shot_dir * 10.0
		elif not placed or dir == Vector3.ZERO:
			_goal = spot
			look_at = rim
		else:
			move = false
			look_at = pl.eye_position() + dir * 10.0
			# (not just before the hold limit takes the ball: the throw would become a punt)
			# Nearly on target, feet planted (a throw carries the thrower's own speed): steady
			# the aim (the skill's slop is the error) and shoot.
			var planted := pl.is_on_floor() and Vector2(pl.velocity.x, pl.velocity.z).length() < 1.5
			if planted and _aim_error(look_at) < 0.03 and _hold_timer < ModeYeetball.HOLD_LIMIT[mode.rules] - 0.3:
				var slop: float = SHOT_SLOP[_skill()]
				_shot_dir = dir.rotated(Vector3.UP, _rng.randf_range(-1, 1) * slop).rotated(dir.cross(Vector3.UP).normalized(), _rng.randf_range(-1, 1) * slop)
				_set_aim(_shot_dir)
				world.gun_action(pl, GravityGun.Action.THROW)
				_release_in = (_lob_charge + LOB_MARGIN) * GravityGun.CHARGE_TIME
	else:
		_hold_timer = 0.0
		var holder := world.get_player(b.held_by) as Player if b.held_by != 0 else null
		var mine := pl.global_position.distance_to(b.global_position)
		var chaser := true
		for q: Player in world.players.values():
			if q != pl and q.team == pl.team and q.is_alive() and q.global_position.distance_to(b.global_position) < mine - 0.5:
				chaser = false
		if holder and holder.team == pl.team:
			_goal = target.global_position.lerp(world.arena.ball_spot, 0.25) # rebound
			look_at = b.global_position
		elif holder:
			_goal = holder.global_position
			look_at = holder.body_center()
			if mine < 5.0 and _punt_cd <= 0.0 and _aim_error(look_at) < 0.25:
				world.gun_action(pl, GravityGun.Action.THROW)
				_punt_cd = PUNT_REST[_skill()] + _rng.randf()
		elif _shot_cool > 0.0:
			_goal = target.global_position + target.global_transform.basis.z * 2.5 # follow it in
			look_at = b.global_position
		elif chaser:
			_goal = b.global_position
			look_at = b.global_position
			move = mine > 3.0
			# (a shot in flight is left alone: wait for it to come down)
			var flying := b.held_by == 0 and b.linear_velocity.length() > 5.0 and b.global_position.y > 2.2
			var see := not flying and mine < GravityGun.PULL_RANGE * 0.7 and _can_see(b.global_position)
			# (the gun's own state, not ours: a hold limit or a kickoff may have ended the grab)
			if see and not pl.gun.grab_active and _aim_error(look_at) < 0.08:
				world.gun_action(pl, GravityGun.Action.GRAB_START)
				_grabbing = true
			elif not see and pl.gun.grab_active:
				world.gun_action(pl, GravityGun.Action.GRAB_END)
				_grabbing = false
		else:
			_goal = b.global_position.lerp(home.global_position, 0.5)
		if pl.gun.grab_active and not chaser:
			world.gun_action(pl, GravityGun.Action.GRAB_END)
			_grabbing = false
	_hopping = held == null and _rng.randf() < HOP[_skill()] * 0.2
	_aim(look_at, delta)
	_steer(delta, move and pl.global_position.distance_to(_goal) > 1.0)



var _shot_range := 6.0
var _shot_dir := Vector3.FORWARD
var _shot_cool := 0.0
const LOB_MARGIN := 0.03 # the wind-up always charges a little: plan the throw speed with it
var _lob_charge := 0.0


func _set_aim(d: Vector3) -> void:
	pl.yaw = atan2(-d.x, -d.z)
	pl.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## The direction to throw the ball held at `from` so it drops into `to` on a high arc,
## worked out the way the physics moves it (gravity and damping, step by step), with the
## charge the distance needs (_lob_charge). ZERO: too close (or too far) for a lob.
func _lob(from: Vector3, to: Vector3) -> Vector3:
	var held := world.get_prop(pl.gun.held_id) as Prop
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
	var damp: float = held.linear_damp if held else 0.0
	if held == null or held.linear_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		damp += ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := flat.length()
	var h := to.y - from.y
	var base: float = Prop.DEFS.basketball.throw_speed * (Pickups.SUPER_MULT if pl.has_buff("super") else 1.0)
	var lo := deg_to_rad(42.0)
	var hi := deg_to_rad(78.0)
	_lob_charge = 0.0
	var v := base * (1.0 + GravityGun.CHARGE_BONUS * LOB_MARGIN)
	while _lob_reach(v, lo, h, g, damp) < d:
		_lob_charge += 0.1
		if _lob_charge > 1.0 - LOB_MARGIN:
			return Vector3.ZERO # out of reach
		v = base * (1.0 + GravityGun.CHARGE_BONUS * (_lob_charge + LOB_MARGIN))
	if _lob_reach(v, hi, h, g, damp) > d:
		return Vector3.ZERO # too close: the arc would have to be steeper
	for k in 16: # the high arc: steeper lands nearer
		var mid := (lo + hi) * 0.5
		if _lob_reach(v, mid, h, g, damp) > d:
			lo = mid
		else:
			hi = mid
	var ang := (lo + hi) * 0.5
	return flat.normalized() * cos(ang) + Vector3.UP * sin(ang)


## How far out a ball thrown at speed v and angle a comes down through height h (-1: never).
func _lob_reach(v: float, a: float, h: float, g: float, damp: float) -> float:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var keep := maxf(1.0 - damp * dt, 0.0)
	var vx := v * cos(a)
	var vy := v * sin(a)
	var x := 0.0
	var y := 0.0
	for i in 400:
		vy -= g * dt
		vx *= keep
		vy *= keep
		var nx := x + vx * dt
		var ny := y + vy * dt
		if vy < 0.0 and ny <= h:
			return x + (nx - x) * (y - h) / maxf(y - ny, 0.0001)
		x = nx
		y = ny
	return -1.0


## Starts winding up a throw; farther targets get a longer charge.
func _throw(distance := 10.0) -> void:
	if _release_in > 0.0:
		return
	world.gun_action(pl, GravityGun.Action.THROW)
	_release_in = clampf((distance - 8.0) / 25.0, 0.05, GravityGun.CHARGE_TIME) * CHARGE[_skill()] + 0.05 + _rng.randf() * 0.1


func _finish_throw() -> void:
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	_release_in = 0.0
	_grabbing = false
	_hold_timer = 0.0
	_target_prop = null


func _carrying_flag() -> bool:
	if pl.gun.held_kind != GravityGun.Kind.PROP:
		return false
	var p := world.get_prop(pl.gun.held_id) as Prop
	return p != null and p.kind == "flag"


func _pickup_goal() -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for ps: PickupSpawn in world.arena.pickups:
		if not ps.is_available():
			continue
		var d := pl.global_position.distance_to(ps.global_position)
		var want := (pl.hp < 60.0 and d < 30.0) if not Pickups.is_powerup(ps.shown_kind) else d < 12.0
		if want and d < best_d:
			best_d = d
			best = ps.global_position
	return best


func _reconsider() -> void:
	_enemy = _find_enemy()
	var holding := pl.gun.held_kind != GravityGun.Kind.NONE
	# Pickups: first aid when hurt, a power-up when one is close by.
	var pickup := _pickup_goal()
	if pickup != Vector3.INF and not _carrying_flag():
		_goal = pickup
		_target_prop = null
		return
	if world.mode == Game.Mode.PUMPKIN and not holding:
		# Candy first: walk over it.
		var best: Prop = null
		var best_d := 22.0
		for p: Prop in world.props.values():
			if is_instance_valid(p) and p.kind == "candy":
				var d := pl.global_position.distance_to(p.global_position)
				if d < best_d:
					best_d = d
					best = p
		if best:
			_goal = best.global_position
			_target_prop = null
			return
	if world.mode == Game.Mode.CTF:
		var flag := _enemy_flag()
		if _carrying_flag():
			_goal = world.arena.flag_pos(pl.team)
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
	var best_d: float = SIGHT[_skill()]
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
	var pumpkins: bool = world.mode == Game.Mode.PUMPKIN
	for p: Prop in world.props.values():
		if not is_instance_valid(p) or p.held_by != 0 or p.freeze or p.kind == "flag" or p.kind == "candy":
			continue
		if dodgeball and p.kind != "ball":
			continue
		if pumpkins and not p.kind.begins_with("pumpkin"):
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
	var k := 1.0 - exp(-TURN_RATE[_skill()] * delta)
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
	var hop := to.length() > 12.0 and _hopping
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
