extends Node
## Developer check for Grandma's Glasses' study (docs/design/GIANT_HOUSE.md): a real Yeet, with real
## jumps, walks the whole route: in under the door, up the stairs of books (none of them too high),
## up the ribbon, along the shelf; the fight, on the shelf, a bunny knocked off falling and not
## climbing back; a matchbox on the plate topples the big book, once the dust's gone and not before,
## and the Yeet walks across it to the desk; the diary; off the desk, hurt but alive, out by the mouse hole.
## Screenshots at each stage. Exits 1 if a step fails.
## Usage: godot -- --host --map res://adventures/grandmas_glasses.adventure.tres --mode adventure --spooky off --tour <dir> --tour-mode study

var world: Node
var out_dir := ""
var _failed := 0
var _top_up := false


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func():
		print("STUDY CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	var mode := world.mode_logic as ModeAdventure
	var horde: Horde = world.horde
	var fight: Encounter = _named("TheDust")
	var book: AnimatedModel = _named("BigBook")
	_check("the map check has nothing to say", _problems().is_empty(), "%s" % [_problems()])
	_check("the big book has its animation, and something solid", book._anim != "" and not book._bodies.is_empty(), "%s, %d bodies" % [book._anim, book._bodies.size()])
	await _wait(3.2)
	await _shot("s01_start")
	# In under the door.
	await _walk(pl, [Vector3(-22, 0, 28), Vector3(-22, 0, 22)])
	_check("in under the door, onto the rug", pl.global_position.z < 26.0 and pl.global_position.y < 1.0, "%s" % pl.global_position)
	await _wait(0.5)
	await _shot("s02_the_room")
	_check("the voice from above starts", _named("IntoTheRoom").active, "")
	# The stairs of books, every step with a real jump; then along the first shelf to the ribbon.
	var stairs: Array[Vector3] = [Vector3(-36, 0, -13)]
	for step in 7:
		stairs.append(Vector3(-36.0 + step * 3.0, 1.1 * (step + 1), -19))
	var got := await _walk(pl, stairs)
	_check("up the stairs of books, jump by jump", got and pl.global_position.y > 7.0, "%s" % pl.global_position)
	got = await _walk(pl, [Vector3(-18, 8, -24), Vector3(-25.5, 8, -23.2)])
	_check("onto the first shelf", got and pl.global_position.y > 7.5, "%s" % pl.global_position)
	await _shot("s03_first_shelf")
	var top := await _climb(pl, _ladder(), 14.5)
	_check("up the ribbon, onto the second shelf", top > 14.5, "y %.1f" % top)
	got = await _walk(pl, [Vector3(-21.5, 15, -26)])
	await _wait(0.5)
	_check("the checkpoint: the first objective done", got and _named("UpTheShelf").active, "%s" % pl.global_position)
	await _shot("s04_second_shelf")
	# The fight, up on the shelf: the plate does nothing till it's over.
	_top_up = true
	_keep_alive(pl)
	var box: Prop = _prop_near(Vector3(-18.5, 15.6, -26))
	_check("a matchbox to carry", box != null, "")
	_place_on_plate(box)
	await _wait(1.5)
	_check("the plate's down, but with the dust still there the book stays put", _named("LoosePlate").active and not book.active, "plate %s, book %s" % [_named("LoosePlate").active, book.active])
	await _walk(pl, [Vector3(-13, 15, -26)])
	await _until(func(): return mode._fight == fight and horde.count() >= 3, 6.0)
	_check("the dust wakes: they come through on the shelf", mode._fight == fight and horde.count() >= 3, "%d" % horde.count())
	var on_shelf: bool = horde.monsters.all(func(m): return m.pos.y > 14.0)
	_check("... standing on the shelf, not the floor below", on_shelf, "%s" % [horde.monsters.map(func(m): return m.pos.y)])
	await _until(func(): return pl.hp < 100.0 or horde.monsters.any(func(m): return m.pos.distance_to(pl.global_position) < 3.0), 12.0)
	_check("... and they come for the Yeet", horde.monsters.any(func(m): return m.pos.distance_to(pl.global_position) < 6.0), "")
	await _shot("s05_fight")
	# One knocked off the edge.
	if not horde.monsters.is_empty():
		var victim = horde.monsters[0]
		var vid: int = victim.id
		victim.pos = Vector3(-12, 15, -24.5) # (west of the desk: nothing to land on but what's far below)
		horde._hit(victim, 1.0, Vector3(0, 4, 12), pl.player_id, "punt")
		await _until(func(): return horde.get_monster(vid) == null, 5.0)
		_check("one knocked off the shelf falls to its end, and doesn't climb back", horde.get_monster(vid) == null, "")
	await _until(func():
		_finish_off(horde)
		return fight.active, 25.0)
	_check("all of it cleared", fight.active, "")
	await _wait(2.6)
	_check("the plate was down all along: the big book topples", book.active, "")
	var look: Vector3 = book.global_position + Vector3(0, 1, 5) - pl.eye_position()
	pl.yaw = atan2(-look.x, -look.z)
	await _wait(0.2)
	await _shot("s06_the_book")
	_top_up = false
	# Across it, on foot.
	got = await _walk(pl, [Vector3(-6, 15, -26), Vector3(3, 15, -25.2), Vector3(5.5, 15, -24.4), Vector3(6, 16, -22), Vector3(6, 16, -17), Vector3(7, 15, -13)])
	_check("across the book, on foot, to the desk", got and pl.global_position.y > 14.5 and pl.global_position.z > -17.0, "%s" % pl.global_position)
	await _shot("s07_the_desk")
	# The diary, as a player reads it.
	got = await _walk(pl, [Vector3(8, 15, -10.5)])
	var diary: StoryNote = _named("HerDiary")
	_check("the diary's within reach", got and diary.usable(), "%s" % pl.global_position)
	diary.server_used(pl)
	await _wait(0.3)
	await _shot("s08_diary")
	world.use_pressed(pl)
	await _wait(2.0)
	_check("read: it's on, the flag remembers, the mouse hole opens", diary.active and world.story_flag("read_the_diary") and _named("MouseDoor").active, "")
	# Off the edge: a long way down, and no harm.
	got = await _walk(pl, [Vector3(8, 15, 1), Vector3(8, 0, 8)], 8.0)
	await _until(func(): return pl.is_on_floor() and pl.global_position.y < 1.0, 4.0)
	_check("off the desk: it hurts, but you're fine, as Mabel says", pl.is_alive() and pl.hp >= 50.0 and pl.global_position.y < 1.0, "hp %d, %s" % [pl.hp, pl.global_position])
	await _wait(0.5)
	got = await _walk(pl, [Vector3(25, 0, 26), Vector3(25, 0, 35)])
	await _until(func(): return world.hud._results != null, 5.0)
	_check("out by the mouse hole: the end screen", got and world.hud._results != null, "%s" % pl.global_position)
	await _shot("s09_end")
	print("STUDY CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Walks to each point with the real controls, jumping when something's in the way or the next point's
## higher. False if it gave up on one.
func _walk(pl: Player, points: Array, each := 12.0) -> bool:
	for p: Vector3 in points:
		var t := 0.0
		var flat_was := INF
		var stuck := 0.0
		while t < each:
			var to: Vector3 = p - pl.global_position
			var flat := Vector2(to.x, to.z).length()
			if flat < 0.7 and absf(to.y) < 1.0:
				break
			pl.yaw = atan2(-to.x, -to.z)
			pl.pitch = 0.0
			pl.cmd.move = Vector2(0, 1)
			if flat >= flat_was - 0.02:
				stuck += 0.05
			else:
				stuck = 0.0
			flat_was = flat
			var up_ahead: bool = to.y > 0.3 and flat < 3.0
			var want_jump: bool = pl.is_on_floor() and (up_ahead or stuck > 0.15)
			pl.cmd.jump = want_jump
			pl.cmd.jump_pressed = want_jump
			await _wait(0.05)
			t += 0.05
		pl.cmd.move = Vector2.ZERO
		pl.cmd.jump = false
		pl.cmd.jump_pressed = false
		if t >= each:
			print("  (gave up on the way to %s, at %s)" % [p, pl.global_position])
			return false
	return true


## Climbs a ladder from where the Yeet stands (facing it, holding forward); the height reached.
func _climb(pl: Player, l: Ladder, want: float) -> float:
	var top := -100.0
	for k in 80:
		var to := l.global_position - l.global_basis.z * 2.0 + Vector3(0, l.height, 0) - pl.eye_position()
		pl.yaw = atan2(-to.x, -to.z)
		pl.pitch = 0.4
		pl.cmd.move = Vector2(0, 1)
		await _wait(0.15)
		top = maxf(top, pl.global_position.y)
		if pl.global_position.y > want and pl.is_on_floor():
			break
	pl.cmd.move = Vector2.ZERO
	return pl.global_position.y if pl.is_on_floor() else top


func _place_on_plate(box: Prop) -> void:
	if box == null:
		return
	var plate: PressurePlate = _named("LoosePlate")
	PhysicsServer3D.body_set_state(box.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis.IDENTITY, plate.global_position + Vector3.UP * 0.6))
	PhysicsServer3D.body_set_state(box.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)


func _prop_near(p: Vector3) -> Prop:
	for q: Prop in world.props.values():
		if is_instance_valid(q) and q.global_position.distance_to(p) < 2.0:
			return q
	return null


func _problems() -> Array:
	var out := []
	for n in world.arena.puzzle:
		out.append_array(n.problems())
	return out


func _ladder() -> Ladder:
	for n in world.arena.find_children("*", "Ladder", true, false):
		return n
	return null


func _finish_off(horde: Horde) -> void:
	for m in horde.monsters.duplicate():
		if m.hp > 0.0 and m.state != Horde.State.HELD:
			horde._damage(m, 99999.0, "fire")


func _keep_alive(pl: Player) -> void:
	while _top_up and is_inside_tree():
		if pl.is_alive():
			world.server_set_hp(pl, 100.0)
		await _wait(0.25)


func _until(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return
		await _wait(0.1)
		t += 0.1


func _named(n: String) -> Variant:
	for p in world.arena.puzzle:
		if String(p.name) == n:
			return p
	return null


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
