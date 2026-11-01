extends Node
## Developer check for "Make your own versions" (the Make Your Own Workshop, in MegaYeet):
## a pipe of your own pours out of its model's Spout, sideways out of the wall, and fills the
## pool; a drain takes water in at its Intake; oil drums (a PropType) have their model, their
## weight and toughness, a convex shape from their "Collision" mesh, while the built-in
## barrels stay as they were; a trap of your own (the thorn bed) has its model and name, the
## shop sells it apart from the built-in fire grate, and built it hurts and slows a monster by
## its own numbers. Screenshots. Exits 1 if a step fails.
## Usage: godot -- --host --map res://custom/make_your_own/workshop.tscn --mode megayeet --bots 0 --port 24810 --tour <dir> --tour-mode makeyourown

var world: Node
var out_dir := ""
var _failed := 0
var _camera: Camera3D


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func():
		print("MAKE YOUR OWN CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var mode := world.mode_logic as ModeMegaYeet
	var pl: Player = world.local_player
	pl.is_bot = true # (held still: no player input)
	mode.phase_end = world.now() + 999.0
	mode._send_state()
	var pipe: FloodValve = null
	var drain: FloodDrain = null
	var thorns: TrapSpot = null
	var grate: TrapSpot = null
	for n in world.arena.puzzle:
		if n is FloodValve:
			pipe = n
		elif n is FloodDrain:
			drain = n
		elif n is TrapSpot:
			if (n as TrapSpot).trap_name != "":
				thorns = n
			else:
				grate = n
	# The pipe: water out of its Spout, out into the pool (not down the wall).
	var land := pipe.landing() if pipe else Vector3.ZERO
	_check("a pipe of your own pours from its model's Spout, out from the wall", pipe != null and pipe._spout != null and land.z > pipe.global_position.z + 0.8, "lands %.1f m out" % (land.z - pipe.global_position.z if pipe else 0.0))
	await _wait(4.0)
	var zone := FloodZone.at(world, land)
	var deep := zone.depth_at(land) if zone else 0.0
	_check("... and it fills the pool", deep > 0.02, "%.2f m deep" % deep)
	_check("a drain takes water in at its Intake", drain != null and drain._intake != null and drain.intake().distance_to(drain.global_position) > 0.5, "")
	_cam(Vector3(-4, 4.5, 2), Vector3(-8, 1.5, -5))
	await _wait(0.3)
	await _shot("y01_pipe")
	# Props of your own.
	var drums := []
	var barrels := []
	for p: Prop in world.props.values():
		if p.ptype:
			drums.append(p)
		elif p.kind == "barrel":
			barrels.append(p)
	var d: Prop = drums[0] if not drums.is_empty() else null
	var shaped: bool = d != null and d.get_children().any(func(c): return c is CollisionShape3D and c.shape is ConvexPolygonShape3D)
	_check("oil drums (a PropType): your model, weight, toughness, a shape from its Collision mesh", drums.size() == 4 and is_equal_approx(d.mass, 60.0) and d.def.fragile == 22000.0 and d.def.label == "Oil drum" and shaped, "%d drums, %.0f kg, shaped %s" % [drums.size(), d.mass if d else 0.0, shaped])
	_check("... and the built-in barrels stay as they were", barrels.size() == 2 and is_equal_approx((barrels[0] as Prop).mass, 40.0) and (barrels[0] as Prop).ptype == null, "%d barrels" % barrels.size())
	_cam(Vector3(5, 2.5, -6), Vector3(5, 0.5, -11))
	await _wait(0.3)
	await _shot("y02_drums")
	# A trap of your own.
	var looks := thorns != null and thorns.find_children("Thorns", "", true, false).size() > 0
	_check("a trap of your own: its name, its numbers, its model", thorns != null and thorns.title() == "Thorn bed" and thorns.stat("damage") == 45.0 and thorns.stat("slows_to") == 0.25 and looks, "model %s" % looks)
	var items: Array = ModeMegaYeet.shop_items(world, pl).filter(func(it): return it.tab == 0)
	var names: Array = items.map(func(it): return it.name)
	_check("... the shop sells it apart from the built-in fire grate", names.has("Thorn bed") and names.has("Fire grate") and items.size() == 2, "%s" % [names])
	pl.respawn(thorns.global_position + Vector3(0, 0, 3), 0.0)
	await _wait(0.3)
	world.hud.open_shop()
	await _wait(0.6)
	await _shot("y03_shop")
	(world.hud._shop as ShopWindow)._buy("trap:" + thorns.type_key())
	await _wait(0.5)
	world.hud._shop.close()
	_check("... bought, it's built", thorns.active and thorns.built and not grate.built, "built %s" % thorns.built)
	pl.respawn(mode.heart.global_position + Vector3(4, 0, 0), 0.0)
	var m = world.horde.server_spawn(thorns.global_position + Vector3(0, 0, -1.2), "shambler")
	var hp0: float = m.hp
	await _wait(0.6)
	_check("... it hurts and slows a monster by its own numbers", m.hp < hp0 - 15.0 and is_equal_approx(m.slow_to, 0.25), "hp %.0f -> %.0f, slowed to %.2f" % [hp0, m.hp, m.slow_to])
	_cam(thorns.global_position + Vector3(5, 4, 5), thorns.global_position)
	await _wait(0.2)
	await _shot("y04_thorns")
	print("MAKE YOUR OWN CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


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
