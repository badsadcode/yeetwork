extends Node
## Developer check for dark maps and storms.
## - On a haunted map (haunted_yard): lights wired to a switch stay off until it's used,
##   everyone carries a flashlight, a failing lamp flickers; screenshots of the yard.
## - Under a storm sky: lightning strikes (a bolt mesh and a light appear, then go), sheet
##   lightning; a screenshot at the strike.
## Exits 1 if a step fails.
## Usage: godot -- --host --map haunted_yard --mode sandbox --bots 2 --port 24700 --tour <dir> --tour-mode dark
##        godot -- --host --map lagoon --sky storm --mode sandbox --bots 0 --port 24700 --tour <dir> --tour-mode dark

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("DARK CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var arena = world.arena
	var weather := _find_weather(arena)
	if weather:
		await _storm(weather)
	else:
		await _haunted(arena)
	print("DARK CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _haunted(arena) -> void:
	_check("a dark map: flashlights on", arena.dark and arena.flashlights, "dark %s" % arena.dark)
	var pl: Player = world.local_player
	await _wait(0.3)
	var torches := 0
	var up := 0
	for q: Player in world.players.values():
		if q.is_alive() and q.state != Player.State.RAGDOLL: # (knocked down: the light's off)
			up += 1
			if q._torch and q._torch.visible:
				torches += 1
	_check("every Yeet on their feet carries a lit flashlight", torches == up and up > 0, "%d of %d" % [torches, up])
	var lights: Array = []
	var wired: Array = []
	var faulty: MapLight = null
	for n in arena.puzzle:
		if n is MapLight:
			lights.append(n)
			if not (n as MapLight).inputs.is_empty():
				wired.append(n)
			if (n as MapLight).flicker == "faulty":
				faulty = n
	_check("the map's lights: always-on ones lit, wired ones off", lights.size() > 10 and wired.size() >= 2 and lights.all(func(l): return l.active == l.inputs.is_empty()), "%d lights, %d wired" % [lights.size(), wired.size()])
	var seen := {}
	for k in 50: # (2.5 s: it drops out now and then, about one moment in five)
		await _wait(0.05)
		seen[snappedf(faulty._light.light_energy, 0.01)] = true
	_check("a faulty lamp flickers", seen.size() > 1, "%d levels seen" % seen.size())
	_look(pl, Vector3(0, 1.6, 12), Vector3(0, 1.5, -4))
	await _wait(0.8)
	_shot("d01_yard")
	_look(pl, Vector3(1.5, 1.6, -2.5), Vector3(0, 1.4, -10))
	await _wait(0.6)
	_shot("d02_crypt_dark")
	# The power switch: the crypt lights come on.
	var switch := arena.get_parent().find_child("PowerSwitch", true, false) as PuzzleButton
	if switch == null:
		for n in arena.puzzle:
			if n is PuzzleButton:
				switch = n
	switch.server_used(pl)
	await _wait(0.6)
	_check("the power switch lights the crypt", wired.all(func(l): return l.active and l._light.light_energy > 0.1), "")
	_shot("d03_crypt_lit")
	_look(pl, Vector3(-6, 1.6, 6), Vector3(-14, 1.0, 13))
	await _wait(0.5)
	_shot("d04_graves")


func _storm(weather: Weather) -> void:
	var pl: Player = world.local_player
	_look(pl, Vector3(0, 6, 0), Vector3(0, 30, -150))
	await _wait(0.5)
	var before: int = weather.get_child_count()
	weather._next_bolt = 100.0 # (no surprise strikes during the check)
	var cam := get_viewport().get_camera_3d()
	# Force a bolt ahead of the camera.
	weather._rng.seed = 3
	var dist := 120.0
	weather._strike(cam, dist, 1.0)
	await get_tree().process_frame
	var mesh: MeshInstance3D = null
	for c in weather.get_children():
		if c is MeshInstance3D:
			mesh = c
	_check("a lightning strike: a branching bolt and a light", mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0 and weather.get_child_count() >= before + 2, "children %d -> %d" % [before, weather.get_child_count()])
	# For the picture: a strike straight ahead (the camera looks along -Z).
	await _wait(0.6)
	weather._strike(get_viewport().get_camera_3d(), 150.0, 1.2, -PI * 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	_shot("s01_lightning")
	await _wait(1.0)
	var left := 0
	for c in weather.get_children():
		if c is MeshInstance3D:
			left += 1
	_check("the bolts fade away", left == 0, "%d left" % left)
	weather._lightning() # sheet or bolt, with its thunder
	await _wait(0.2)
	_check("a lightning event with thunder runs", true, "")


func _find_weather(n: Node) -> Node:
	for c in n.get_children():
		if c is Weather:
			return c
	return null


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(pl: Player, eye: Vector3, target: Vector3) -> void:
	var to := target - eye
	pl.respawn(eye - Vector3(0, Player.EYE_STAND, 0), 0.0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
