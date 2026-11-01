extends Node
## The pictures for docs/MAKE_A_NEW_MAP.md (docs/images/new_map/), on Lighthouse Point
## (custom/lighthouse_point/lighthouse_point.tscn), and for docs/REBUILD_A_MAP.md
## (docs/images/rebuild_courtyard/), taken from
## Courtyard: the finished map (from the south-west, from above, props on Red's deck, in the
## game), or a part of it: a copy of maps/courtyard.tscn with the later groups taken out (a
## file named ..._geometry.tscn: Breakables, Gameplay, Props and the pickups out;
## ..._breakables.tscn: Gameplay, Props and the pickups out).
## Usage: godot --path . -- --host --map res://maps/courtyard.tscn --mode sandbox --bots 0 --tour <folder> --tour-mode guideshots

var world: Node
var out_dir := ""
var _camera: Camera3D


func _ready() -> void:
	await _wait(1.0)
	var pl: Player = world.local_player
	pl.respawn(Vector3(28, 3, -5), 0.0)
	await _wait(1.5)
	world.hud.visible = false
	pl.visible = false # (it stands on Blue's deck, unseen)
	var map := ""
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".tscn"):
			map = a
	if map.ends_with("lighthouse_point.tscn"):
		await _lighthouse(pl)
	elif map.ends_with("_geometry.tscn"):
		await _shot("03_geometry", Vector3(-40, 20, 32), Vector3(0, 0, 0))
	elif map.ends_with("_breakables.tscn"):
		await _shot("04_breakables", Vector3(-15, 7, 19), Vector3(0, 1.5, 0))
	else:
		await _shot("01_finished", Vector3(-40, 20, 32), Vector3(0, 0, 0))
		await _top("02_from_above")
		await _shot("05_props", Vector3(-12, 10, 13), Vector3(-25, 2.5, 0))
		pl.visible = true
		world.hud.visible = true
		pl.respawn(Vector3(-24, 3, 2), -PI / 2.0)
		await _wait(1.0)
		pl.yaw = -PI / 2.0 - 0.15
		pl.pitch = -0.12
		pl.camera.make_current()
		await _wait(0.6)
		await _save("06_ingame")
	print("GUIDE SHOTS OK")
	get_tree().quit(0)


func _lighthouse(pl: Player) -> void:
	pl.respawn(Vector3(26, 0, 3), 0.0)
	await _wait(1.0)
	pl.visible = false
	await _shot("01_lighthouse_point", Vector3(-8, 22, 46), Vector3(0, 2, -2))
	await _top("02_from_above")
	await _shot("03_lighthouse", Vector3(-8, 9, 14), Vector3(-25, 6, 0))
	await _shot("04_boathouse", Vector3(8, 4, 8), Vector3(20, 1.5, 0))
	await _shot("05_middle", Vector3(-14, 6, 18), Vector3(2, 2, -6))
	await _shot("06_gallery", Vector3(-26, 17.5, 4.5), Vector3(5, 4, -2))
	pl.visible = true
	world.hud.visible = true
	pl.respawn(Vector3(13, 0, 3), 0.0)
	await _wait(1.0)
	var to := Vector3(-27, 9, 0) - pl.eye_position()
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	pl.camera.make_current()
	await _wait(0.6)
	await _save("07_ingame")


func _shot(n: String, eye: Vector3, at: Vector3) -> void:
	_cam().projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.look_at_from_position(eye, at)
	await _wait(0.8)
	await _save(n)


## Straight down, north up: the whole map.
func _top(n: String) -> void:
	_cam().projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 54.0
	_camera.look_at_from_position(Vector3(0, 80, 0), Vector3.ZERO, Vector3(0, 0, -1))
	await _wait(0.8)
	await _save(n)


func _cam() -> Camera3D:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 60.0
		_camera.far = 400.0
		world.add_child(_camera)
	_camera.make_current()
	return _camera


func _save(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.resize(1280, int(1280.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg("%s/%s.jpg" % [out_dir, n], 0.85)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
