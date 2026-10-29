extends Node
## Developer tool: fires effects in front of a still camera and saves frames over time
## (explosion, dust, impacts, splash), to judge the particles and shaders.
## Usage: godot -- --host --map lagoon --bots 0 --tour <dir> --tour-mode fx [--graphics 0|1|2]

var world: Node
var out_dir := ""
var pl: Player


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.set_physics_process(false)
	world.hud.visible = false
	# Lagoon: standing on the north side of the ring, looking along it (open sky).
	_look(Vector3(17, 1.8, -3), Vector3(17, 4.0, -13))
	await _wait(0.8)
	var fx: Effects = world.fx
	fx.explosion(Vector3(17, 1.0, -13), 7.5)
	for t in [0.12, 0.35, 0.8, 1.5, 2.4, 3.2]:
		await _until(t)
		_shot("boom_%.2f" % t)
	_t0 = -1.0
	await _wait(1.5)
	fx.dust(Vector3(15.5, 0.3, -6), Color(0.9, 0.86, 0.8), 2.0)
	fx.impact(Vector3(19, 0.1, -6), Vector3.UP, 2.0, "stone")
	fx.ground_dust(Vector3(17, 0.05, -2), 1.0)
	for t in [0.2, 0.6, 1.2]:
		await _until(t)
		_shot("dust_%.1f" % t)
	_t0 = -1.0
	# The gravity gun's electric arc: pulling a crate, holding it, charging a throw.
	pl.set_physics_process(true)
	_look(Vector3(-12, 1.6, -14), Vector3(0, 1.6, -14))
	await _wait(0.4)
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, pl.eye_position() + pl.aim_direction() * 9.0 + Vector3.UP * 0.5))
	await _wait(0.8)
	_look(pl.eye_position(), crate.global_position) # aim right at it once it has landed
	await _wait(0.1)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	for t in [0.25, 0.45]:
		await _until(t)
		_shot("arc_pull_%.2f" % t, false)
	_t0 = -1.0
	await _wait(0.6)
	_shot("arc_hold", false)
	world.gun_action(pl, GravityGun.Action.THROW)
	await _wait(0.45)
	_shot("charge_half", false)
	await _wait(0.55)
	_shot("arc_charged", false)
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	world.gun_action(pl, GravityGun.Action.GRAB_END)
	for t in [0.25, 0.4]:
		await _until(t)
		_shot("throw_trail_%.2f" % t, false)
	_t0 = -1.0
	pl.set_physics_process(false)
	# Water on the lens, drying.
	_look(Vector3(-17, 1.8, -8), Vector3(0, 1.0, 0))
	await _wait(0.5)
	if pl.lens:
		pl.lens.wet(1.0)
	for t in [0.15, 1.0, 1.8, 3.0]:
		await _until(t)
		_shot("lens_%.1f" % t)
	get_tree().quit()


var _t0 := -1.0


func _until(t: float) -> void:
	if _t0 < 0.0:
		_t0 = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - _t0 < t:
		await get_tree().process_frame


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(eye: Vector3, target: Vector3) -> void:
	var to := target - eye
	pl.global_position = eye - Vector3(0, Player.EYE_STAND, 0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String, hide_gun := true) -> void:
	if pl.gun and hide_gun:
		pl.gun.set_viewmodel_visible(false)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
