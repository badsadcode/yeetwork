extends Node
## Developer tool: screenshots of a charged gravity-gun throw (--tour <dir> --tour-mode charge).
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
	world.gun_action(pl, GravityGun.Action.THROW)
	await get_tree().create_timer(0.85).timeout
	get_viewport().get_texture().get_image().save_png(out_dir + "/charging.png")
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await get_tree().create_timer(0.12).timeout
	get_viewport().get_texture().get_image().save_png(out_dir + "/released.png")
	print("Saved charge shots")
	get_tree().quit()
