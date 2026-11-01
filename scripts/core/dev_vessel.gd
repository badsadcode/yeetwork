extends Node
## Developer check for the Map Kit's Vessel (Make Your Own Boat): the boat's pieces are on a
## ship that rides the swell (heave, pitch, roll within its limits); a Yeet and the cargo on
## deck stay aboard; the flags, the ladder, the crane and the breakable fence ride with it;
## overboard, the ladder takes a Yeet back up onto the deck. Screenshots. Exits 1 if a step
## fails.
## Usage: godot -- --host --map res://custom/make_your_own/boat.tscn --mode sandbox --bots 0 --port 24940 --tour <dir> --tour-mode vessel

var world: Node
var out_dir := ""
var _failed := 0
var _camera: Camera3D


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func():
		print("VESSEL CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var pl: Player = world.local_player
	pl.is_bot = true # (held still: no player input)
	var ship := world.arena.carrier as Ship
	var deck: Node = ship.find_child("Deck", true, false) if ship else null
	_check("the boat is a ship riding the sea (its pieces on it, not High Seas' own events)", ship != null and not ship.high_seas and deck != null and deck.get_parent() == ship and ship.ocean != null, "")
	# It rides the swell.
	var x0 := ship.global_transform
	var most := 0.0
	var moved := 0.0
	for k in 30:
		await _wait(0.1)
		most = maxf(most, ship.tilt())
		moved = maxf(moved, ship.global_transform.origin.distance_to(x0.origin) + (ship.global_transform.basis.y - x0.basis.y).length())
	_check("... it heaves and rolls with the swell, within its limits", moved > 0.01 and most < deg_to_rad(12.0 + 5.0 + 1.0), "moved %.3f, most tilt %.1f deg" % [moved, rad_to_deg(most)])
	# A Yeet and the cargo aboard.
	pl.respawn(world.arena.random_spawn(0, world.rng), 0.0)
	await _wait(5.0)
	var inv := ship.global_transform.affine_inverse()
	var aboard := ship.deck_box.has_point(inv * pl.global_position) and (inv * pl.global_position).y > 1.0
	var crates := 0
	for p: Prop in world.props.values():
		if p.kind == "crate" and ship.deck_box.has_point(inv * p.global_position) and (inv * p.global_position).y > 1.0:
			crates += 1
	_check("a Yeet on deck stays aboard (carried, not slid off)", aboard, "deck-local %s" % (inv * pl.global_position))
	_check("... and so does the cargo", crates == 3, "%d of 3 crates" % crates)
	# Everything else on it rides along.
	var red: Vector3 = world.arena.flag_pos(1)
	var stand_red: Vector3 = ship.global_transform * Vector3(-9, 1.6 + 0.4, 0)
	_check("the flags ride with it (where the game looks for them is where they are)", red.distance_to(stand_red) < 0.05, "%.3f m apart" % red.distance_to(stand_red))
	var ladder := ship.find_children("*", "Ladder", true, false)
	_check("... and its ladder (known to the bots in the sea)", not ladder.is_empty() and world.arena.ladders.has((ladder[0] as Ladder).foot()), "")
	var crane := ship.find_children("*", "Crane", true, false)
	_check("... and its crane (it knows it's on a ship)", not crane.is_empty() and (crane[0] as Crane).crane.ship == ship, "")
	var fence: Destructible = null
	for d in world.arena.destructibles:
		fence = d
	_check("... and its breakable fence", fence != null and fence.get_parent() == ship, "")
	# Overboard: up the ladder and back aboard.
	var ld := ladder[0] as Ladder
	pl.respawn(ld.global_transform * Vector3(0, 1.4, 0.8), 0.0)
	var top := -100.0
	for k in 60:
		await _wait(0.15)
		var at := ld.global_transform * Vector3(0, 3.0, -2.0)
		_face(pl, at)
		pl.cmd.move = Vector2(0, 1)
		var l := ship.global_transform.affine_inverse() * pl.global_position
		top = maxf(top, l.y)
		if l.y > 1.5 and pl.is_on_floor():
			break
	pl.cmd.move = Vector2.ZERO
	var l2 := ship.global_transform.affine_inverse() * pl.global_position
	_check("overboard, the ladder takes a Yeet back up onto the deck", l2.y > 1.4 and absf(l2.z) < 4.0, "deck-local %s (highest %.1f)" % [l2, top])
	_cam(ship.global_transform * Vector3(-24, 9, 20), ship.global_transform * Vector3(0, 2, 0))
	await _wait(0.4)
	await _shot("v01_boat")
	_cam(ship.global_transform * Vector3(-11, 4.5, 0), ship.global_transform * Vector3(6, 2, 0))
	await _wait(0.4)
	await _shot("v02_deck")
	print("VESSEL CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _face(q: Player, at: Vector3) -> void:
	var to := at - q.eye_position()
	q.yaw = atan2(-to.x, -to.z)
	q.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _cam(eye: Vector3, target: Vector3) -> void:
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 70.0
		world.add_child(_camera)
	_camera.look_at_from_position(eye, target)
	_camera.make_current()


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
