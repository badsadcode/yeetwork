class_name Player
extends CharacterBody3D
## Arena-movement character. The peer that controls a player (its owner, or the server for
## bots) simulates it and streams its state; everyone else interpolates.
##
## Movement: Quake-style ground/air acceleration (strafe jumping + bunny hopping), air
## control, crouch sliding with slope gravity, wall running, wall jumping, ramp jumps
## (upward velocity from slopes is kept when jumping), and momentum preserved on landing.

enum State { NORMAL, RAGDOLL, HELD, DEAD }

const F_GROUNDED := 1
const F_CROUCHED := 2
const F_SLIDING := 4
const F_WALLRUN := 8
const F_RAGDOLL := 16
const F_HELD := 32
const F_DEAD := 64

const RADIUS := 0.4
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.05
const EYE_STAND := 1.6
const EYE_CROUCH := 0.85
const MASS := 80.0

const GRAVITY := 24.0
const MAX_SPEED := 9.5
const CROUCH_SPEED := 4.5
const GROUND_ACCEL := 11.0
const AIR_ACCEL := 14.0
const AIR_CAP := 1.1
const AIR_CONTROL := 1.2
const FRICTION := 6.0
const STOP_SPEED := 3.0
const JUMP_VELOCITY := 8.6
const SLIDE_MIN_SPEED := 7.0
const SLIDE_FRICTION := 0.35
const SLIDE_BOOST := 3.5
const WALLRUN_MIN_SPEED := 6.5
const WALLRUN_TIME := 1.6
const WALL_JUMP_PUSH := 7.0
const MAX_WALL_JUMPS := 3

const HURT_WALL := 17.0
const HURT_WALL_RAGDOLL := 11.0
const HURT_FLOOR := 21.0
const HURT_FLOOR_RAGDOLL := 14.0
const BREAK_SPEED := 20.0
const BREAK_SPEED_LAUNCHED := 13.0


class Cmd:
	var move := Vector2.ZERO # x = right, y = forward
	var jump := false
	var jump_pressed := false
	var crouch := false


# Identity (replicated).
var player_id := 0
var owner_peer := 1
var is_bot := false
var display_name := "Player"
var team := 0
var color := Color.WHITE
var hat := 0

# Gameplay (server authoritative, replicated).
var hp := 100.0
var frags := 0
var deaths := 0
var score := 0
var last_attacker := 0
var last_attacker_time := -100.0

var state: int = State.NORMAL
var yaw := 0.0
var pitch := 0.0
var cmd := Cmd.new()
var world: Node
var model: CharacterModel
var gun: GravityGun
var bot_brain: RefCounted

var crouched := false
var sliding := false
var wallrunning := false
var wall_normal := Vector3.ZERO
var flags := 0

var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _head: Node3D
var _arm: SpringArm3D
var camera: Camera3D
var _trail: CPUParticles3D
var _eye_height := EYE_STAND
var _air_time := 0.0
var _jump_buffer := 0.0
var _jump_held_last := false
var _wallrun_time := 0.0
var _wallrun_cooldown := 0.0
var _last_wall_normal := Vector3.ZERO
var _wall_jumps := MAX_WALL_JUMPS
var _slide_boost_cd := 0.0
var _ragdoll_time := 0.0
var _launched_until := 0.0
var _held_target := Vector3.ZERO
var _held_vel := Vector3.ZERO
var _held_last_update := 0.0
var _held_by := 0
var _impact_cooldown := 0.0
var _send_accum := 0.0
var _exceptions := {} # collider -> expiry time
var _landing_dip := 0.0
var _shake := 0.0
var _cam_roll := 0.0
var _tilt := 0.0
var _prev_grounded := true
var _view_third_person := false
var _corpse: Node3D

# Remote interpolation.
var _net_pos := Vector3.ZERO
var _net_vel := Vector3.ZERO
var _net_age := 0.0


func setup(p_world: Node, info: Dictionary) -> void:
	world = p_world
	player_id = info.id
	owner_peer = info.owner
	is_bot = info.get("bot", false)
	display_name = info.name
	team = info.team
	color = info.color
	hat = info.get("hat", 0)
	frags = info.get("frags", 0)
	deaths = info.get("deaths", 0)
	score = info.get("score", 0)
	name = "P%d" % player_id


func _ready() -> void:
	collision_layer = Game.L_PLAYERS
	collision_mask = Game.L_WORLD | Game.L_PLAYERS | Game.L_PROPS
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	floor_constant_speed = false
	floor_stop_on_slope = true
	max_slides = 6
	wall_min_slide_angle = deg_to_rad(5.0)

	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = STAND_HEIGHT * 0.5
	add_child(_collision)

	model = CharacterModel.new()
	add_child(model)
	model.setup(color, hat, player_id)

	_head = Node3D.new()
	_head.position.y = EYE_STAND
	add_child(_head)

	gun = GravityGun.new()
	gun.player = self
	add_child(gun)

	_trail = CPUParticles3D.new()
	_trail.amount = 24
	_trail.lifetime = 0.5
	_trail.local_coords = false
	_trail.emitting = false
	_trail.position.y = 0.9
	var tm := SphereMesh.new()
	tm.radius = 0.12
	tm.height = 0.24
	_trail.mesh = tm
	_trail.material_override = Mats.glow(color.lightened(0.2), 1.5)
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.2
	_trail.gravity = Vector3.ZERO
	_trail.spread = 10.0
	_trail.initial_velocity_max = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_trail.scale_amount_curve = curve
	add_child(_trail)

	if is_local_human():
		_arm = SpringArm3D.new()
		_arm.collision_mask = Game.L_WORLD
		_arm.spring_length = 0.0
		_arm.margin = 0.2
		_arm.add_excluded_object(get_rid())
		_head.add_child(_arm)
		camera = Camera3D.new()
		camera.fov = Game.fov
		camera.near = 0.05
		camera.far = 800.0
		_arm.add_child(camera)
		camera.make_current()
		gun.build_viewmodel(camera)
		_view_third_person = Game.third_person
	_net_pos = global_position
	_update_view_mode()


# --- Roles ----------------------------------------------------------------------

func is_controlled_here() -> bool:
	if is_bot:
		return multiplayer.is_server()
	return owner_peer == multiplayer.get_unique_id()


func is_local_human() -> bool:
	return not is_bot and owner_peer == multiplayer.get_unique_id()


func is_alive() -> bool:
	return state != State.DEAD


func eye_position() -> Vector3:
	return global_position + Vector3(0, _eye_height, 0)


func aim_direction() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD


func body_center() -> Vector3:
	return global_position + Vector3(0, _capsule.height * 0.5, 0)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# --- Main loop ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_human() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		yaw -= e.relative.x * Game.mouse_sensitivity
		pitch = clampf(pitch - e.relative.y * Game.mouse_sensitivity, -1.55, 1.55)
	elif event.is_action_pressed("toggle_view"):
		_view_third_person = not _view_third_person
		Game.third_person = _view_third_person
		_update_view_mode()


func _physics_process(delta: float) -> void:
	_expire_exceptions()
	if is_controlled_here():
		if is_local_human():
			_read_local_input(delta)
		elif is_bot and bot_brain:
			bot_brain.call("think", delta)
		_simulate(delta)
		_send_accum += delta
		if _send_accum >= 1.0 / 30.0:
			_send_accum = 0.0
			world.net_send_player_state(self)
	else:
		_interpolate_remote(delta)
	if multiplayer.is_server() and gun:
		gun.server_tick(delta)


func _process(delta: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	model.animate(delta, velocity, flags, yaw, _held_by != 0)
	_trail.emitting = hv.length() > 15.0 or state == State.RAGDOLL and velocity.length() > 10.0
	if camera:
		_update_camera(delta)
	if gun:
		gun.update_visuals(delta)


func _read_local_input(_delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured:
		cmd.move = Vector2.ZERO
		cmd.jump = false
		cmd.jump_pressed = false
		cmd.crouch = false
		return
	# Gamepad look.
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.05:
		yaw -= look.x * 3.2 * get_physics_process_delta_time()
		pitch = clampf(pitch - look.y * 2.4 * get_physics_process_delta_time(), -1.55, 1.55)
	cmd.move = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))
	var jump_now := Input.is_action_pressed("jump")
	cmd.jump_pressed = jump_now and not _jump_held_last
	_jump_held_last = jump_now
	cmd.jump = jump_now
	cmd.crouch = Input.is_action_pressed("crouch")
	if not is_alive():
		return
	if Input.is_action_just_pressed("gun_grab"):
		world.gun_action(self, GravityGun.Action.GRAB_START)
	if Input.is_action_just_released("gun_grab"):
		world.gun_action(self, GravityGun.Action.GRAB_END)
	if Input.is_action_just_pressed("gun_throw"):
		world.gun_action(self, GravityGun.Action.THROW)
	if Input.is_action_just_pressed("freeze_prop"):
		world.gun_action(self, GravityGun.Action.FREEZE)
	if Input.is_action_just_pressed("spawn_prop"):
		world.request_spawn_prop(self, gun.selected_slot)
	if Input.is_action_just_pressed("suicide"):
		world.request_suicide(self)
	for i in range(1, 10):
		if Input.is_action_just_pressed("slot_%d" % i):
			gun.selected_slot = i - 1
	if Input.is_action_just_pressed("next_slot"):
		gun.selected_slot = (gun.selected_slot + 1) % Prop.SPAWNABLE.size()
	if Input.is_action_just_pressed("prev_slot"):
		gun.selected_slot = (gun.selected_slot + Prop.SPAWNABLE.size() - 1) % Prop.SPAWNABLE.size()


func _simulate(delta: float) -> void:
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	_wallrun_cooldown = maxf(_wallrun_cooldown - delta, 0.0)
	_slide_boost_cd = maxf(_slide_boost_cd - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if cmd.jump_pressed:
		_jump_buffer = 0.15
	match state:
		State.NORMAL:
			_move_normal(delta)
		State.RAGDOLL:
			_move_ragdoll(delta)
		State.HELD:
			_move_held(delta)
		State.DEAD:
			velocity = Vector3.ZERO
	if global_position.y < world.arena.kill_y and state != State.DEAD:
		report_hazard_damage(1000.0, "void")
	_update_flags()


func _update_flags() -> void:
	flags = 0
	if is_on_floor():
		flags |= F_GROUNDED
	if crouched:
		flags |= F_CROUCHED
	if sliding:
		flags |= F_SLIDING
	if wallrunning:
		flags |= F_WALLRUN
	match state:
		State.RAGDOLL:
			flags |= F_RAGDOLL
		State.HELD:
			flags |= F_HELD
		State.DEAD:
			flags |= F_DEAD


# --- Normal movement --------------------------------------------------------------

func _wish_dir() -> Vector3:
	var basis := Basis(Vector3.UP, yaw)
	var w := basis * Vector3(cmd.move.x, 0, -cmd.move.y)
	if w.length_squared() > 1.0:
		w = w.normalized()
	return w


func _move_normal(delta: float) -> void:
	var wish := _wish_dir()
	var wish_speed := wish.length()
	var wish_dir := wish.normalized() if wish_speed > 0.0 else Vector3.ZERO
	var grounded := is_on_floor()

	# Crouch / stand.
	if cmd.crouch and not crouched:
		_set_crouched(true)
		if grounded and horizontal_speed() > SLIDE_MIN_SPEED:
			_start_slide()
	elif not cmd.crouch and crouched and _can_stand():
		_set_crouched(false)
	if not crouched:
		sliding = false

	if grounded:
		if not _prev_grounded:
			_on_landed()
		_air_time = 0.0
		_wall_jumps = MAX_WALL_JUMPS
		wallrunning = false
		var want_jump := _jump_buffer > 0.0 or (cmd.jump and _auto_hop())
		if want_jump:
			_do_jump()
			grounded = false
	if grounded:
		if sliding:
			_slide(delta, wish_dir)
		else:
			_friction(delta, FRICTION)
			_accelerate(wish_dir, (CROUCH_SPEED if crouched else MAX_SPEED) * wish_speed, GROUND_ACCEL, delta)
		var floor_n := get_floor_normal()
		if floor_n.is_normalized():
			velocity = velocity.slide(floor_n)
	else:
		_air_time += delta
		_air_move(delta, wish_dir, wish_speed)

	_prev_grounded = grounded
	_move_and_collide_events()


func _auto_hop() -> bool:
	return Game.auto_bhop or is_bot


func _do_jump() -> void:
	var up_v := maxf(velocity.y, 0.0) + JUMP_VELOCITY
	if sliding:
		sliding = false
		up_v *= 0.92
	velocity.y = up_v
	_jump_buffer = 0.0
	_prev_grounded = false
	if model:
		model.squash(-0.15)
	Sfx.play3d("jump", global_position, -8.0, randf_range(0.95, 1.1))


func _on_landed() -> void:
	_landing_dip = clampf(-velocity.y * 0.01, 0.0, 0.25)
	if model:
		model.squash(0.2)
	if _air_time > 0.3:
		Sfx.play3d("land", global_position, -10.0, randf_range(0.9, 1.1))


func _air_move(delta: float, wish_dir: Vector3, wish_speed: float) -> void:
	var hspeed := horizontal_speed()
	if wallrunning:
		_wallrun_time += delta
		var hit := _probe_wall(true)
		var keep: bool = not hit.is_empty() and _wallrun_time < WALLRUN_TIME and hspeed > 4.0 and cmd.move.y > 0.1
		if keep:
			wall_normal = hit.normal
			velocity -= wall_normal * velocity.dot(wall_normal)
			velocity -= wall_normal * 1.5 * delta * 10.0
			var along := Vector3(velocity.x, 0, velocity.z).normalized()
			_accelerate(along, MAX_SPEED * 1.15, 4.0, delta)
			var sag := -1.0 - _wallrun_time * 3.0
			velocity.y = move_toward(velocity.y, sag, GRAVITY * 0.6 * delta)
			if cmd.jump_pressed:
				velocity += wall_normal * WALL_JUMP_PUSH + along * 1.5
				velocity.y = JUMP_VELOCITY
				_end_wallrun()
				Sfx.play3d("jump", global_position, -6.0, 1.25)
			return
		_end_wallrun()
	else:
		if _wallrun_cooldown <= 0.0 and _air_time > 0.12 and cmd.move.y > 0.1 and hspeed > WALLRUN_MIN_SPEED and velocity.y > -10.0:
			var hit := _probe_wall(true)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				var hdir := Vector3(velocity.x, 0, velocity.z).normalized()
				var same_wall := n.dot(_last_wall_normal) > 0.9
				if absf(hdir.dot(n)) < 0.75 and not same_wall:
					wallrunning = true
					_wallrun_time = 0.0
					wall_normal = n
					velocity.y = maxf(velocity.y, 2.0)
					return
		if cmd.jump_pressed and _wall_jumps > 0 and _air_time > 0.08:
			var hit := _probe_wall(false)
			if not hit.is_empty():
				var n: Vector3 = hit.normal
				velocity -= n * minf(velocity.dot(n), 0.0)
				velocity += n * WALL_JUMP_PUSH
				velocity.y = maxf(velocity.y, 0.0) + JUMP_VELOCITY * 0.95
				_wall_jumps -= 1
				_jump_buffer = 0.0
				if model:
					model.squash(-0.15)
				Sfx.play3d("jump", global_position, -6.0, 1.15)
	_air_accelerate(wish_dir, wish_speed * MAX_SPEED, delta)
	_air_control(wish_dir, delta)
	velocity.y -= GRAVITY * delta


func _end_wallrun() -> void:
	if wallrunning:
		_last_wall_normal = wall_normal
		_wallrun_cooldown = 0.25
	wallrunning = false


func _probe_wall(sides_only: bool) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.9, 0)
	var basis := Basis(Vector3.UP, yaw)
	var dirs := [basis.x, -basis.x]
	if not sides_only:
		dirs.append_array([basis.z, -basis.z, (basis.x + basis.z).normalized(), (basis.x - basis.z).normalized(), (-basis.x + basis.z).normalized(), (-basis.x - basis.z).normalized()])
	var best := {}
	var best_d := INF
	for d in dirs:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * (RADIUS + 0.55), Game.L_WORLD | Game.L_PROPS, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if absf(n.y) > 0.35:
			continue
		var dist := origin.distance_to(hit.position)
		if dist < best_d:
			best_d = dist
			best = hit
	return best


func _set_crouched(c: bool) -> void:
	crouched = c
	_capsule.height = CROUCH_HEIGHT if c else STAND_HEIGHT
	_collision.position.y = _capsule.height * 0.5


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = RADIUS * 0.95
	probe.height = STAND_HEIGHT
	params.shape = probe
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.05, 0))
	params.collision_mask = Game.L_WORLD
	params.exclude = [get_rid()]
	return space.intersect_shape(params, 1).is_empty()


func _start_slide() -> void:
	sliding = true
	if _slide_boost_cd <= 0.0:
		var hdir := Vector3(velocity.x, 0, velocity.z).normalized()
		velocity += hdir * SLIDE_BOOST
		_slide_boost_cd = 1.2
	Sfx.play3d("slide", global_position, -8.0, randf_range(0.9, 1.1))


func _slide(delta: float, wish_dir: Vector3) -> void:
	var n := get_floor_normal()
	var g := Vector3.DOWN * GRAVITY
	velocity += (g - n * g.dot(n)) * delta
	_friction(delta, SLIDE_FRICTION)
	_accelerate(wish_dir, 2.0, 3.0, delta)
	if velocity.length() < 4.5:
		sliding = false


func _friction(delta: float, amount: float) -> void:
	var speed := velocity.length()
	if speed < 0.05:
		velocity = Vector3.ZERO
		return
	var control := maxf(speed, STOP_SPEED)
	var new_speed := maxf(speed - control * amount * delta, 0.0)
	velocity *= new_speed / speed


func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO:
		return
	var current := velocity.dot(wish_dir)
	var add := wish_speed - current
	if add <= 0.0:
		return
	velocity += wish_dir * minf(accel * delta * wish_speed, add)


func _air_accelerate(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO:
		return
	var capped := minf(wish_speed, AIR_CAP)
	var current := velocity.dot(wish_dir)
	var add := capped - current
	if add <= 0.0:
		return
	velocity += wish_dir * minf(AIR_ACCEL * wish_speed * delta, add)


## CPM-style air control: holding only forward gently bends velocity toward the view.
func _air_control(wish_dir: Vector3, delta: float) -> void:
	if wish_dir == Vector3.ZERO or absf(cmd.move.x) > 0.1 or cmd.move.y <= 0.0:
		return
	var hv := Vector3(velocity.x, 0, velocity.z)
	var speed := hv.length()
	if speed < 0.5:
		return
	var dir := hv / speed
	var d := dir.dot(wish_dir)
	if d <= 0.0:
		return
	var k := 32.0 * AIR_CONTROL * d * d * delta
	dir = (dir * speed + wish_dir * k).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


# --- Ragdoll / held -------------------------------------------------------------

func _move_ragdoll(delta: float) -> void:
	_ragdoll_time -= delta
	velocity.y -= GRAVITY * delta
	if is_on_floor():
		_friction(delta, 3.0)
	_move_and_collide_events()
	var settled := is_on_floor() and velocity.length() < 3.0
	if (_ragdoll_time <= 0.0 and settled) or _ragdoll_time < -3.0:
		_recover()


func _move_held(_delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 - _held_last_update > 0.35:
		_release_from_hold(0.3)
		return
	var to := _held_target - body_center()
	velocity = (to * 14.0 + _held_vel).limit_length(45.0)
	if cmd.jump_pressed:
		world.request_break_free(self)
	_move_and_collide_events()


func enter_ragdoll(time: float) -> void:
	if state == State.DEAD:
		return
	if state != State.RAGDOLL:
		state = State.RAGDOLL
		_set_crouched(false)
		sliding = false
		wallrunning = false
	_ragdoll_time = maxf(_ragdoll_time, time)


func _recover() -> void:
	state = State.NORMAL
	_ragdoll_time = 0.0
	if model:
		model.squash(0.3)


func _release_from_hold(ragdoll_time: float) -> void:
	_held_by = 0
	if state == State.HELD:
		state = State.NORMAL
		if ragdoll_time > 0.0:
			enter_ragdoll(ragdoll_time)


## Called on the controlling peer. `replace` sets velocity instead of adding to it.
func external_launch(vel: Vector3, replace: bool, ragdoll_time: float) -> void:
	if state == State.DEAD:
		return
	if state == State.HELD:
		_held_by = 0
		state = State.NORMAL
	if replace:
		velocity = vel
	else:
		velocity += vel
	if vel.y > 0.0:
		_prev_grounded = false
		position.y += 0.05
	_launched_until = Time.get_ticks_msec() / 1000.0 + 1.5
	if ragdoll_time > 0.0:
		enter_ragdoll(ragdoll_time)


## Called on the controlling peer while a gravity gun holds this player.
func held_update(target: Vector3, holder_vel: Vector3, holder_id: int) -> void:
	if state == State.DEAD:
		return
	_held_target = target
	_held_vel = holder_vel
	_held_by = holder_id
	_held_last_update = Time.get_ticks_msec() / 1000.0
	if state != State.HELD:
		state = State.HELD
		_set_crouched(false)
		wallrunning = false
		sliding = false


func held_release(ragdoll_time: float) -> void:
	_release_from_hold(ragdoll_time)


func report_hazard_damage(amount: float, cause: String) -> void:
	world.report_self_damage(self, amount, cause, global_position + Vector3.UP, Vector3.UP, velocity)


# --- Collisions & impacts ---------------------------------------------------------

func _move_and_collide_events() -> void:
	var pre := velocity
	var was_air := not is_on_floor()
	move_and_slide()
	var now := Time.get_ticks_msec() / 1000.0
	var launched := state == State.RAGDOLL or state == State.HELD or now < _launched_until
	var worst := 0.0
	var worst_col: KinematicCollision3D
	var restore := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		var impact := -pre.dot(n)
		if impact <= 0.5:
			continue
		var other := col.get_collider()
		if other is StaticBody3D and (other as Node).has_meta("destructible"):
			var threshold := BREAK_SPEED_LAUNCHED if launched else BREAK_SPEED
			if impact > threshold:
				var d: Destructible = other.get_meta("destructible")
				world.report_break(self, d, other.get_meta("cell"), col.get_position(), impact, pre)
				# Fly on through: ignore the cells we are about to smash.
				for c in d.cells_near(col.get_position(), 1.6):
					var b := d.cell_body(c)
					if b:
						_add_temp_exception(b, 0.6)
				restore = true
				continue
		elif other is Player:
			var o := other as Player
			var rel := pre - o.velocity
			if rel.length() > 7.0 and _impact_cooldown <= 0.0:
				world.report_player_bump(self, o, pre)
				_impact_cooldown = 0.25
				velocity = pre * 0.3
			continue
		elif other is Prop:
			var p := other as Prop
			if not p.freeze or not multiplayer.is_server():
				world.report_prop_push(self, p, pre, col.get_position())
				if p.mass < 30.0 and pre.length() > 6.0 and not p.frozen_by_player:
					_add_temp_exception(p, 0.35)
					restore = true
			if pre.length() < 12.0:
				continue
		if impact > worst:
			worst = impact
			worst_col = col
		if state == State.RAGDOLL and impact > 4.0:
			velocity = pre.bounce(n) * 0.35
	if restore:
		velocity = pre * 0.85
	if worst_col and _impact_cooldown <= 0.0:
		var n := worst_col.get_normal()
		var floor_hit := n.y > 0.7
		var threshold: float
		if floor_hit:
			threshold = HURT_FLOOR_RAGDOLL if launched else HURT_FLOOR
		else:
			threshold = HURT_WALL_RAGDOLL if launched else HURT_WALL
		if worst > threshold:
			_impact_cooldown = 0.2
			var dmg := (worst - threshold) * 4.0 + 5.0
			world.report_self_damage(self, dmg, "impact", worst_col.get_position(), n, pre)
			_shake = clampf(worst / 30.0, 0.2, 1.0)
			if worst > threshold + 6.0:
				enter_ragdoll(1.2)
			Sfx.play3d("thud", worst_col.get_position(), 0.0, randf_range(0.8, 1.0))
		elif worst > 9.0 and was_air:
			Sfx.play3d("land", global_position, -6.0, 0.8)


func _add_temp_exception(body: Node, time: float) -> void:
	if body is PhysicsBody3D:
		add_collision_exception_with(body)
		_exceptions[body] = Time.get_ticks_msec() / 1000.0 + time


func _expire_exceptions() -> void:
	if _exceptions.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for b in _exceptions.keys():
		if not is_instance_valid(b):
			_exceptions.erase(b)
		elif now > _exceptions[b]:
			if gun == null or gun.held_node() != b:
				remove_collision_exception_with(b)
			_exceptions.erase(b)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# --- Networking -------------------------------------------------------------------

func get_net_state() -> Array:
	return [player_id, global_position, velocity, yaw, pitch, flags]


func apply_net_state(pos: Vector3, vel: Vector3, p_yaw: float, p_pitch: float, p_flags: int) -> void:
	if is_controlled_here():
		return
	_net_pos = pos
	_net_vel = vel
	_net_age = 0.0
	velocity = vel
	yaw = p_yaw
	pitch = p_pitch
	flags = p_flags
	var c := (p_flags & F_CROUCHED) != 0
	if c != crouched:
		_set_crouched(c)
	match state:
		State.DEAD:
			pass
		_:
			if p_flags & F_RAGDOLL:
				state = State.RAGDOLL
			elif p_flags & F_HELD:
				state = State.HELD
			else:
				state = State.NORMAL


func _interpolate_remote(delta: float) -> void:
	_net_age += delta
	var predicted := _net_pos + _net_vel * minf(_net_age, 0.15)
	if global_position.distance_to(predicted) > 6.0:
		global_position = predicted
	else:
		global_position = global_position.lerp(predicted, 1.0 - exp(-18.0 * delta))


# --- Life cycle (all peers) -------------------------------------------------------

func die(death_velocity: Vector3) -> void:
	state = State.DEAD
	hp = 0.0
	_held_by = 0
	wallrunning = false
	sliding = false
	model.visible = false
	collision_layer = 0
	if gun:
		gun.on_owner_died()
	var corpse := Ragdoll.spawn(world.fx_root, model, global_transform, death_velocity, color)
	world.track_corpse(corpse)
	if is_local_human():
		_corpse = corpse
	_update_flags()


func respawn(pos: Vector3, p_yaw: float) -> void:
	state = State.NORMAL
	hp = 100.0
	global_position = pos
	_net_pos = pos
	velocity = Vector3.ZERO
	yaw = p_yaw
	pitch = 0.0
	_ragdoll_time = 0.0
	_held_by = 0
	collision_layer = Game.L_PLAYERS
	model.visible = true
	_corpse = null
	_set_crouched(false)
	_update_view_mode()
	_update_flags()


# --- Camera -------------------------------------------------------------------------

func _update_view_mode() -> void:
	if not is_local_human() or model == null:
		return
	var tp := _view_third_person or state == State.RAGDOLL or state == State.DEAD
	model.set_first_person(not tp)
	if gun:
		gun.set_viewmodel_visible(not tp and state != State.DEAD)
	if _arm:
		_arm.spring_length = 4.0 if tp else 0.0


func _update_camera(delta: float) -> void:
	_update_view_mode()
	var target_eye := EYE_CROUCH if crouched else EYE_STAND
	_eye_height = lerpf(_eye_height, target_eye, 1.0 - exp(-14.0 * delta))
	_landing_dip = lerpf(_landing_dip, 0.0, 1.0 - exp(-8.0 * delta))
	if state == State.DEAD and is_instance_valid(_corpse):
		var torso: Node3D = _corpse.get("torso")
		var focus := torso.global_position if torso else _corpse.global_position
		_head.global_position = _head.global_position.lerp(focus + Vector3(0, 1.0, 0), 1.0 - exp(-6.0 * delta))
	else:
		_head.position = Vector3(0, _eye_height - _landing_dip, 0)
	_head.rotation = Vector3(pitch, yaw, 0)
	# Roll: wall running leans away from the wall; strafing tilts slightly.
	var roll_target := 0.0
	if wallrunning:
		var right := Basis(Vector3.UP, yaw).x
		roll_target = -signf(right.dot(wall_normal)) * deg_to_rad(9.0)
	else:
		roll_target = -cmd.move.x * deg_to_rad(1.5)
	_cam_roll = lerpf(_cam_roll, roll_target, 1.0 - exp(-8.0 * delta))
	var shake_off := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.8, 0.0)
		var s := _shake * _shake
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * s * 0.06
	camera.rotation = Vector3(shake_off.x, shake_off.y, _cam_roll)
	var speed_fov := clampf((horizontal_speed() - MAX_SPEED) * 1.1, 0.0, 22.0)
	camera.fov = lerpf(camera.fov, Game.fov + speed_fov, 1.0 - exp(-5.0 * delta))
