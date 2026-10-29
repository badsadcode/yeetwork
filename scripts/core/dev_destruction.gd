extends Node
## Developer tool: scripted destruction showcase on Yeetwork Prime, saving screenshots.
## Usage: godot -- --host --map prime --bots 0 --tour <dir> --tour-mode destruction

var world: Node
var out_dir := ""
var pl: Player


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	pl = world.local_player
	pl.process_mode = Node.PROCESS_MODE_DISABLED
	pl.model.visible = false
	pl.collision_layer = 0
	var wall_face := Vector3(25, 3.2, -20.4)
	_cam(Vector3(25, 3.4, -26.4), wall_face)
	await _wait(3.0)
	_shot("00_wall_intact")

	# A thrown player crashing through.
	var victim := _dummy(Vector3(24, 2.2, -24.5))
	victim.external_launch(Vector3(0, 2.5, 28), true, 1.5)
	await _wait(0.35)
	_shot("01_player_impact")
	await _wait(1.2)
	_shot("02_player_hole")

	# Heavy crate.
	var crate: Prop = world.server_spawn_prop("crate_big", Transform3D(Basis.IDENTITY, Vector3(19, 2.5, -26)))
	crate.linear_velocity = Vector3(0, 1.5, 30)
	await _wait(1.0)
	_shot("03_crate_hole")

	# Fast small projectiles: small punches with crack rings.
	for i in 3:
		var b: Prop = world.server_spawn_prop("ball", Transform3D(Basis.IDENTITY, Vector3(29.5 + i * 1.2, 5.5 - i * 0.6, -26)))
		b.linear_velocity = Vector3(0, 0.5, 45)
	await _wait(1.0)
	_shot("04_projectiles")

	# Anvil.
	var anvil: Prop = world.server_spawn_prop("anvil", Transform3D(Basis.IDENTITY, Vector3(32.5, 2.0, -26)))
	anvil.linear_velocity = Vector3(0, 2, 26)
	await _wait(1.2)
	_shot("05_anvil")

	# Explosion against the wall.
	var barrel: Prop = world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, Vector3(21, 6.5, -21.3)))
	await _wait(0.2)
	world.server_explode(barrel)
	await _wait(0.25)
	_shot("06_explosion")
	await _wait(2.5)
	_shot("07_after_explosion")

	_cam(Vector3(27, 1.2, -25.5), Vector3(25, 0.4, -21))
	await _wait(1.0)
	_shot("08_debris_closeup")
	_cam(Vector3(25, 3.0, -13), Vector3(25, 3.0, -25))
	await _wait(1.0)
	_shot("09_through_holes")

	# Props shatter: a crate and a barrel smashed into the wall.
	_cam(Vector3(24, 2.6, -25.5), Vector3(28, 1.5, -20.5))
	var sc: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(26, 1.8, -23)))
	var sb: Prop = world.server_spawn_prop("barrel", Transform3D(Basis.IDENTITY, Vector3(30, 1.8, -23)))
	await _wait(0.1)
	sc.linear_velocity = Vector3(0, 1, 40)
	sb.linear_velocity = Vector3(0, 1, 42)
	await _wait(0.12)
	_shot("09b_props_shatter")
	await _wait(1.2)
	_shot("09c_props_after")

	# Glass window at the red base deck.
	_cam(Vector3(-29, 8.0, 3.5), Vector3(-37, 7.5, 0))
	await _wait(1.5)
	_shot("10_glass_intact")
	var c2: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(-32, 7.8, 0.5)))
	c2.linear_velocity = Vector3(-24, 1, 0)
	await _wait(0.3)
	_shot("11_glass_shatter")
	await _wait(1.5)
	_shot("12_glass_after")

	# Bridge: blow a hole and watch the unsupported span crumble.
	_cam(Vector3(-24, 10.5, 11), Vector3(-22, 5.0, 0))
	await _wait(1.0)
	for x in [-14.0, -30.0]:
		var bb: Prop = world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, Vector3(x, 6.6, 0)))
		await _wait(0.1)
		world.server_explode(bb)
	await _wait(0.6)
	_shot("13_bridge_blast")
	await _wait(3.0)
	_shot("14_bridge_crumble")
	await _wait(4.0)
	_shot("15_bridge_after")
	get_tree().quit()


func _dummy(pos: Vector3) -> Player:
	world._server_add_bot()
	var v: Player = null
	for p: Player in world.players.values():
		if p.is_bot:
			v = p
	v.bot_brain = null
	v.respawn(pos, 0.0)
	return v


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _cam(eye: Vector3, target: Vector3) -> void:
	var to := target - eye
	pl.global_position = eye - Vector3(0, Player.EYE_STAND, 0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	pl._head.position = Vector3(0, Player.EYE_STAND, 0)
	pl._head.rotation = Vector3(pl.pitch, pl.yaw, 0)
	pl.camera.rotation = Vector3.ZERO
	pl.camera.fov = 80.0


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	img.save_png(path)
	print("Saved ", path)
