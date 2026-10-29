extends Node
## Developer tool: screenshots of the gravity gun's arc while holding / charging / throwing.
## Usage: godot -- --host --map prime --bots 0 --tour <dir> --tour-mode charge

var world: Node
var out_dir := ""


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.respawn(Vector3(-10, 0.2, -24), -PI * 0.5)
	pl.pitch = -0.1
	await get_tree().create_timer(0.5).timeout
	world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, pl.eye_position() + pl.aim_direction() * 3.0))
	await get_tree().create_timer(0.3).timeout
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await get_tree().create_timer(0.8).timeout
	world.gun_adjust(pl, 2.5, 0.6, 0.3)
	pl.yaw += 0.35 # the arc should bend while the barrel catches up
	await get_tree().create_timer(0.15).timeout
	_shot("holding")
	await get_tree().create_timer(0.8).timeout
	pl._view_third_person = true
	await get_tree().create_timer(0.6).timeout
	_shot("holding_third_person")
	pl._view_third_person = false
	await get_tree().create_timer(0.5).timeout
	world.gun_action(pl, GravityGun.Action.THROW)
	await get_tree().create_timer(0.85).timeout
	_shot("charging")
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await get_tree().create_timer(0.12).timeout
	_shot("released")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("Saved ", shot_name)
