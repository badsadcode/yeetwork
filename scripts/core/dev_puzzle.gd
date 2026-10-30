extends Node
## Developer check for the Puzzle mode: plays through a puzzle level by itself and checks
## every step, saving screenshots. Exits 1 if a step fails.
##   moving_day:    a crate on the first plate, a player and the anvil on the two heavy
##                  plates, a checkpoint and a respawn there, the exit.
##   test_chambers: 100 kg on a plate, key props coming back, the reset button, a target hit
##                  and a smashed wall, three targets within the time window, a button, the exit.
##   warehouse:     the open level's objective list, the Lost Yeet's cage, glass and ice smashed
##                  for fuses, fuses pulled with the gun and locked in the fuse box, the Lost
##                  Yeet carried (scared) to the rescue mat (grinning), the exit.
##   pump_house:    flood water: valves fill a room (volume kept), crates float, Yeets swim,
##                  the network encoding, an anvil sunk on the plug drains a bathtub, the door
##                  under the water opens once it's drained; fire carried from beacon to
##                  beacon, a wooden wall burnt down, a fuse, an ice wall melted into water.
## Usage: godot -- --host --map moving_day --mode puzzle --tour <dir> --tour-mode puzzle
## (add --headless to only check)

var world: Node
var out_dir := ""
var pl: Player
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(func():
		print("PUZZLE CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	pl = world.local_player
	var map_name: String = world.arena.map_settings.map_name if world.arena.map_settings else ""
	if map_name in ["Test Chambers", "The Warehouse", "The Pump House"]:
		if map_name == "Test Chambers":
			await _chambers()
		elif map_name == "The Warehouse":
			await _warehouse()
		else:
			await _pump_house()
		print("PUZZLE CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
		get_tree().quit(0 if _failed == 0 else 1)
		return
	var hud_ok: bool = world.mode == Game.Mode.PUZZLE and world.puzzle_start >= 0.0
	_check("puzzle mode running, no bots", hud_ok and world.players.size() == 1, "mode %d, players %d" % [world.mode, world.players.size()])
	_check("first objective shown", world.puzzle_objective() == "Put a crate on the plate to open the gate", world.puzzle_objective())
	_look(Vector3(0, 4.5, 1.5), Vector3(2, 0.5, 12))
	await _wait(0.4)
	_shot("01_room1")
	# Room 1: a crate on the plate.
	var plate1: PuzzleNode = _piece("Plate1")
	var crate := _nearest("crate", plate1.global_position)
	crate.global_position = plate1.global_position + Vector3(0, 0.8, 0)
	crate.linear_velocity = Vector3.ZERO
	await _wait(1.6)
	_check("crate on plate opens the gate", plate1.active and _piece("Gate1").active, "plate %s (%.0f kg), gate %s" % [plate1.active, (plate1 as PressurePlate).weight, _piece("Gate1").active])
	_shot("02_gate_open")
	# Room 2: through checkpoint 1; one heavy plate is not enough...
	_place_player(_piece("Checkpoint1").global_position + Vector3(0, 0.3, 0))
	await _wait(0.5)
	_place_player(_piece("Plate2").global_position + Vector3(0, 0.3, 0))
	await _wait(0.8)
	_check("one heavy plate alone keeps the gate shut", _piece("Plate2").active and not _piece("Gate2").active, "plate2 %s gate2 %s" % [_piece("Plate2").active, _piece("Gate2").active])
	# ...the anvil on the other one opens it.
	var plate3: PuzzleNode = _piece("Plate3")
	var anvil := _nearest("anvil", plate3.global_position)
	anvil.global_position = plate3.global_position + Vector3(0, 0.6, 0)
	anvil.linear_velocity = Vector3.ZERO
	await _wait(1.2)
	_check("both plates open the second gate", _piece("Gate2").active, "plate3 %s (%.0f kg)" % [plate3.active, (plate3 as PressurePlate).weight])
	_check("checkpoint 1 reached on the way", _piece("Checkpoint1").active, "")
	_look(Vector3(0, 5, 18), Vector3(0, 1, 30))
	await _wait(0.6)
	_shot("03_room2")
	# Room 3: the checkpoint, then a respawn there.
	_place_player(_piece("Checkpoint2").global_position + Vector3(0, 0.3, 0))
	await _wait(0.6)
	_check("checkpoint 2 reached", _piece("Checkpoint2").active, "")
	world.server_damage_player(pl, 1000.0, 0, "void", pl.body_center(), Vector3.UP)
	await _wait(World.RESPAWN_TIME + 0.8)
	var d := pl.global_position.distance_to(_piece("Checkpoint2").global_position)
	_check("respawn at the last checkpoint", pl.is_alive() and d < 4.0, "%.1f m from it" % d)
	_look(Vector3(0, 4, 31), Vector3(0, 0, 44))
	await _wait(0.4)
	_shot("04_moat")
	# The exit.
	_check("objective before the exit", world.puzzle_objective() == "Get everyone to the exit", world.puzzle_objective())
	# Into the exit by air (an Unscheduled Flight).
	_place_player(_piece("Exit").global_position + Vector3(0, 0.2, -4.5))
	await _wait(0.3)
	world.server_launch_player(pl, Vector3(0, 9.0, 7.0), true, 0.0, 0)
	await _wait(1.6)
	_check("everyone at the exit finishes the level", world.puzzle_finish >= 0.0 and world.puzzle_objective() == "Level complete!", "finish %.1f, objective %s" % [world.puzzle_finish, world.puzzle_objective()])
	var res: Dictionary = world.puzzle_results
	var award_names: Array = res.get("awards", []).map(func(a): return a[0])
	_check("results: a gold medal, Big Brain Yeet and Unscheduled Flight", res.get("medal", "") == "gold" and award_names.has("Big Brain Yeet") and award_names.has("Unscheduled Flight"), "medal %s, awards %s" % [res.get("medal", ""), award_names])
	_look(Vector3(0, 3, 43), Vector3(0, 1.5, 50))
	await _wait(0.5)
	_shot("05_exit")
	print("PUZZLE CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _chambers() -> void:
	_look(Vector3(0, 4, 1), Vector3(0, 0.5, 12))
	await _wait(0.4)
	_shot("c01_heavy")
	# A: 100 kg. The couch alone (60) is not enough; the couch and a barrel (100) are.
	var plate: PressurePlate = _piece("PlateA")
	var couch := _nearest("couch", plate.global_position)
	couch.global_position = plate.global_position + Vector3(-0.6, 0.7, 0)
	couch.linear_velocity = Vector3.ZERO
	await _wait(1.2)
	_check("60 kg is not enough", not _piece("GateA").active, "%.0f kg" % plate.weight)
	var barrel := _nearest("barrel", plate.global_position)
	barrel.global_position = plate.global_position + Vector3(0.9, 0.8, 0.6)
	barrel.linear_velocity = Vector3.ZERO
	await _wait(1.2)
	_check("100 kg opens the gate", _piece("GateA").active, "%.0f kg" % plate.weight)
	_shot("c02_heavy_open")
	# Key props come back: a crate smashed is back home 2.5 s later.
	var crate := _nearest("crate", Vector3(-5, 0.6, 5))
	var home := crate.home_transform.origin
	world.server_break_prop(crate, Vector3.UP)
	await _wait(3.2)
	var back := _nearest("crate", home)
	_check("a smashed key prop comes back", back != null and back.global_position.distance_to(home) < 1.5, "%.1f m from home" % (back.global_position.distance_to(home) if back else -1.0))
	# The reset button: throw the room's barrel into room C, press reset, it's home again.
	var stray := _nearest("barrel", Vector3(5, 0.7, 4))
	var stray_home := stray.home_transform.origin
	stray.global_position = Vector3(0, 1.0, 44)
	await _wait(0.5)
	var reset: PuzzleNode = _piece("ResetA")
	_place_player(reset.global_position + Vector3(1.4, 0.0, 0.0))
	await _wait(0.5)
	_check("walking into the reset button does nothing", not reset.active, "")
	_aim_at(reset.use_point())
	await _wait(0.2)
	_shot("c02b_use_prompt")
	var prompt: PuzzleNode = world.usable_for(pl)
	world.use_pressed(pl)
	await _wait(0.6)
	_check("pressing Use on the reset button puts the room's props back", prompt == reset and stray.global_position.distance_to(stray_home) < 1.5, "looking at it: %s, barrel %.1f m from home" % [prompt == reset, stray.global_position.distance_to(stray_home)])
	# B: a ball thrown at the target across the acid.
	_place_player(_piece("CheckpointB").global_position + Vector3(0, 0.2, 0))
	await _wait(0.5)
	_look(Vector3(-1.5, 2.6, 20), Vector3(-3.5, 2.5, 31))
	await _wait(0.3)
	_shot("c03_shot")
	var target: PuzzleTarget = _piece("TargetB")
	# The intended way: a bank shot off the bouncy panel, thrown at tap-throw speed from
	# where players stand. (Any of a few aim heights is enough: it must be possible.)
	var banked := -1.0
	var panel := world.arena.map_settings.get_parent().get_node("Geometry/BouncePanel") as Node3D
	for aim_y in [2.0, 2.5, 3.0, 3.5, 4.0, 4.5]:
		var from := Vector3(-1.5, 1.8, 21.0)
		var to := Vector3(panel.global_position.x, aim_y, panel.global_position.z)
		var t := from.distance_to(to) / 30.0
		var v := (to - from - 0.5 * Vector3(0, -24.0, 0) * t * t) / t
		var b: Prop = world.server_spawn_prop("ball", Transform3D(Basis.IDENTITY, from), Vector3.ZERO, Color(0, 0, 0, 0), 0, v)
		await _wait(1.0)
		if is_instance_valid(b):
			world.server_despawn_prop(b)
		if target.active:
			banked = aim_y
			break
	_check("the bank shot off the panel works", banked > 0.0, "aimed at height %.1f" % banked)
	if not target.active:
		await _throw_at(target)
	_check("a ball on the target opens the gate", target.active and _piece("GateB").active, "target %s" % target.active)
	# The other way: smash the wall the target hangs on.
	var sensor: BreakSensor = _piece("WallSensorB")
	for k in 6:
		world.server_damage_destructible(sensor._d, target.global_position + Vector3(randf_range(-2, 2), randf_range(-1.5, 1.5), 0.2), 1.2, 400.0, Vector3(0, 0, 8), 0)
	await _wait(0.5)
	_check("smashing the target's wall counts too", sensor.active, "%d of %d pieces broken" % [sensor._d.broken_cells.size(), sensor._d.cells.size()])
	# C: three targets inside the time window.
	_place_player(_piece("CheckpointC").global_position + Vector3(0, 0.2, 0))
	await _wait(0.5)
	_look(Vector3(0, 3, 38), Vector3(0, 2.5, 50))
	await _wait(0.3)
	_shot("c04_three")
	await _throw_at(_piece("TargetC1"))
	await _throw_at(_piece("TargetC2"))
	await _wait(3.4)
	await _throw_at(_piece("TargetC3"))
	await _wait(0.3)
	_check("too slow: the window closed", not _piece("GateC").active, "")
	_throw_at(_piece("TargetC1"))
	_throw_at(_piece("TargetC2"))
	await _throw_at(_piece("TargetC3"))
	await _wait(0.5)
	_check("all three within 3 s open the gate", _piece("GateC").active, "")
	# The button drops the ledge with the spare balls.
	_place_player(_piece("ButtonC").global_position + Vector3(0, 0.2, 0))
	await _wait(1.6)
	var ball := _nearest("ball", Vector3(6.0, 4.3, 46.2))
	_check("the button drops the ball ledge", _piece("BallLedge").active and ball.global_position.y < 2.0, "ball at y %.1f" % ball.global_position.y)
	# D: the Yeetapult. Stand on the yellow end, the anvil drops on the red end: up you go.
	var saw: Seesaw = _piece("SeesawD")
	_place_player(saw.global_transform * Vector3(-3.0, 0.5, 0))
	await _wait(1.2)
	_check("standing on the yellow end tips it down", saw.angle < -0.2, "angle %.0f deg" % rad_to_deg(saw.angle))
	_look(Vector3(5, 4.5, 55), Vector3(-2, 2, 63))
	await _wait(0.2)
	_shot("c05_seesaw")
	_place_player(saw.global_transform * Vector3(-3.0, 0.5, 0))
	await _wait(0.3)
	var anvil := _nearest("anvil", saw.global_position)
	anvil.global_position = saw.global_transform * Vector3(3.0, 3.2, 0)
	anvil.linear_velocity = Vector3.ZERO
	var peak := -INF
	for k in 30:
		await _wait(0.05)
		peak = maxf(peak, pl.global_position.y)
	await _wait(1.0)
	var on_ledge := pl.global_position.y > 4.5 and pl.global_position.x < -5.3
	_check("the anvil yeets the player up to the ledge", peak > 5.5 and on_ledge, "peak %.1f m, now at %s" % [peak, pl.global_position.snapped(Vector3.ONE * 0.1)])
	if not on_ledge:
		_place_player(_piece("ButtonD").global_position + Vector3(1.3, 0.2, 0))
		await _wait(0.3)
	_aim_at(_piece("ButtonD").use_point())
	await _wait(0.2)
	world.use_pressed(pl)
	await _wait(0.6)
	_check("the ledge button opens the gate", _piece("GateD").active, "")
	# E: the fan on the turntable.
	_place_player(_piece("CheckpointE").global_position + Vector3(0, 0.2, 0))
	var fan_piece: PuzzleFan = _piece("FanE")
	var fan := fan_piece.fan_prop()
	var start_dir := -fan.global_transform.basis.z
	_check("the fan runs and blows the wrong way at first", fan_piece.active and start_dir.dot(Vector3(0, 0, 1)) < 0.3, "blowing %s" % start_dir.snapped(Vector3.ONE * 0.01))
	_place_player(_piece("ButtonE").global_position + Vector3(1.3, 0.2, 0))
	await _wait(0.3)
	_aim_at(_piece("ButtonE").use_point())
	await _wait(0.1)
	world.use_pressed(pl)
	await _wait(1.5)
	var turned := -fan.global_transform.basis.z
	_check("the button spins the turntable, turning the fan", _piece("TableE").active and turned.angle_to(start_dir) > 0.5, "turned %.0f deg" % rad_to_deg(turned.angle_to(start_dir)))
	world.use_pressed(pl) # stop it
	await _wait(0.4)
	# Aim it across the pit, as a player would with the gravity gun, and ride the wind.
	fan.global_transform = Transform3D(Basis(Vector3.UP, PI), fan.global_position)
	fan.linear_velocity = Vector3.ZERO
	await _wait(0.5)
	_look(Vector3(-3, 3.5, 76), Vector3(0, 0.5, 96))
	await _wait(0.3)
	_shot("c06_windy")
	# A running jump from the pit's edge, into the wind (driven like a player: run, jump).
	_place_player(Vector3(0, 0.1, 81.0))
	_aim_at(Vector3(0, 1.6, 100))
	pl.is_bot = true # (the test drives its inputs)
	pl.bot_brain = null
	pl.cmd.run = true
	pl.cmd.move = Vector2(0, 1)
	var furthest := 0.0
	for k in 60:
		await _wait(0.05)
		pl.cmd.jump = pl.global_position.z > 84.6 and pl.global_position.z < 86.0
		furthest = maxf(furthest, pl.global_position.z)
	pl.cmd.move = Vector2.ZERO
	pl.cmd.jump = false
	_check("the wind carries a Yeet across the pit", furthest > 95.0 and pl.global_position.y > -1.0, "got to z %.1f, now at y %.1f" % [furthest, pl.global_position.y])
	# F: Thin Ice.
	_look(Vector3(2.5, 2.2, 103.5), Vector3(-3, 0.5, 112))
	await _wait(0.4)
	_shot("c07_ice")
	_look(Vector3(-3.5, 1.4, 106.2), Vector3(-5.5, 0.8, 108))
	await _wait(0.3)
	_shot("c07b_ice_close")
	_look(Vector3(4.3, 1.3, 112.6), Vector3(5.8, 0.6, 114.5))
	await _wait(0.3)
	_shot("c07c_ice_maps")
	_place_player(Vector3(-2, 0.2, 106))
	await _wait(0.4)
	_check("standing on the pond is standing on ice", pl.on_ice, "")
	var slider := _nearest("crate", Vector3(3, 0.6, 103.5))
	slider.global_position = Vector3(4, 0.6, 105.5)
	slider.linear_velocity = Vector3(0, 0, 8)
	var from_z := slider.global_position.z
	await _wait(2.0)
	_check("a crate glides across the ice", slider.global_position.z - from_z > 7.0, "slid %.1f m" % (slider.global_position.z - from_z))
	_check("the exit stays shut until the plate is pressed", not _piece("Exit").active and not _piece("PlateF").active, "")
	slider.global_position = _piece("PlateF").global_position + Vector3(0, 0.7, 0)
	slider.linear_velocity = Vector3.ZERO
	await _wait(0.8)
	_check("a crate on the far plate", _piece("PlateF").active, "")
	var anvil_f := _nearest("anvil", Vector3(6, 0.3, 103.5))
	anvil_f.global_position = Vector3(0, 3.5, 111)
	anvil_f.linear_velocity = Vector3.ZERO
	await _wait(2.0)
	var thin: Destructible = null
	for d in world.arena.destructibles:
		if d.material == "ice":
			thin = d
	_check("the anvil goes through the thin ice", thin != null and thin.broken_cells.size() > 0 and anvil_f.global_position.y < -0.5, "broken %d, anvil at y %.1f" % [thin.broken_cells.size() if thin else -1, anvil_f.global_position.y])
	_place_player(_piece("Exit").global_position + Vector3(0, 0.3, 0))
	await _wait(0.8)
	_check("the exit finishes the level", world.puzzle_finish >= 0.0, "")
	var res: Dictionary = world.puzzle_results
	var award_names: Array = res.get("awards", []).map(func(a): return a[0])
	_check("results: time, medal, stats and awards arrive", res.get("medal", "") == "gold" and res.get("stats", []).size() >= 4 and award_names.has("Structural Disagreement"), "medal %s, awards %s" % [res.get("medal", ""), award_names])
	_look(Vector3(0, 3, 116), Vector3(0, 1.5, 123))
	await _wait(0.5)
	_shot("c08_exit")


func _warehouse() -> void:
	var obj: String = world.puzzle_objective()
	_check("the open level lists every objective", obj.count("\n") == 3 and obj.begins_with("Fuses for the main gate: 0/3"), obj.replace("\n", " | "))
	_look(Vector3(0, 5, 1), Vector3(0, 1, 20))
	await _wait(0.4)
	_shot("w01_hub")
	# Storage: 100 kg on the plate opens the Lost Yeet's cage.
	var plate: PressurePlate = _piece("PlateW")
	var couch := _nearest("couch", plate.global_position)
	couch.global_position = plate.global_position + Vector3(-0.6, 0.7, 0)
	couch.linear_velocity = Vector3.ZERO
	var barrel := _nearest("barrel", plate.global_position)
	barrel.global_position = plate.global_position + Vector3(0.9, 0.8, 0.6)
	barrel.linear_velocity = Vector3.ZERO
	await _wait(1.2)
	_check("100 kg opens the cage", _piece("CageDoor").active, "%.0f kg" % plate.weight)
	# The fuse on the top shelf: smash the glass with a ball, pull the fuse down with the gun.
	var glass: Destructible = null
	var ice: Destructible = null
	for d in world.arena.destructibles:
		if d.material == "glass":
			glass = d
		elif d.material == "ice":
			ice = d
	_look(Vector3(-27, 2.5, 14), Vector3(-30, 3.8, 23.4))
	await _wait(0.4)
	_shot("w02_shelf")
	var thrown: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(-30, 4.5, 19.0)), Vector3.ZERO, Color(0, 0, 0, 0), 0, Vector3(0, 1.5, 16.0))
	await _wait(0.8)
	_check("a thrown crate smashes the shelf's glass", glass != null and glass.broken_cells.size() > 0, "broken %d" % (glass.broken_cells.size() if glass else -1))
	if is_instance_valid(thrown):
		world.server_despawn_prop(thrown)
	var fuse1 := _nearest("fuse", Vector3(-30, 3.85, 23.4))
	_place_player(Vector3(-30, 0, 13))
	await _wait(0.3)
	_aim_at(fuse1.global_position)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), fuse1.global_position - pl.eye_position())
	await _wait(1.6)
	_check("the gun pulls the fuse down", pl.gun.held_kind == GravityGun.Kind.PROP and pl.gun.held_id == fuse1.prop_id, "holding %d (%d)" % [pl.gun.held_id, pl.gun.held_kind])
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	# Into the fuse box: it locks in its slot, and the objective counts it.
	var box: Receptacle = _piece("FuseBox")
	fuse1.global_position = box.global_position + Vector3(0, 0.8, 0)
	fuse1.linear_velocity = Vector3.ZERO
	await _wait(0.6)
	_check("the fuse box takes the fuse and locks it in", box.delivered.size() == 1 and fuse1.freeze and fuse1.has_meta("delivered"), "%d in, frozen %s" % [box.delivered.size(), fuse1.freeze])
	_check("the objective counts it", world.puzzle_objective().begins_with("Fuses for the main gate: 1/3"), world.puzzle_objective().get_slice("\n", 0))
	_place_player(box.global_position + Vector3(0, 0, -3))
	await _wait(0.3)
	_aim_at(fuse1.global_position)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), fuse1.global_position - pl.eye_position())
	await _wait(0.4)
	_check("a delivered fuse can't be grabbed again", pl.gun.held_kind == GravityGun.Kind.NONE and fuse1.freeze, "holding %d" % pl.gun.held_id)
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	_look(box.global_position + Vector3(-2.5, 1.8, -3.5), box.global_position + Vector3(0, 0.6, 0))
	await _wait(0.4)
	_shot("w03_fuse_box")
	# Cold Storage: an anvil slid across the ice into the ice wall.
	var anvil := _nearest("anvil", Vector3(-4, 0.3, -8))
	anvil.global_position = Vector3(0, 0.6, -19)
	anvil.linear_velocity = Vector3(0, 0, -14)
	await _wait(1.5)
	_check("an anvil smashes the ice wall", ice != null and ice.broken_cells.size() > 0, "broken %d" % (ice.broken_cells.size() if ice else -1))
	_look(Vector3(3, 2.5, -16), Vector3(0, 1, -25))
	await _wait(0.4)
	_shot("w04_ice_wall")
	# The other two fuses (any solution counts: here, they just get there).
	for from in [Vector3(17.25, 5.35, 15), Vector3(0, 0.35, -25.8)]:
		var f := _nearest("fuse", from)
		f.global_position = box.global_position + Vector3(0, 0.8, 0)
		f.linear_velocity = Vector3.ZERO
		await _wait(0.6)
	await _wait(0.4)
	_check("three fuses open the main gate", box.active and _piece("MainGate").active, "%d in" % box.delivered.size())
	_check("finished objectives leave the list", world.puzzle_objective().count("\n") == 1, world.puzzle_objective().replace("\n", " | "))
	# The Lost Yeet: carried out of its cage with the gun (scared), set down on the mat (happy).
	var yeet := _nearest("lost_yeet", Vector3(-33.5, 0.85, 2.5))
	_look(Vector3(-28, 2.5, 9), Vector3(-33.5, 1, 2.5))
	await _wait(0.4)
	_shot("w05_cage_open")
	_place_player(Vector3(-33.5, 0, 9))
	await _wait(0.3)
	_aim_at(yeet.global_position)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), yeet.global_position - pl.eye_position())
	await _wait(1.0)
	var carried := pl.gun.held_kind == GravityGun.Kind.PROP and pl.gun.held_id == yeet.prop_id
	_check("the gun carries the Lost Yeet out, scared", carried and yeet._yeet_model.base_mood == "scared", "holding %s, mood %s" % [carried, yeet._yeet_model.base_mood])
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	var mat: Receptacle = _piece("RescueMat")
	yeet.global_position = mat.global_position + Vector3(0, 1.2, 0)
	yeet.linear_velocity = Vector3.ZERO
	await _wait(0.8)
	_check("the rescue mat takes the Lost Yeet, grinning", mat.active and yeet._yeet_model.base_mood == "grin", "mat %s, mood %s" % [mat.active, yeet._yeet_model.base_mood])
	_look(mat.global_position + Vector3(2.5, 2.0, -3.5), mat.global_position + Vector3(0, 1.0, 0))
	await _wait(0.5)
	_shot("w06_rescued")
	_place_player(_piece("Exit").global_position + Vector3(0, 0.3, 0))
	await _wait(0.8)
	_check("the exit finishes the level", world.puzzle_finish >= 0.0, "")
	var res: Dictionary = world.puzzle_results
	_check("results arrive with a medal", res.get("medal", "") == "gold", "medal %s" % res.get("medal", ""))
	await _wait(0.3)
	_shot("w07_results")


func _pump_house() -> void:
	var f1: FloodZone = _piece("Flood1")
	var f2: FloodZone = _piece("Flood2")
	_check("the bathtub starts full", absf(f2.depth_at(Vector3(2, 0, 21)) - 2.6) < 0.05 and f1.volume() < 0.01, "depth %.2f m, room 1 %.1f m³" % [f2.depth_at(Vector3(2, 0, 21)), f1.volume()])
	_look(Vector3(0, 4.5, 1), Vector3(0, 1, 12))
	await _wait(0.4)
	_shot("p01_rising_tide")
	# 1: the button opens the valves; the room fills.
	var button: PuzzleNode = _piece("Button1")
	_place_player(button.global_position + Vector3(1.2, 0, 0))
	await _wait(0.3)
	_aim_at(button.use_point())
	world.use_pressed(pl)
	await _wait(0.5)
	_check("the button opens the valves", _piece("Valve1a").active and _piece("Valve1b").active, "")
	_place_player(Vector3(0, 3, 13.5))
	var t0: float = world.now()
	while f1.depth_at(Vector3(0, 0, 7)) < 1.9 and world.now() - t0 < 40.0:
		await _wait(0.5)
	var poured: float = (_piece("Valve1a") as FloodValve).poured + (_piece("Valve1b") as FloodValve).poured
	_check("the room fills up", f1.depth_at(Vector3(0, 0, 7)) >= 1.9, "%.2f m after %.0f s" % [f1.depth_at(Vector3(0, 0, 7)), world.now() - t0])
	_check("no water is lost or made", absf(f1.volume() - poured) < poured * 0.02 + 0.5, "%.1f m³ in, %.1f m³ there" % [poured, f1.volume()])
	await _wait(1.0)
	var crate := _nearest("crate", Vector3(-3, 0.6, 5))
	var surface := f1.surface_at(Vector3(0, 0, 7))
	_check("crates float up with the water", crate.global_position.y > surface - 0.8, "crate at y %.1f, water at %.1f" % [crate.global_position.y, surface])
	_look(Vector3(-1, 4.7, 13.0), Vector3(1, 1.2, 3))
	await _wait(0.4)
	_shot("p02_flooded")
	# What the water costs (host step, everyone's surface texture), the room 1 grid full.
	var us := Time.get_ticks_usec()
	for k in 30:
		f1._step(1.0 / 60.0)
	var step_ms := (Time.get_ticks_usec() - us) / 30000.0
	us = Time.get_ticks_usec()
	for k in 30:
		f1._changed = true
		f1._update_texture()
	var tex_ms := (Time.get_ticks_usec() - us) / 30000.0
	_check("the water is cheap enough", step_ms < 6.0 and tex_ms < 6.0, "step %.2f ms, texture %.2f ms (%d x %d cells)" % [step_ms, tex_ms, f1.nx, f1.nz])
	# A Yeet let go in the middle of the water floats (swims), it doesn't sink to the bottom.
	_place_player(Vector3(1, 1.0, 7))
	await _wait(2.0)
	_check("Yeets float in deep water", pl.global_position.y > 0.8 and pl.is_alive(), "player at y %.1f, water at %.1f" % [pl.global_position.y, f1.surface_at(Vector3(1, 0, 7))])
	_shot("p03_swimming")
	# The network: every chunk encoded and decoded again is the same water (to the mm).
	var before := f1.depth.duplicate()
	var st: Array = f1.full_state()
	f1.depth.fill(0.0)
	for k in st[0].size():
		f1.decode_chunk(st[0][k], st[1][k])
	var worst := 0.0
	for k in before.size():
		worst = maxf(worst, absf(before[k] - f1.depth[k]))
	_check("flood chunks survive the trip over the network", worst < 0.001 and st[0].size() > 0, "%d chunks, worst %.4f m" % [st[0].size(), worst])
	_place_player(Vector3(0, 3, 13.5))
	await _wait(0.6)
	_check("up on the ledge: checkpoint", _piece("Checkpoint2").active, "")
	# 2: a crate floats (no good); the anvil sinks onto the plug and the bathtub drains.
	var crate2 := _nearest("crate", Vector3(3, 3.6, 16.5))
	crate2.global_position = Vector3(0, 2.0, 24)
	crate2.linear_velocity = Vector3.ZERO
	await _wait(2.0)
	_check("a crate floats in the bathtub (not on the plug)", crate2.global_position.y > 1.8 and not _piece("PlugPlate").active, "crate at y %.1f" % crate2.global_position.y)
	crate2.global_position = Vector3(3, 3.6, 16.5)
	_look(Vector3(-2, 4.8, 17.4), Vector3(0, 1.0, 27))
	await _wait(0.5)
	_shot("p04_bathtub")
	var anvil := _nearest("anvil", Vector3(-3, 3.3, 16.5))
	anvil.global_position = Vector3(0, 3.2, 23.5)
	anvil.linear_velocity = Vector3(0, -2, 0)
	await _wait(2.5)
	_check("the anvil sinks onto the plug", _piece("PlugPlate").active and anvil.global_position.y < 1.0, "anvil at y %.1f" % anvil.global_position.y)
	_check("the door stays shut while it's full", not _piece("Door2").active and _piece("Level2").active, "")
	t0 = world.now()
	while not _piece("Door2").active and world.now() - t0 < 40.0:
		await _wait(0.5)
	_check("drained: the door opens", _piece("Door2").active and f2.depth_at(Vector3(0, 0, 24)) < 0.5, "%.2f m left after %.0f s" % [f2.depth_at(Vector3(0, 0, 24)), world.now() - t0])
	_look(Vector3(-3, 4.8, 16.5), Vector3(0, 0.5, 28))
	await _wait(0.5)
	_shot("p05_drained")
	# 3: fire from the lit beacon, carried in a crate to the other two.
	var lit: Beacon = _piece("BeaconLit")
	_check("one beacon burns from the start", lit.active and not _piece("BeaconA").active, "")
	var torch := _nearest("crate", Vector3(2, 0.6, 33))
	torch.global_position = lit.bowl_position() + Vector3(0.9, 0.2, 0)
	torch.linear_velocity = Vector3.ZERO
	await _wait(1.5)
	_check("a crate held in the flames catches fire", world.is_burning(torch), "")
	_look(Vector3(0, 2.2, 31), Vector3(-2, 1.2, 35))
	await _wait(0.3)
	_shot("p06_beacon")
	for b_name in ["BeaconA", "BeaconB"]:
		var b: Beacon = _piece(b_name)
		torch.global_position = b.bowl_position() + Vector3(0, 0.9, 0)
		torch.linear_velocity = Vector3.ZERO
		await _wait(1.2)
	_check("the burning crate lights both beacons", _piece("BeaconA").active and _piece("BeaconB").active, "A %s, B %s" % [_piece("BeaconA").active, _piece("BeaconB").active])
	await _wait(1.0)
	_check("both beacons open the gate", _piece("Gate3").active, "")
	# 4: the wooden wall burns down; its fire lights the fuse; the fuse lights the beacon by
	# the ice wall, which melts a way through.
	_check("the wooden wall is too tough to need burning? (still standing)", not _piece("WoodGone").active, "")
	torch.global_position = Vector3(1.5, 0.6, 47.6)
	torch.linear_velocity = Vector3.ZERO
	if not world.is_burning(torch):
		world.server_ignite_prop(torch, 10.0)
	await _wait(1.5)
	_check("the wooden wall catches fire", not world._burning_walls.is_empty(), "")
	_look(Vector3(-2, 2.0, 45.8), Vector3(1, 1.5, 48.5))
	await _wait(0.2)
	_shot("p07_wall_burning")
	t0 = world.now()
	while not _piece("WoodGone").active and world.now() - t0 < 12.0:
		await _wait(0.5)
	_check("it burns down", _piece("WoodGone").active, "%.0f s" % (world.now() - t0))
	var fuse: FuseLine = _piece("Fuse4")
	_check("its fire lights the fuse behind it", fuse.lit or fuse.burned > 0.0, "burned %.2f" % fuse.burned)
	if not fuse.lit and fuse.burned == 0.0:
		fuse.lit = true # (go on with the rest anyway)
	_look(Vector3(-1, 2.0, 50), Vector3(3, 0.2, 54))
	await _wait(1.5)
	_shot("p08_fuse")
	t0 = world.now()
	while not _piece("IceGone").active and world.now() - t0 < 15.0:
		await _wait(0.5)
	_check("the fuse lights the beacon, the beacon melts the ice", _piece("BeaconC").active and _piece("IceGone").active, "beacon %s after %.0f s" % [_piece("BeaconC").active, world.now() - t0])
	var f4: FloodZone = _piece("Flood4")
	_check("the meltwater runs into the room", f4.volume() > 0.3, "%.2f m³" % f4.volume())
	_look(Vector3(-1.5, 2.2, 54), Vector3(2.5, 1.3, 58.5))
	await _wait(0.5)
	_shot("p09_melted")
	_place_player(_piece("Exit").global_position + Vector3(0, 0.3, 0))
	await _wait(0.8)
	_check("the exit finishes the level", world.puzzle_finish >= 0.0, "")


## A ball thrown straight at a target from 2 m away.
func _throw_at(t: PuzzleNode) -> void:
	var face := t.global_transform.basis.z.normalized()
	var start := t.global_position + face * 2.2
	var b: Prop = world.server_spawn_prop("ball", Transform3D(Basis.IDENTITY, start), Vector3.ZERO, Color(0, 0, 0, 0), 0, -face * 12.0)
	await _wait(0.45)
	if is_instance_valid(b):
		world.server_despawn_prop(b)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _piece(n: String) -> PuzzleNode:
	for p in world.arena.puzzle:
		if p.name == n:
			return p
	push_error("no puzzle piece " + n)
	return null


func _nearest(kind: String, to: Vector3) -> Prop:
	var best: Prop = null
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.kind == kind and (best == null or p.global_position.distance_to(to) < best.global_position.distance_to(to)):
			best = p
	return best


func _place_player(pos: Vector3) -> void:
	pl.respawn(pos, 0.0)
	pl.cmd.move = Vector2.ZERO


## Point the player's view at a spot (also when headless).
func _aim_at(p: Vector3) -> void:
	var to := p - pl.eye_position()
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var to := target - eye
	_place_player(eye - Vector3(0, Player.EYE_STAND, 0))
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
