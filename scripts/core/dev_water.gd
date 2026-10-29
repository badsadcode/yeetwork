extends Node
## Developer tool: screenshots of liquids (sea, waterline split, underwater, Snell's window,
## splash, floating props, acid, and test basins of pool water and lava), then GPU timings.
## Usage: godot -- --host --map courtyard --bots 0 --tour <dir> --tour-mode water
##        godot -- --host --map prime --bots 0 --tour <dir> --tour-mode water
## Extra options (after --):
##   --shots "name:ex,ey,ez:tx,ty,tz;..."  only these views (eye and look-at points)
##   --perf                                print GPU time per view instead of saving shots
##   --graphics 0|1|2                      quality preset (handled by main.gd)

# name, eye, look-at
const SHOTS_OCEAN := [
	["sea_sun", Vector3(40, 0.2, 30), Vector3(140, -3.5, 110)],
	["sea_away", Vector3(-40, 0.5, -28), Vector3(-140, -4.0, -100)],
	["island", Vector3(-78, 3, 46), Vector3(-25, -1, 0)],
	["from_wall", Vector3(-33, 13, 20), Vector3(-75, -3, 45)],
	["horizon", Vector3(10, 40, 30), Vector3(60, -3, 220)],
	["waterline", Vector3(-44, -3.0, 12), Vector3(-20, -3.0, 2)],
	["underwater", Vector3(-43, -7.5, 9), Vector3(-30, -5.5, 0)],
	["underwater_up", Vector3(-46, -7, 12), Vector3(-45, 0, 8)],
	["underwater_sun", Vector3(-46, -6, 12), Vector3(-20, -1, 34)],
]
const SHOTS_PRIME := [
	["acid", Vector3(0, 4, 20), Vector3(0, -6.4, 0)],
	["acid_close", Vector3(5, -3.5, 9), Vector3(0, -6.4, 2)],
	["acid_under", Vector3(6, -7.3, 6), Vector3(0, -7, -2)],
]
# Test basins built far outside the map: clear pool water and lava.
const POOL := Vector3(300, 0, 0)
const LAVA := Vector3(300, 0, 60)
const SHOTS_BASINS := [
	["pool", POOL + Vector3(-9, 4.5, 11), POOL + Vector3(0, -1, 0)],
	["pool_waterline", POOL + Vector3(-3, -0.05, 4), POOL + Vector3(6, -0.6, -2)],
	["pool_under", POOL + Vector3(-5, -2.2, 5), POOL + Vector3(4, -2.4, -3)],
	["lava", LAVA + Vector3(-9, 4.5, 11), LAVA + Vector3(0, -1, 0)],
	["lava_close", LAVA + Vector3(-4, 1.2, 5), LAVA + Vector3(2, -0.6, -1)],
]

var world: Node
var out_dir := ""
var pl: Player
var _perf := false
var _surf: Liquid


func _ready() -> void:
	process_priority = 100 # after the player: hide the viewmodel it re-shows every frame
	await get_tree().create_timer(1.0).timeout
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.set_physics_process(false) # park the camera exactly where we put it
	world.hud.visible = false
	var ocean := false
	for l: Liquid in Liquid.all:
		ocean = ocean or l.ocean
	if not ocean:
		_build_basins()
	var args := OS.get_cmdline_user_args()
	_perf = "--perf" in args
	var custom := _custom_shots(args)
	if not custom.is_empty():
		for s in custom:
			await _view(s[0], s[1], s[2])
		get_tree().quit()
		return
	if _perf:
		await _perf_run(ocean)
		get_tree().quit()
		return
	for s in SHOTS_OCEAN if ocean else SHOTS_PRIME + SHOTS_BASINS:
		await _view(s[0], s[1], s[2])
	if ocean:
		await _props_shots()
	get_tree().quit()


func _process(_delta: float) -> void:
	if pl == null:
		return
	pl.model.visible = false
	if pl.gun:
		pl.gun.set_viewmodel_visible(false)
		pl.gun._world_model.visible = false
	if _surf:
		# Keep the eyes exactly at the moving surface, so the view stays split.
		var e := pl.eye_position()
		pl.global_position.y += _surf.height_at(e.x, e.z) - e.y


func _custom_shots(args: PackedStringArray) -> Array:
	var i := args.find("--shots")
	if i < 0 or i + 1 >= args.size():
		return []
	var out := []
	for part in args[i + 1].split(";", false):
		var f := part.split(":")
		var e := f[1].split_floats(",")
		var t := f[2].split_floats(",")
		out.append([f[0], Vector3(e[0], e[1], e[2]), Vector3(t[0], t[1], t[2])])
	return out


## Concrete tubs with a liquid inside, so pool water and lava can be judged on any map.
func _build_basins() -> void:
	var arena: Arena = world.arena
	for b in [[POOL, "water", Color(0.85, 0.82, 0.72)], [LAVA, "lava", Color(0.25, 0.22, 0.24)]]:
		var c: Vector3 = b[0]
		arena.box(c + Vector3(0, -3.5, 0), Vector3(16, 1, 12), b[2])
		arena.box(c + Vector3(-8.5, -1.5, 0), Vector3(1, 5, 12), b[2])
		arena.box(c + Vector3(8.5, -1.5, 0), Vector3(1, 5, 12), b[2])
		arena.box(c + Vector3(0, -1.5, -6.5), Vector3(18, 5, 1), b[2])
		arena.box(c + Vector3(0, -1.5, 6.5), Vector3(18, 5, 1), b[2])
		# A ramp and a step, so the depth gradient and the shore foam show.
		arena.box(c + Vector3(-5, -2.2, -2), Vector3(4, 2, 4), b[2].darkened(0.2))
		arena.box(c + Vector3(4, -2.6, 2), Vector3(5, 1, 3), Color(0.9, 0.5, 0.3))
		arena.add_child(Liquid.create(b[1], c + Vector3(0, -0.4, 0), Vector3(16, 3.2, 12)))
		var lamp := c + Vector3(0, 6, 0)
		arena.light(lamp, Color(1.0, 0.9, 0.7), 12.0, 0.5)
	if world.is_server:
		for i in 3:
			world.server_spawn_prop(["crate", "beachball", "barrel"][i], Transform3D(Basis.IDENTITY, POOL + Vector3(-3 + i * 3, 1.0, -2)))


func _props_shots() -> void:
	var drop := Vector3(-40, 6, 10)
	_place(Vector3(-50, 0.5, 19), Vector3(-40, -3, 10))
	world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, drop), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, -6, 0))
	world.server_spawn_prop("barrel", Transform3D(Basis.IDENTITY, drop + Vector3(3, 2, -2)), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, -6, 0))
	world.server_spawn_prop("anvil", Transform3D(Basis.IDENTITY, drop + Vector3(-3, 2, 2)), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, -6, 0))
	await get_tree().create_timer(0.62).timeout
	_shot("splash")
	await get_tree().create_timer(2.8).timeout
	# Diving deep in the ocean drowns you; put the camera back after the respawn.
	_place(Vector3(-50, 0.5, 19), Vector3(-40, -3, 10))
	await get_tree().create_timer(0.2).timeout
	_shot("floating")


func _view(shot_name: String, eye: Vector3, target: Vector3) -> void:
	_place(eye, target)
	_surf = Liquid.at(eye, 3.0) if shot_name.contains("waterline") else null
	await get_tree().create_timer(0.7).timeout
	_shot(shot_name)
	_surf = null


func _place(eye: Vector3, target: Vector3) -> void:
	var to := target - eye
	pl.global_position = eye - Vector3(0, Player.EYE_STAND, 0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(shot_name: String) -> void:
	if _perf:
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("Saved ", shot_name)


## Average GPU frame time looking at the water and away from it (vsync off).
func _perf_run(ocean: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var views: Array = SHOTS_OCEAN if ocean else SHOTS_PRIME
	if not ocean:
		views = views + [["basin_pool", SHOTS_BASINS[0][1], SHOTS_BASINS[0][2]]]
	views = views + [["sky", Vector3(0, 30, 0), Vector3(0, 60, 1)]]
	print("PERF graphics=%d size=%s" % [Game.graphics, get_viewport().get_visible_rect().size])
	for s in views:
		_place(s[1], s[2])
		await get_tree().create_timer(0.8).timeout
		var gpu := 0.0
		var cpu := 0.0
		var frames := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 2000000:
			await get_tree().process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			frames += 1
		print("PERF %-16s gpu %.2f ms  cpu %.2f ms  fps %.0f" % [s[0], gpu / frames, cpu / frames, frames / ((Time.get_ticks_usec() - t0) / 1000000.0)])
