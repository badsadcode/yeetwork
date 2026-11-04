extends Node
## Developer check for The Foundry (MegaYeet's second fortress): from every rift the monsters
## have a way to the Heart, and it's the way the map means: the scrapyard through the assembly
## hall, the alley's rift by the pipe alley, the far bank over the bridge and along the yard;
## the canal isn't walked in, the bridge is; every jump pad over a wall lands on walkable
## ground, on the far side; runners from every rift make their way to the gates; a Yeet gets
## out of the control room over its low wall; the Ram's charge runs the length of the hall.
## Screenshots. Exits 1 if a step fails.
## Usage: godot -- --host --map res://maps/foundry.tscn --mode megayeet --bots 0 --port 24650 --tour <dir> --tour-mode foundry

var world: Node
var out_dir := ""
var _failed := 0
var _camera: Camera3D


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func():
		print("FOUNDRY CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var mode := world.mode_logic as ModeMegaYeet
	var horde: Horde = world.horde
	var f: FlowField = horde.field
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	mode.phase_end = world.now() + 999.0
	mode._send_state()
	# Which way each rift goes, and which gates are on it.
	var gates := {}
	for n in world.arena.destructibles:
		gates[n] = _gate_name(n.global_position)
	var routes := {}
	for s: MonsterSpawn in world.arena.monster_spawns:
		var c := f.cell_of(s.global_position)
		var reached: bool = c >= 0 and f.walk[c] == 1 and f.dist[c] < FlowField.INF_COST
		routes[String(s.name)] = _route(f, s.global_position, gates)
		_check("%s has a way to the Heart" % s.name, reached, "%s" % [routes[String(s.name)]])
	_check("the scrapyard's rifts: through a gate on the scrapyard's east side", _has(routes.RiftScrapNorth, ["HallWest", "YardSide"]) and _has(routes.RiftScrapSouth, ["HallWest", "YardSide"]), "%s / %s" % [routes.RiftScrapNorth, routes.RiftScrapSouth])
	_check("the alley's rift: by the alley, into the furnace hall by its alley gate", _has(routes.RiftAlley, ["FurnaceAlley"]), "%s" % [routes.RiftAlley])
	_check("the far bank's rifts: over the bridge, into the furnace hall from the yard", _has(routes.RiftFarBank, ["FurnaceYard"]) and _has(routes.RiftFarBankEast, ["FurnaceYard"]), "%s / %s" % [routes.RiftFarBank, routes.RiftFarBankEast])
	var bridge := f.cell_of(Vector3(3, 0, 44))
	var canal := f.cell_of(Vector3(20, 0, 44))
	_check("the bridge is walked, the canal isn't", f.walk[bridge] == 1 and f.dist[bridge] < FlowField.INF_COST and f.walk[canal] == 0, "bridge %d, canal %d" % [f.walk[bridge], f.walk[canal]])
	# Under the catwalks, the floor's the monsters'.
	var under := f.cell_of(Vector3(-20, 0, -22))
	_check("the hall's floor is walked under the catwalks", f.walk[under] == 1 and absf(f.height[under]) < 0.2, "height %.1f" % f.height[under])
	var bad_pads := []
	for link: Array in world.arena.jump_links:
		var to: Vector3 = link[1]
		if to.y < 1.0: # (floor to floor: over a wall, not up onto a catwalk)
			var cell := f.cell_of(to)
			if cell < 0 or f.walk[cell] != 1 or f.dist[cell] >= FlowField.INF_COST:
				bad_pads.append(link[0])
	_check("the jump pads over the walls land on walkable ground", bad_pads.is_empty(), "bad: %s" % [bad_pads])
	await _shots(mode, pl)
	# Runners from every rift get to where the gates stop them.
	var runners := []
	for s: MonsterSpawn in world.arena.monster_spawns:
		var m = horde.server_spawn(s.global_position, "runner")
		runners.append([m, f.dist[f.cell_of(s.global_position)], String(s.name)])
	await _wait(14.0)
	var stuck := []
	for r: Array in runners:
		var c := f.cell_of(r[0].pos)
		if r[0].hp > 0.0 and (c < 0 or f.dist[c] >= int(r[1]) - 200):
			stuck.append("%s at %s" % [r[2], r[0].pos])
	_check("runners from every rift are well on their way", stuck.is_empty(), "%s" % [stuck])
	await _shot("f07_runners", Vector3(-6, 8.5, -15.5), Vector3(-30, 0, -15.5))
	horde.server_clear()
	await _wait(0.2)
	# Out of the control room: over the low wall (a hop), not through it.
	pl.respawn(Vector3(43, 0.2, 13), PI)
	await _wait(0.4)
	pl.yaw = PI
	pl.cmd.move = Vector2(0, 1)
	pl.cmd.run = true
	pl.cmd.jump = true
	pl.cmd.jump_pressed = true
	for k in 50:
		await _wait(0.1)
		if pl.global_position.z > 15.5:
			break
	pl.cmd.jump = false
	pl.cmd.move = Vector2.ZERO
	_check("a Yeet hops out of the control room, over its low wall", pl.global_position.z > 15.5, "at %s" % pl.global_position)
	# The Ram: the length of the hall.
	pl.respawn(Vector3(-12, 0.2, -15.5), 0.0) # (within its 30 m)
	await _wait(0.3)
	var ram = horde.server_spawn(Vector3(-36, 0, -15.5), "ram")
	ram.speed = 0.0
	ram.yaw = -PI * 0.5
	ram.charge_cd = 0.0
	var ran := false
	for k in 50:
		await _wait(0.1)
		if ram.state == Horde.State.CHARGE:
			ran = true
			break
	await _shot("f08_ram_in_the_hall", Vector3(14, 3, -13), Vector3(-10, 2, -15.5))
	for k in 40:
		await _wait(0.1)
		if ram.state == Horde.State.STUN:
			break
	_check("the Ram sees down the hall and charges along it", ran and ram.pos.x > -20.0, "ran %s, got to %s" % [ran, ram.pos])
	print("FOUNDRY CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## The gates on the way from here to the Heart, as the monsters go.
func _route(f: FlowField, from: Vector3, gates: Dictionary) -> Array:
	var out := []
	var at := from
	var c := f.cell_of(at)
	for k in 600:
		if c < 0 or f.dist[c] == 0 or f.dist[c] >= FlowField.INF_COST:
			break
		if f.gate_wall.has(c):
			var g: String = gates.get(f.gate_wall[c], "?")
			if not out.has(g):
				out.append(g)
		var step: Vector2 = f.toward[c]
		if step == Vector2.ZERO:
			break
		var p := f.center(c) + step
		c = f.cell_of(Vector3(p.x, 0, p.y))
	return out


func _gate_name(p: Vector3) -> String:
	var names := {"HallWest": Vector2(-43, -15.5), "YardSide": Vector2(-43, 12), "FurnaceAlley": Vector2(30, -46), "FurnaceHall": Vector2(30, -15.5), "FurnaceYard": Vector2(63, 3)}
	for n: String in names:
		if (names[n] as Vector2).distance_to(Vector2(p.x, p.z)) < 5.0:
			return n
	return "?"


func _has(route: Array, any: Array) -> bool:
	return any.any(func(g): return route.has(g))


func _shots(_mode: ModeMegaYeet, pl: Player) -> void:
	pl.respawn(Vector3(43, 0.2, 9), 0.0)
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await _shot("f01_overview", Vector3(-20, 75, 75), Vector3(5, 0, -5))
	await _shot("f02_top", Vector3(0, 130, 1), Vector3(0, 0, 0))
	await _shot("f03_hall", Vector3(-41, 2.4, -15.5), Vector3(30, 2.4, -15.5))
	await _shot("f04_catwalk", Vector3(-30, 7.4, -9), Vector3(25, 2, -19))
	await _shot("f05_alley", Vector3(-17, 2.2, -34), Vector3(14, 1.6, -32.5))
	await _shot("f06_bridge", Vector3(3, 3.4, 56), Vector3(3, 1.5, 22))
	await _shot("f09_furnace", Vector3(36, 7.5, -3), Vector3(58, 1.5, -32))
	await _shot("f10_control", Vector3(43, 3.2, 4.5), Vector3(43, 0.5, 30))
	await _shot("f11_scrapyard", Vector3(-78, 6, -42), Vector3(-48, 0, -2))


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String, eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 70.0
		world.add_child(_camera)
	_camera.look_at_from_position(eye, target)
	_camera.make_current()
	await _wait(0.4)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
