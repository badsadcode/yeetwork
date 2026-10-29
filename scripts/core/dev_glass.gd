extends Node
## Developer tool: cracks a glass window (without breaking it) and saves two frames a moment
## apart with the camera perfectly still, to see the cracks and check they don't flicker.
## Usage: godot -- --host --map prime --bots 0 --tour <dir> --tour-mode glass

var world: Node
var out_dir := ""


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.set_physics_process(false)
	world.hud.visible = false
	var pane: Destructible = null
	for d: Destructible in world.arena.destructibles:
		if d.material == "glass":
			pane = d
			break
	if pane == null:
		print("No glass on this map")
		get_tree().quit()
		return
	var c := pane.global_position
	# Light hits: enough to crack the cells, not to break them.
	for i in 6:
		var p := c + pane.global_transform.basis * Vector3(randf_range(-2.5, 2.5), randf_range(-1.0, 1.0), 0.0)
		world.server_damage_destructible(pane, p, 1.4, float(pane.matdef.hp) * 0.25, Vector3.ZERO, 0)
	var n := pane.global_transform.basis.z.normalized()
	var eye := c + n * 3.2 + Vector3(0, 0.2, 0)
	var to := c - eye
	pl.global_position = eye - Vector3(0, Player.EYE_STAND, 0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await get_tree().create_timer(1.0).timeout
	for k in 2:
		if pl.gun:
			pl.gun.set_viewmodel_visible(false)
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/glass_%d.png" % [out_dir, k])
		await get_tree().create_timer(0.35).timeout
	print("Saved glass shots")
	get_tree().quit()
