extends Node
## Developer check for Fixtures (set dressing that does something), on the Pump House: the
## machines start up and hum (each with its loop), the engine's flywheel turns, the pump wired
## to the valves' button waits for it and then winds up, a crate dropped on the generator
## breaks it (it winds down and falls silent) and it starts again in time, an electric one
## jolts whoever touches it; screenshots of the machines and every built-in look.
## Exits 1 if a step fails.
## Usage: godot -- --host --map pump_house --mode puzzle --bots 0 --port 24700 --tour <dir> --tour-mode fixtures

var world: Node
var out_dir := ""
var _failed := 0
var _camera: Camera3D


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("FIXTURE CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var arena = world.arena
	var pl: Player = world.local_player
	var fixtures: Array = arena.puzzle.filter(func(n): return n is Fixture)
	_check("the Pump House's machines are fixtures", fixtures.size() >= 6, "%d" % fixtures.size())
	var by_name := {}
	for f: Fixture in fixtures:
		by_name[String(f.name)] = f
	var pump: Fixture = by_name.get("ValvePump")
	var gen: Fixture = by_name.get("Generator")
	var engine: Fixture = by_name.get("ExitEngine")
	# Running: the ambient loops come from a worker thread a moment after startup.
	var always: Array = fixtures.filter(func(f): return f.inputs.is_empty())
	var running := false
	for k in 40:
		await _wait(0.2)
		running = always.all(func(f): return f._level > 0.95 and f._audio.stream != null and f._audio.playing)
		if running:
			break
	_check("the always-on ones wind up, each humming its loop", running, ", ".join(always.map(func(f): return "%s %.2f %s" % [f.name, f._level, f._audio.stream != null])))
	var before: Basis = engine._spin.transform.basis
	await _wait(0.3)
	_check("the engine's flywheel turns", not engine._spin.transform.basis.is_equal_approx(before), "")
	_check("... and it shudders", engine._look.position.length() > 0.0005, "%.4f m" % engine._look.position.length())
	# Screenshots of the machines (the pump room before it floods).
	_cam(Vector3(1.5, 2.0, 11.6), Vector3(4.3, 0.6, 10.8))
	await _wait(0.6)
	_shot("f01_pump")
	_cam(Vector3(-1.2, 4.8, 11.0), Vector3(-4.5, 4.2, 13.6))
	await _wait(0.5)
	_shot("f02_pipes")
	_cam(Vector3(-1.0, 1.8, 36.4), Vector3(-4.3, 0.6, 38.0))
	await _wait(0.5)
	_shot("f03_generator")
	_cam(Vector3(-0.6, 2.0, 62.8), Vector3(-4.1, 0.7, 66.0))
	await _wait(0.5)
	_shot("f04_engine")
	_cam(Vector3(1.0, 6.6, 20.5), Vector3(4.85, 7.0, 24.0))
	await _wait(0.5)
	_shot("f05_fan")
	_cam(Vector3(-2.6, 4.0, 15.9), Vector3(-4.4, 3.15, 17.4))
	await _wait(0.5)
	_shot("f06_radio")
	# Wired: the pump waits for the valves' button.
	_check("the valve pump is off until the button's pressed", not pump.active and pump._level < 0.01 and not pump._audio.playing, "level %.2f" % pump._level)
	var button := arena.get_parent().find_child("Button1", true, false) as PuzzleButton
	button.server_used(pl)
	await _wait(2.5)
	_check("... then it winds up", pump.active and pump._level > 0.9 and pump._audio.playing, "level %.2f" % pump._level)
	# A crate dropped on the generator breaks it: it winds down and falls silent, then starts
	# again after its repair time.
	gen.repair_time = 2.5
	var at := gen.glow_position()
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, at + Vector3(0, 3.0, 0)))
	for k in 3:
		await get_tree().physics_frame
	crate.linear_velocity = Vector3(0, -14, 0)
	var broke := false
	for k in 20:
		await _wait(0.05)
		if gen.broken:
			broke = true
			break
	_cam(at + Vector3(3.0, 1.0, -2.5), at)
	await _wait(1.6)
	_check("a crate dropped on the generator breaks it: it winds down, silent", broke and gen._level < 0.01 and not gen._audio.playing, "broken %s, level %.2f" % [broke, gen._level])
	_shot("f07_generator_broken")
	await _wait(1.6)
	_check("... and it starts again in time", not gen.broken and gen._level > 0.2 and gen._audio.playing, "level %.2f" % gen._level)
	if is_instance_valid(crate):
		world.server_despawn_prop(crate)
	# Every built-in look in a row (and an electric one: it jolts whoever touches it).
	var row: Array[Fixture] = []
	var places := {"box": Vector3(-3.8, 0, 50.8), "generator": Vector3(-1.6, 0, 50.8), "engine": Vector3(2.2, 0, 50.8),
		"fan": Vector3(-3.4, 0, 53.4), "pump": Vector3(-1.2, 0, 53.4), "pipes": Vector3(0.8, 0, 53.4), "radio": Vector3(2.6, 0, 53.4)}
	for kind in Fixture.KINDS:
		var f := Fixture.new()
		f.kind = kind
		f.solid = false
		if kind == "box":
			f.hazard = "electric"
			f.effect = "sparks"
			f.sound = "buzz"
		f.world = world
		f.puzzle_index = arena.puzzle.size()
		arena.puzzle.append(f)
		arena.add_child(f)
		f.global_position = places[kind]
		row.append(f)
	_cam(Vector3(0, 3.0, 57.6), Vector3(-0.4, 0.5, 51.6))
	await _wait(2.0)
	_shot("f08_every_kind")
	var hp := pl.hp
	_look(pl, row[0].global_position + Vector3(0.6, 0, 0.4), row[0].global_position)
	var jolted := false
	for k in 30:
		await _wait(0.05)
		if pl.hp < hp or pl.state == Player.State.RAGDOLL or pl.velocity.length() > 3.0:
			jolted = true
			break
	_check("an electric one jolts whoever touches it", jolted, "hp %.0f -> %.0f" % [hp, pl.hp])
	print("FIXTURE CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


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


## Screenshots from a free camera (no gun in the way).
func _cam(eye: Vector3, target: Vector3) -> void:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 70.0
		world.add_child(_camera)
	_camera.look_at_from_position(eye, target)
	_camera.make_current()


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
