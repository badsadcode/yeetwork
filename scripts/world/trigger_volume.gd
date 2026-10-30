class_name TriggerVolume
extends Area3D
## Jump pads, acid, water and wind. Players are affected by the peer that controls them;
## props are affected on the server only.

enum Kind { JUMP_PAD, ACID, WIND, KILL, WATER }

var kind: int = Kind.JUMP_PAD
var launch_velocity := Vector3.ZERO
var strength := 0.0
var _cooldowns := {}
var _splash_cooldowns := {}
## The Liquid this volume belongs to (acid / lava / water), for surface height and splashes.
var liquid: Liquid

## Upward speed of a water jump: clears a ledge about 1.5 m above the surface.
const WATER_JUMP := 11.0
## Swimming speed and stroke acceleration in pools.
const SWIM_SPEED := 5.0
const SWIM_ACCEL := 14.0


func setup(p_kind: int, size: Vector3, p_velocity := Vector3.ZERO, p_strength := 0.0) -> void:
	kind = p_kind
	launch_velocity = p_velocity
	strength = p_strength
	collision_layer = Game.L_TRIGGERS
	collision_mask = Game.L_PLAYERS | Game.L_PROPS
	monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## The ocean leaves alone whatever is in a pool (or acid, lava) inside its area: there the
## smaller liquid's rules apply, not both at once.
func _ceded(body: Node3D) -> bool:
	if liquid == null or not liquid.ocean or not is_instance_valid(body):
		return false
	for l in Liquid.all:
		if is_instance_valid(l) and l != liquid and not l.ocean and l.contains_xz(body.global_position):
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if liquid == null or _ceded(body):
		return
	var v := Vector3.ZERO
	var scale := 1.0
	if body is Player:
		v = (body as Player).velocity
	elif body is Prop:
		var p := body as Prop
		v = p.motion_velocity() # clients: props are kinematic, use the streamed velocity
		scale = clampf(p.size.length() / 1.2, 0.3, 1.5) # debris makes small splashes
	elif body is RigidBody3D:
		v = (body as RigidBody3D).linear_velocity
	# Something bobbing at the surface (or bouncing on acid) splashes at most every 0.6 s.
	var now := Time.get_ticks_msec() / 1000.0
	if _splash_cooldowns.size() > 64:
		_prune(_splash_cooldowns, now)
		_prune(_cooldowns, now)
	if v.length() > 2.5 and now - _splash_cooldowns.get(body, -10.0) > 0.6:
		_splash_cooldowns[body] = now
		liquid.splash(body.global_position, v.length() * scale)


## Forget cooldowns of bodies that are gone or long finished (debris comes and goes).
static func _prune(d: Dictionary, now: float) -> void:
	for k in d.keys():
		if not is_instance_valid(k) or now - d[k] > 2.0:
			d.erase(k)


## Bursting back out of a liquid (jumping out, being yanked out) splashes too.
func _on_body_exited(body: Node3D) -> void:
	if liquid == null or not is_instance_valid(body) or _ceded(body):
		return
	var v := Vector3.ZERO
	if body is Player:
		v = (body as Player).velocity
	elif body is Prop:
		v = (body as Prop).motion_velocity()
	var now := Time.get_ticks_msec() / 1000.0
	if v.y > 3.0 and now - _splash_cooldowns.get(body, -10.0) > 0.6:
		_splash_cooldowns[body] = now
		liquid.splash(body.global_position, v.length() * 0.6)


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for body in get_overlapping_bodies():
		if _ceded(body):
			continue
		if body is Player:
			var pl := body as Player
			if pl.is_controlled_here():
				_affect_player(pl, delta, now)
		elif body is Prop and multiplayer.is_server():
			_affect_prop(body as Prop, delta, now)


func _affect_player(pl: Player, delta: float, now: float) -> void:
	match kind:
		Kind.JUMP_PAD:
			if now - _cooldowns.get(pl, -10.0) < 0.5:
				return
			_cooldowns[pl] = now
			pl.external_launch(launch_velocity, false, 0.0)
			Sfx.play3d("boing", global_position, 2.0, 0.8)
		Kind.ACID:
			if now - _cooldowns.get(pl, -10.0) < 0.6:
				return
			_cooldowns[pl] = now
			pl.external_launch(Vector3(randf_range(-3, 3), 15.0, randf_range(-3, 3)), false, 0.8)
			pl.report_hazard_damage(strength, "lava" if liquid and liquid.kind == "lava" else "acid")
			Sfx.play3d("sizzle", pl.global_position, 0.0, randf_range(0.9, 1.2))
		Kind.WIND:
			pl.velocity += launch_velocity * delta
		Kind.KILL:
			if pl.is_alive():
				pl.report_hazard_damage(1000.0, "void")
		Kind.WATER:
			_swim(pl, delta)


## Water: drag, buoyancy and swimming (hold jump to rise). The open ocean is too rough to
## swim in: you sink and, deep enough, drown.
func _swim(pl: Player, delta: float) -> void:
	var depth := liquid.height_at(pl.global_position.x, pl.global_position.z) - pl.global_position.y
	if depth <= 0.0:
		return
	var sub := clampf(depth / 1.5, 0.0, 1.0)
	var drag := 2.6 if liquid.ocean else 1.8
	pl.velocity *= exp(-drag * sub * delta)
	if liquid.ocean:
		pl.velocity.y += Player.GRAVITY * 0.8 * sub * delta
		if depth > 6.0 and pl.is_alive():
			pl.report_hazard_damage(1000.0, "drown")
		return
	pl.velocity.y += Player.GRAVITY * 1.12 * sub * delta
	# Swim strokes: steer toward where you look (air control alone is far too weak here).
	var wish := Basis(Vector3.UP, pl.yaw) * Vector3(pl.cmd.move.x, 0, -pl.cmd.move.y)
	if wish.length() > 0.1:
		wish = wish.normalized()
		if Vector3(pl.velocity.x, 0, pl.velocity.z).dot(wish) < SWIM_SPEED:
			pl.velocity += wish * SWIM_ACCEL * sub * delta
	if pl.cmd.jump:
		pl.velocity.y += 16.0 * sub * delta
		# Water jump: swimming at the surface into a ledge kicks you up and out.
		if depth < 1.7 and pl.velocity.y < WATER_JUMP and _ledge_ahead(pl):
			pl.velocity.y = WATER_JUMP
	elif pl.cmd.crouch:
		pl.velocity.y -= 10.0 * sub * delta


## A wall right in front of the swimmer's chest, in the direction they swim.
func _ledge_ahead(pl: Player) -> bool:
	if pl.cmd.move.y <= 0.1:
		return false
	var fwd := Basis(Vector3.UP, pl.yaw) * Vector3(0, 0, -1)
	var chest := pl.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(chest, chest + fwd * (Player.RADIUS + 0.5), Game.L_WORLD)
	return not pl.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _affect_prop(p: Prop, delta: float, now: float) -> void:
	if p.freeze:
		return
	match kind:
		Kind.JUMP_PAD:
			if now - _cooldowns.get(p, -10.0) < 0.5:
				return
			_cooldowns[p] = now
			p.linear_velocity = launch_velocity
		Kind.ACID:
			if now - _cooldowns.get(p, -10.0) < 0.6:
				return
			_cooldowns[p] = now
			p.linear_velocity = Vector3(randf_range(-4, 4), 13.0, randf_range(-4, 4))
		Kind.WIND:
			p.linear_velocity += launch_velocity * delta
		Kind.KILL:
			if p.world:
				p.world.server_prop_fell_out(p)
		Kind.WATER:
			_float(p, delta)


## Wood, rubber and soft things float and bob on the waves; metal and stone sink.
func _float(p: Prop, delta: float) -> void:
	if p.held_by != 0:
		return
	var r := clampf(p.size.y * 0.5, 0.15, 1.0)
	var depth := liquid.height_at(p.global_position.x, p.global_position.z) - p.global_position.y
	var sub := clampf((depth + r) / (2.0 * r), 0.0, 1.0)
	if sub <= 0.0:
		return
	var floaty := 0.55 if p.impact_material() in ["metal", "stone", "concrete", "brick", "glass"] else 1.75
	p.linear_velocity.y += Player.GRAVITY * floaty * sub * delta
	p.linear_velocity *= exp(-1.6 * sub * delta)
	p.angular_velocity *= exp(-2.0 * sub * delta)
	if liquid.ocean:
		p.linear_velocity += Vector3(cos(0.3), 0, sin(0.3)) * 0.8 * sub * delta
