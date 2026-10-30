extends Node
## Developer check for High Seas: lets the ship ride for a while and reports how far it rolls
## and pitches, whether a player standing still stays put on the deck (riding the moving
## platform), and how much loose cargo is still aboard. Exits 1 if something is off.
## Usage: godot --headless -- --host --map highseas --bots 0 --tour x --tour-mode ship [--sea stormy]

var world: Node
var out_dir := ""


func _ready() -> void:
	# Failsafe: whatever happens, never hang (a script error would stop this coroutine).
	get_tree().create_timer(45.0).timeout.connect(func():
		print("SHIP CHECK FAILED (timed out)")
		get_tree().quit(1))
	await get_tree().create_timer(0.5).timeout
	var ship: Ship = world.arena.carrier
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.cmd.move = Vector2.ZERO
	var spot := Vector3(-14.0, MapHighSeas.DECK + 0.2, 14.0)
	pl.respawn(ship.global_transform * spot, 0.0)
	# This checks the ship's motion: no boom barrels (their blasts and the fires they start
	# throw cargo around for reasons that have nothing to do with the swell).
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.explosive:
			world.server_despawn_prop(p)
	await get_tree().physics_frame
	var aboard_start := _aboard(ship)
	var start_local := {}
	for p: Prop in world.props.values():
		start_local[p] = ship.global_transform.affine_inverse() * p.global_position
	var max_roll := 0.0
	var max_pitch := 0.0
	var max_tilt := 0.0
	var drift := 0.0
	var heave_min := INF
	var heave_max := -INF
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		await get_tree().physics_frame
		var e := ship.global_transform.basis.get_euler()
		max_roll = maxf(max_roll, absf(e.x))
		max_pitch = maxf(max_pitch, absf(e.z))
		max_tilt = maxf(max_tilt, ship.tilt())
		heave_min = minf(heave_min, ship.global_position.y)
		heave_max = maxf(heave_max, ship.global_position.y)
		var local: Vector3 = ship.global_transform.affine_inverse() * pl.global_position
		drift = maxf(drift, Vector2(local.x - spot.x, local.z - spot.z).length())
	var aboard_end := _aboard(ship)
	var local_end: Vector3 = ship.global_transform.affine_inverse() * pl.global_position
	print("SHIP sea=%s roll max %.1f deg, pitch max %.1f deg, tilt max %.1f deg, heave %.2f..%.2f m" % [
		Game.sea_override if Game.sea_override != "" else "ocean", rad_to_deg(max_roll), rad_to_deg(max_pitch), rad_to_deg(max_tilt), heave_min, heave_max])
	print("SHIP player drifted %.2f m on deck (still on deck: %s, height above deck %.2f m), cargo aboard %d -> %d" % [
		drift, absf(local_end.y - MapHighSeas.DECK) < 0.6, local_end.y - MapHighSeas.DECK, aboard_start, aboard_end])
	# Cargo lost overboard: props that are still around but no longer on deck (props that
	# exploded, burnt down or broke apart on deck don't count).
	var overboard := 0
	var inv := ship.global_transform.affine_inverse()
	for p in start_local: # (untyped: props that exploded meanwhile are freed)
		if is_instance_valid(p) and p.kind != "flag" and ship.deck_box.has_point(start_local[p]) 				and not ship.deck_box.has_point(inv * p.global_position):
			overboard += 1
	print("SHIP cargo overboard: %d" % overboard)
	var ok := max_roll > deg_to_rad(0.5) and absf(local_end.y - MapHighSeas.DECK) < 0.6 and overboard <= 3
	var moved := {}
	for p in start_local: # (untyped: props that exploded meanwhile are freed)
		if is_instance_valid(p):
			var d := Vector2((ship.global_transform.affine_inverse() * p.global_position - start_local[p]).x, (ship.global_transform.affine_inverse() * p.global_position - start_local[p]).z).length()
			moved[p.kind] = maxf(moved.get(p.kind, 0.0), d)
	var parts := []
	for k in moved:
		parts.append("%s %.1f" % [k, moved[k]])
	print("SHIP cargo slid (max m per kind): ", ", ".join(parts))
	print("SHIP CHECK ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)


func _aboard(ship: Ship) -> int:
	var n := 0
	var inv := ship.global_transform.affine_inverse()
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.kind != "flag" and ship.deck_box.has_point(inv * p.global_position):
			n += 1
	return n
