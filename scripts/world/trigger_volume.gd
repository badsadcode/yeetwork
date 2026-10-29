class_name TriggerVolume
extends Area3D
## Jump pads, acid and wind. Players are affected by the peer that controls them;
## props are affected on the server only.

enum Kind { JUMP_PAD, ACID, WIND, KILL }

var kind: int = Kind.JUMP_PAD
var launch_velocity := Vector3.ZERO
var strength := 0.0
var _cooldowns := {}


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


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for body in get_overlapping_bodies():
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
			pl.report_hazard_damage(strength, "acid")
			Sfx.play3d("sizzle", pl.global_position, 0.0, randf_range(0.9, 1.2))
		Kind.WIND:
			pl.velocity += launch_velocity * delta
		Kind.KILL:
			if pl.is_alive():
				pl.report_hazard_damage(1000.0, "void")


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
