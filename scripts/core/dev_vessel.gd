extends Node
## Developer check for the Map Kit's Vessel (Make Your Own Boat, in Capture the Flag): the
## boat's pieces are on a ship that rides the swell (heave, pitch, roll within its limits); a
## Yeet and the cargo on deck stay aboard; Blue's flag, the ladder, the crane and the breakable
## fence ride with it; overboard, the ladder takes a Yeet back up onto the deck. Dry land beside
## it stays put: the island's spawn points, the pier's crates, Red's flag (and its flag comes
## home there, Blue's to the moving bow); the pier's pad throws a Yeet aboard. Screenshots.
## Exits 1 if a step fails.
## Usage: godot -- --host --map res://custom/make_your_own/boat.tscn --mode ctf --bots 0 --port 24940 --tour <dir> --tour-mode vessel

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
	_check("... it heaves and rolls with the swell, within its limits", moved > 0.01 and most < deg_to_rad(8.0 + 4.0 + 1.0), "moved %.3f, most tilt %.1f deg" % [moved, rad_to_deg(most)])
	# A Yeet and the cargo aboard.
	pl.respawn(world.arena.to_world(Vector3(-7, 1.8, -2.5)), 0.0) # (the boat's own spawn point: the others are ashore)
	await _wait(5.0)
	var inv := ship.global_transform.affine_inverse()
	var aboard := ship.deck_box.has_point(inv * pl.global_position) and (inv * pl.global_position).y > 1.0
	var crates := 0
	for p: Prop in world.props.values():
		if p.kind == "crate" and ship.deck_box.has_point(inv * p.global_position) and (inv * p.global_position).y > 1.0:
			crates += 1
	_check("a Yeet on deck stays aboard (carried, not slid off)", aboard, "deck-local %s" % (inv * pl.global_position))
	var where := []
	for p: Prop in world.props.values():
		if p.kind == "crate" and not p.extra.get("land", false):
			where.append(inv * p.global_position)
	_check("... and so does the cargo", crates == 3, "%d of 3 crates, deck-local %s" % [crates, where])
	# Everything else on it rides along.
	var blue: Vector3 = world.arena.flag_pos(2)
	var stand_blue: Vector3 = ship.global_transform * Vector3(10.5, 1.6 + 0.4, 1.5)
	_check("Blue's flag (on the boat) rides with it", blue.distance_to(stand_blue) < 0.05, "%.3f m apart" % blue.distance_to(stand_blue))
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
	await _land(pl, ship)
	_cam(ship.global_transform * Vector3(-24, 9, 20), ship.global_transform * Vector3(0, 2, 0))
	await _wait(0.4)
	await _shot("v01_boat")
	_cam(Vector3(-40, 14, 30), Vector3(-25, 1, 0))
	await _wait(0.3)
	await _shot("v03_island_and_boat")
	_cam(ship.global_transform * Vector3(-11, 4.5, 0), ship.global_transform * Vector3(6, 2, 0))
	await _wait(0.4)
	await _shot("v02_deck")
	print("VESSEL CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Dry land beside the boat stays put; the pier's pad throws a Yeet aboard.
func _land(pl: Player, ship: Ship) -> void:
	var land_spawn := Vector3(-48, 1.2, -4)
	var red0: Vector3 = world.arena.flag_pos(1)
	var a0: Vector3 = world.arena.to_world(land_spawn)
	var crates0 := []
	for p: Prop in world.props.values():
		if p.kind == "crate" and p.extra.get("land", false):
			crates0.append(p.global_position)
	await _wait(1.5)
	var crates1 := []
	for p: Prop in world.props.values():
		if p.kind == "crate" and p.extra.get("land", false):
			crates1.append(p.global_position)
	var still := crates0.size() == 3 and crates1.size() == 3
	for i in mini(crates0.size(), crates1.size()):
		still = still and (crates0[i] as Vector3).distance_to(crates1[i]) < 0.05
	_check("dry land stays put while the boat moves: its spawn points, Red's flag, the pier's crates", world.arena.land_points.has(land_spawn) and world.arena.to_world(land_spawn).distance_to(a0) < 0.001 and a0.distance_to(land_spawn) < 0.001 and red0.distance_to(Vector3(-56, 1.4, 4)) < 0.01 and world.arena.flag_pos(1).distance_to(red0) < 0.001 and still, "crates %d, flag at %s" % [crates1.size(), red0])
	# The flags come home: Red's to the island, Blue's to the moving bow.
	var ctf := world.mode_logic as ModeCTF
	var red_flag: Prop = ctf._flag(1) if ctf else null
	var blue_flag: Prop = ctf._flag(2) if ctf else null
	if red_flag and blue_flag:
		red_flag.global_position += Vector3(6, 3, 0)
		blue_flag.global_position += Vector3(-6, 3, 0)
		await _wait(1.0)
		ctf.return_flag(1)
		ctf.return_flag(2)
	var home_red: bool = red_flag != null and red_flag.global_position.distance_to(Vector3(-56, 1.4 + 1.25, 4)) < 0.05 and red_flag.extra.get("land", false)
	var home_blue: bool = blue_flag != null and blue_flag.global_position.distance_to(world.arena.flag_pos(2) + Vector3(0, 1.25, 0)) < 0.3
	_check("... the flags come home: Red's to the island, Blue's to the bow where it is now", home_red and home_blue, "red %s, blue %s" % [home_red, home_blue])
	# Off the pier's end onto the boat.
	pl.respawn(Vector3(-25, 1.6, 0), 0.0)
	var aboard := false
	for k in 30:
		await _wait(0.1)
		var l := ship.global_transform.affine_inverse() * pl.global_position
		if pl.is_on_floor() and k > 3 and ship.deck_box.has_point(l) and l.y > 1.4:
			aboard = true
			break
	_check("the pier's jump pad throws a Yeet aboard the moving boat", aboard, "at %s" % (ship.global_transform.affine_inverse() * pl.global_position))


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
