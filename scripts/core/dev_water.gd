extends Node
## Developer tool: screenshots of liquids (sea, waterline split, underwater, acid, splash).
## Usage: godot -- --host --map courtyard --bots 0 --tour <dir> --tour-mode water
##        godot -- --host --map prime --bots 0 --tour <dir> --tour-mode water

var world: Node
var out_dir := ""
var pl: Player


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.set_physics_process(false) # park the camera exactly where we put it
	var ocean := false
	for l: Liquid in Liquid.all:
		ocean = ocean or l.ocean
	if ocean:
		await _view("sea", Vector3(-31, 0, 4), PI * 0.5 + 0.3, -0.12)
		await _view("sea_down", Vector3(-31, 0, 4), PI * 0.5 - 0.2, -0.75)
		await _view("waterline", Vector3(-44, -3.0 - Player.EYE_STAND, 6), -PI * 0.5 + 0.2, 0.02)
		await _view("underwater", Vector3(-42, -6.2 - Player.EYE_STAND, 4), -PI * 0.5 + 0.3, 0.35)
		await _view("underwater_up", Vector3(-40, -6.0 - Player.EYE_STAND, 2), -PI * 0.5, 1.1)
		pl.global_position = Vector3(-31, 0, 4)
		pl.yaw = PI * 0.5
		pl.pitch = -0.35
		world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(-40, 6, 4)), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, -6, 0))
		await get_tree().create_timer(0.62).timeout
		_shot("splash")
		await get_tree().create_timer(2.5).timeout
		_shot("floating")
	else:
		await _view("acid", Vector3(0, 0.0, 17), 0.0, -0.45)
		await _view("acid_close", Vector3(4, -4.5, 9), 0.3, -0.5)
	get_tree().quit()


func _view(shot_name: String, feet: Vector3, yaw: float, pitch: float) -> void:
	pl.global_position = feet
	pl.yaw = yaw
	pl.pitch = pitch
	await get_tree().create_timer(0.6).timeout
	_shot(shot_name)


func _shot(shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("Saved ", shot_name)
