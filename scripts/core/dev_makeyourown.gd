extends Node
## Developer check for "Make your own versions" (the Make Your Own Workshop, in MegaYeet):
## a pipe of your own pours out of its model's Spout, sideways out of the wall, and fills the
## pool; a drain takes water in at its Intake; oil drums (a PropType) have their model, their
## weight and toughness, a convex shape from their "Collision" mesh, while the built-in
## barrels stay as they were; a trap of your own (the thorn bed) has its model and name, the
## shop sells it apart from the built-in fire grate, and built it hurts and slows a monster by
## its own numbers. Phase 2: a pickup of your own (the energy drink) shows its model and gives
## its boost for its own time; the fan's own model turns its Rotor; the flag stands take their
## model; a brick wall wears its material, and so do its pieces when it breaks; the map check
## spots a marker spelled wrong. Phase 3: a ladder of your own up out of the swimmable sea
## (climbed to the top), the built-in ladder; a crane of your own slews and swings its load;
## a bell (a Horn) of your own sounds and its Lever is pulled. Breakable models: a door's
## plank breaks (the frame stands), its knob comes off whole; a window's pane shatters, its
## frame stays; a fence's rails fall off whole when the posts holding them go. Monsters of
## your own: the Scarecrow (a MonsterType on the Heart) has its numbers, its model's parts
## tagged and its joints, it's drawn, and it's its share of the waves; a map theme's monster
## slot gives the built-in runners its look. Screenshots.
## Exits 1 if a step fails.
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
		if p.ptype and p.ptype.display_name == "Oil drum":
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
	await _phase2(pl)
	await _phase3(pl)
	await _breakables(pl)
	await _breaking_props(pl)
	await _animated(pl)
	await _monsters()
	# Spray and a rift's glow seen against the sea (the sea mustn't paint over them).
	_cam(Vector3(-1.5, 2.6, -0.5), Vector3(-20, 1.6, -6.5))
	await _wait(0.4)
	await _shot("y14_pipe_against_sea")
	_cam(Vector3(10, 1.4, -9), Vector3(10, 0.8, -30))
	await _wait(0.4)
	await _shot("y15_rift_against_sea")
	print("MAKE YOUR OWN CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _phase2(pl: Player) -> void:
	# A pickup of your own.
	Game.pickups = 0 # (whatever the host saved: pickups on for this check)
	world._server_setup_pickups()
	await _wait(0.3)
	var drink: PickupSpawn = world.arena.pickups[0] if not world.arena.pickups.is_empty() else null
	var can := drink != null and drink.find_children("Can", "", true, false).size() > 0
	_check("a pickup of your own (energy drink): its model on the pad", drink != null and drink.is_available() and can and Pickups.name_of(drink.shown_kind) == "Energy drink", "model %s" % can)
	world.server_clear_buffs(pl)
	pl.respawn(drink.global_position, 0.0)
	await _wait(0.6)
	_check("... walk through it: its boost, for its own time", pl.buff_left("speed") > 15.0 and not drink.is_available(), "speed %.1f s" % pl.buff_left("speed"))
	_cam(drink.global_position + Vector3(2.5, 2.0, 2.5), drink.global_position + Vector3.UP)
	await _wait(1.2)
	# The fan of your own.
	var fan: Prop = null
	for p: Prop in world.props.values():
		if p.kind == "fan":
			fan = p
	var turning: bool = fan != null and fan._rotor != null and fan.find_children("Rotor", "", true, false).size() > 0
	_check("a fan of your own: its model, its Rotor turning", turning, "")
	# Flag stands.
	var stands: int = world.arena.get_children().filter(func(c): return c.has_meta("mk") and c.get_meta("mk").get("type", "") == "flag" and not c is MeshInstance3D and c.find_children("Plinth", "", true, false).size() > 0).size()
	_check("flag stands take your model", stands == 2, "%d" % stands)
	# A brick wall: its material, and its pieces'.
	var wall: Destructible = null
	for d: Destructible in world.arena.destructibles:
		if not d is ModelDestructible:
			wall = d
	var faced := wall != null and wall.face_path.ends_with("bricks.tres")
	_cam(wall.global_position + Vector3(3, 2.5, 6), wall.global_position + Vector3.UP * 1.5)
	await _wait(0.3)
	await _shot("y05_bricks")
	world.server_damage_destructible(wall, wall.global_position + Vector3.UP * 1.2, 2.5, 6000.0, Vector3(0, 0, -6), 0, 1.0)
	await _wait(0.4)
	var pieces := 0
	for p: Prop in world.props.values():
		if p.kind == "shard" and String(p.extra.get("face", "")).ends_with("bricks.tres"):
			pieces += 1
	_check("a brick wall wears its own material, and so do its pieces", faced and pieces > 0 and not wall.broken_cells.is_empty(), "%d pieces in bricks" % pieces)
	await _shot("y06_bricks_broken")
	_cam(Vector3(8, 3.5, -1), Vector3(4.5, 1, -6))
	await _wait(0.3)
	await _shot("y07_fan")
	# The map check spots a marker spelled wrong (and says what a missing one means).
	var root := Node3D.new()
	var bad := Node3D.new()
	bad.name = "spout"
	root.add_child(bad)
	bad.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var notes := Looks.notes("TestPipe", scene, "FloodValve")
	var spelled := notes.any(func(n): return n.contains("\"spout\"") and n.contains("exactly"))
	var missing := notes.any(func(n): return n.contains("no \"Spout\""))
	_check("the map check notes a marker spelled wrong, and one that's missing", spelled and missing, "%s" % [notes])


func _phase3(pl: Player) -> void:
	var sea_ladder: Ladder = null
	var crane: Crane = null
	var bell: Horn = null
	for n in world.arena.find_children("*", "", true, false):
		if n is Ladder and String(n.name) == "SeaLadder":
			sea_ladder = n
		elif n is Crane:
			crane = n
		elif n is Horn:
			bell = n
	# The sea and the ladder out of it.
	var sea := Liquid.at(Vector3(30, -1.5, 0), 0.5)
	_check("the sea round the island is swimmable, its ladder known to the bots", sea != null and sea.swimmable and sea_ladder != null and world.arena.ladders.has(sea_ladder.foot()), "")
	var wood := sea_ladder != null and sea_ladder.find_children("WoodLadder", "", true, false).size() > 0
	world.server_clear_buffs(pl)
	pl.respawn(sea_ladder.global_position + Vector3(0.7, 1.6, 0), 0.0)
	await _wait(0.2)
	_face(pl, sea_ladder.global_position + Vector3(-2, 3.5, 0))
	pl.cmd.move = Vector2(0, 1)
	var top := -10.0
	for k in 40:
		await _wait(0.15)
		_face(pl, sea_ladder.global_position + Vector3(-2, 3.5, 0))
		pl.cmd.move = Vector2(0, 1)
		top = maxf(top, pl.global_position.y)
		if pl.global_position.y > 0.3 and pl.is_on_floor():
			break
	pl.cmd.move = Vector2.ZERO
	_check("a ladder of your own: climbed out of the sea onto the island", wood and pl.global_position.y > -0.2 and top > 0.0, "model %s, at y %.1f (highest %.1f)" % [wood, pl.global_position.y, top])
	# The crane.
	var sc: ShipCrane = crane.crane if crane else null
	var turret: Node3D = sc._slew if sc else null
	var a0 := turret.rotation.y if turret else 0.0
	var p0: Vector3 = sc._load.global_position if sc else Vector3.ZERO
	_cam(crane.global_position + Vector3(14, 10, 14), crane.global_position + Vector3(4, 5, 0))
	# The most it turns and moves in 3 s: it slews to and fro (a sine of the clock), so a short
	# window round a turnaround sees almost nothing (1.5 s: 0.01 rad at worst; 3 s: 0.04).
	var turned := 0.0
	var moved := 0.0
	for k in 30:
		await _wait(0.1)
		if turret:
			turned = maxf(turned, absf(turret.rotation.y - a0))
			moved = maxf(moved, sc._load.global_position.distance_to(p0))
	await _shot("y08_crane")
	var own := sc != null and sc._hook != null and String(turret.name) == "Turret" and sc._load.find_children("CrateLoad", "", true, false).size() > 0
	_check("a crane of your own: its Turret slews, the load (your model) swings from its Hook", own and turned > 0.01 and moved > 0.1, "turned %.2f rad, load moved %.2f m" % [turned, moved])
	# The bell.
	var lever: Node3D = bell._lever if bell else null
	var r0 := lever.rotation.z if lever else 0.0
	pl.respawn(bell.global_position + Vector3(0, 0, 1.6), 0.0)
	await _wait(0.3)
	_face(pl, bell.use_point())
	world.use_pressed(pl)
	await _wait(0.3)
	_check("a bell of your own (a Horn): Use sounds it, its Lever is pulled", lever != null and String(lever.name) == "Lever" and absf(lever.rotation.z - r0) > 0.3, "lever %.2f -> %.2f" % [r0, lever.rotation.z if lever else 0.0])
	_cam(bell.global_position + Vector3(2.5, 2.0, 2.5), bell.global_position + Vector3(0.3, 1.2, 0))
	await _wait(0.1)
	await _shot("y09_bell")
	_cam(sea_ladder.global_position + Vector3(6, 3, 5), sea_ladder.global_position + Vector3(0, 2, 0))
	await _wait(0.2)
	await _shot("y10_sea_ladder")


func _breakables(pl: Player) -> void:
	var door: ModelDestructible = null
	var window: ModelDestructible = null
	var fence: ModelDestructible = null
	for d in world.arena.destructibles:
		if d is ModelDestructible and not (d as ModelDestructible).tear_off:
			var md := d as ModelDestructible
			if md.part_meshes.size() == 8:
				door = md
			elif md.part_meshes.size() == 4:
				window = md
			elif md.part_meshes.size() == 7:
				fence = md
	_check("a door, a window and a fence of your own, breakable part by part", door != null and window != null and fence != null, "")
	pl.respawn(Vector3(15, 0, 16), 0.0)
	_cam(Vector3(15.5, 2.5, 15), Vector3(15.5, 1.0, 8))
	await _wait(0.4)
	await _shot("y11_breakables")
	# The door: one plank, then the knob.
	var plank := _part(door, "Wood_Plank2")
	var knob := _part(door, "Metal_Knob")
	var frame_bodies := door.get_children().filter(func(c): return c is StaticBody3D and not c.has_meta("cell")).size()
	world.server_damage_destructible(door, door.cell_world(plank) + Vector3(0, 0.3, 0.05), 0.15, 120.0, Vector3(0, 0, -8), 0, 4.0)
	await _wait(0.4)
	var planks_left := 0
	for i in door.part_meshes.size():
		if door.is_alive(i) and String(door.part_meshes[i].name).begins_with("Wood_Plank"):
			planks_left += 1
	_check("... a hit breaks the door's planks where it lands, the rest hold; its frame (Fixed) stands", not door.is_alive(plank) and planks_left >= 2 and frame_bodies == 3 and door.part_mats[plank] == "wood", "plank alive %s, planks left %d, frame pieces %d" % [door.is_alive(plank), planks_left, frame_bodies])
	world.server_damage_destructible(door, door.cell_world(knob), 0.1, 400.0, Vector3(0, 0, 4), 0, 4.0)
	await _wait(0.4)
	var knob_prop := false
	for p: Prop in world.props.values():
		if p.extra.get("whole", false) and int(p.extra.get("mwall", -1)) == door.wall_id and int(p.extra.get("part", -1)) == knob:
			knob_prop = true
	_check("... its knob (small, metal) comes off whole: a prop", not door.is_alive(knob) and knob_prop and door.part_small[knob] == 1, "prop %s" % knob_prop)
	# The window: a pane shatters, the frame stays.
	var pane := _part(window, "Glass_PaneLeft")
	var bar := _part(window, "Wood_Mullion")
	world.server_damage_destructible(window, window.cell_world(pane) + Vector3(-0.1, 0.2, 0.03), 0.2, 60.0, Vector3(0, 0, -6), 0, 4.0)
	await _wait(0.15)
	await _shot("y12_window")
	await _wait(0.3)
	_check("... a window's pane shatters (glass), its mullion and frame stay", not window.is_alive(pane) and window.is_alive(bar) and window.part_mats[pane] == "glass", "pane %s, mullion %s" % [window.is_alive(pane), window.is_alive(bar)])
	# The fence: break the middle post (the rails still hang on the outer ones), then the left
	# post: the left bay's rails hold onto nothing and fall off whole.
	var mid := _part(fence, "Wood_Post1")
	var left := _part(fence, "Wood_Post0")
	world.server_damage_destructible(fence, fence.cell_world(mid) + Vector3(0, 0, -0.1), 0.12, 150.0, Vector3(0, 0, 5), 0, 4.0)
	await _wait(0.3)
	var rails_after_mid := 0
	for i in fence.part_meshes.size():
		if fence.is_alive(i) and String(fence.part_meshes[i].name).begins_with("Wood_Rail"):
			rails_after_mid += 1
	world.server_damage_destructible(fence, fence.cell_world(left) + Vector3(0, 0, -0.1), 0.12, 150.0, Vector3(0, 0, 5), 0, 4.0)
	await _wait(0.6)
	var fallen := 0
	for p: Prop in world.props.values():
		if p.extra.get("whole", false) and int(p.extra.get("mwall", -1)) == fence.wall_id:
			fallen += 1
	_check("... a fence: its rails hold on while a post stands; with both gone they fall off whole", rails_after_mid == 4 and fallen >= 2 and not fence.is_alive(_part(fence, "Wood_Rail0_0")), "rails after the middle post %d, fallen %d" % [rails_after_mid, fallen])
	_cam(Vector3(18, 2.5, 13), Vector3(15, 0.6, 5))
	await _wait(0.6)
	await _shot("y13_fence")
	# Repaired: whole again.
	world.server_restore_wall(fence.wall_id)
	await _wait(0.2)
	_check("... repaired, it's whole again (every part back)", fence.broken_cells.is_empty() and fence.part_meshes.all(func(m): return m.visible), "")


## A door the gun rips off (Tear Off), thrown: it comes apart. A PropType that breaks into its
## parts (a glass cabinet).
func _breaking_props(pl: Player) -> void:
	var shed: ModelDestructible = null
	for d in world.arena.destructibles:
		if d is ModelDestructible and (d as ModelDestructible).tear_off:
			shed = d
	_check("a shed door that tears off (BreakableModel Tear Off)", shed != null, "")
	if shed == null:
		return
	pl.respawn(shed.global_position + Vector3(0, 0, 3.2), 0.0)
	await _wait(0.4)
	var at := shed.global_position + Vector3(0, 1.1, 0)
	_face(pl, at)
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), at - pl.eye_position())
	await _wait(1.0)
	var held := world.get_prop(pl.gun.held_id) as Prop if pl.gun.held_kind == GravityGun.Kind.PROP else null
	var gone := range(shed.cells.size()).all(func(i): return not shed.is_alive(i))
	var frame_left := shed.get_children().filter(func(c): return c is StaticBody3D and not c.has_meta("cell")).size()
	var meshes := held.get_children().filter(func(c): return c is MeshInstance3D and c.visible).size() if held else 0
	_check("... the gun rips it off its frame: its planks, braces and knob, one prop in its hands; the frame stays", held != null and held.extra.get("assembly", false) and gone and frame_left == 3 and meshes == 8, "held %s, parts gone %s, frame pieces %d, meshes %d" % [held != null, gone, frame_left, meshes])
	_cam(shed.global_position + Vector3(2.5, 2.2, 4.5), shed.global_position + Vector3(0, 1.0, 1.5))
	await _wait(0.3)
	await _shot("y16_torn_off")
	# Carried back out of the frame, and thrown: it comes apart into its parts where it lands.
	for k in 10:
		pl.global_position += Vector3(0, 0, 0.25)
		await _wait(0.05)
	var door_id := held.prop_id if held else -1
	pl.pitch = 0.35 # (lifted clear of the floor, then down at it: thrown level, it sails off the island)
	await _wait(0.5)
	pl.gun.server_action(GravityGun.Action.THROW, pl.eye_position(), Vector3(0, -0.6, -1))
	await _wait(0.1)
	pl.gun.server_action(GravityGun.Action.THROW_RELEASE, pl.eye_position(), Vector3(0, -0.6, -1))
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD) # (or it rips the repaired one off again)
	await _wait(1.5)
	var parts := 0
	for p: Prop in world.props.values():
		if p.extra.get("whole", false) and int(p.extra.get("mwall", -1)) == shed.wall_id:
			parts += 1
	_check("... thrown hard, it comes apart into its parts", world.get_prop(door_id) == null and parts >= 6, "door still there %s, parts %d" % [world.get_prop(door_id) != null, parts])
	_cam(shed.global_position + Vector3(3, 2.5, 1), shed.global_position + Vector3(0, 0.3, -1))
	await _wait(0.3)
	await _shot("y17_door_apart")
	world.server_restore_wall(shed.wall_id)
	await _wait(0.2)
	_check("... repaired, it's back on its frame", shed.broken_cells.is_empty() and shed.part_meshes.all(func(m): return m.visible), "broken %s, hidden %d" % [shed.broken_cells, shed.part_meshes.filter(func(m): return not m.visible).size()])
	# A glass cabinet (a PropType that breaks into its parts).
	var cab: Prop = null
	for p: Prop in world.props.values():
		if p.ptype and p.ptype.breaks_into_parts:
			cab = p
	_check("glass cabinets (a PropType that breaks into its parts)", cab != null and cab.is_fragile(), "")
	if cab == null:
		return
	var path := cab.ptype.resource_path
	var where := cab.global_position
	_cam(where + Vector3(2.0, 1.6, 2.6), where)
	await _wait(0.2)
	await _shot("y18_cabinets")
	world.server_break_prop(cab, Vector3(0, 0, -8))
	await _wait(0.1)
	await _shot("y19_cabinet_apart")
	var boards := 0
	var glass := 0
	for p: Prop in world.props.values():
		if p.extra.get("ptype", "") == path and p.extra.get("whole", false):
			if p.extra.part == 6:
				glass += 1
			boards += 1
	_check("... broken, its boards and handle fly off whole, its glass shatters", not is_instance_valid(cab) or cab.is_queued_for_deletion(), "")
	_check("... (7 parts, no glass among them)", boards == 7 and glass == 0, "%d parts, %d glass" % [boards, glass])


## Models playing their own animations (AnimatedModel): the windmill turns on the shared clock,
## the ferry carries a Yeet, a button lowers the drawbridge (stand on it) and raises it again.
func _animated(pl: Player) -> void:
	var am := {}
	for n in world.arena.puzzle:
		if n is AnimatedModel:
			am[String(n.name)] = n
	var mill: AnimatedModel = am.get("Windmill")
	var ferry: AnimatedModel = am.get("Ferry")
	var bridge: AnimatedModel = am.get("Drawbridge")
	_check("models playing their own animations (AnimatedModel): a windmill, a sign, a ferry, a drawbridge", am.size() == 4 and mill and mill._anim == "Turn" and ferry and ferry._bodies.size() == 1 and bridge and bridge._bodies.size() == 1, "%s" % [am.keys()])
	if am.size() < 4 or mill == null or ferry == null or bridge == null:
		return
	# The windmill: its sails turn, at the point of their animation the shared clock says.
	var sails := mill._inst.find_child("Sails", true, false) as Node3D
	var x0 := sails.global_basis.x
	await _wait(0.5)
	var turned := sails.global_basis.x.angle_to(x0)
	var drift := absf(mill._ap.current_animation_position - mill.time_now(world.net_time()))
	# (a few frames' lag under load at most: not on the clock, it'd be seconds out)
	_check("... the windmill's sails turn, every player at the same point (the shared clock)", turned > 0.2 and (drift < 0.25 or drift > mill._len - 0.25), "turned %.2f rad, %.3f s off the clock" % [turned, drift])
	_cam(mill.global_position + Vector3(9, 5, 9), mill.global_position + Vector3(0, 5, 0))
	await _wait(0.2)
	await _shot("y20_windmill")
	# The ferry: stand on it, and it carries you out over the sea.
	var deck := ferry._bodies[0][0] as AnimatableBody3D
	world.server_clear_buffs(pl)
	pl.respawn(deck.global_position + Vector3(0, 0.4, 0), 0.0)
	await _wait(0.3)
	# (the most it moves in 3 s: it goes to and fro, so two moments alone can straddle a turn)
	var d0 := deck.global_position
	var moved := 0.0
	var on := true
	for k in 30:
		await _wait(0.1)
		moved = maxf(moved, deck.global_position.distance_to(d0))
		on = on and Vector2(pl.global_position.x - deck.global_position.x, pl.global_position.z - deck.global_position.z).length() < 1.6 and absf(pl.global_position.y - deck.global_position.y - 0.2) < 0.5
	_check("... the ferry carries a Yeet standing on it", moved > 0.8 and on, "deck moved up to %.2f m, the Yeet on it all along %s" % [moved, on])
	_cam(deck.global_position + Vector3(6, 4, -3), deck.global_position)
	await _wait(0.1)
	await _shot("y21_ferry")
	# The drawbridge: up; a press lowers it (walk across), another raises it.
	var span := bridge._bodies[0][0] as AnimatableBody3D
	var up0 := span.global_basis.y.dot(Vector3.UP)
	var btn: PuzzleButton = null
	for n in world.arena.puzzle:
		if n is PuzzleButton and String(n.name) == "BridgeButton":
			btn = n
	btn.server_used(pl)
	await _wait(3.6)
	var flat := span.global_basis.y.dot(Vector3.UP)
	pl.respawn(span.global_position + Vector3(0, 0.4, 0), 0.0)
	await _wait(0.6)
	var standing := pl.is_on_floor() and absf(pl.global_position.y) < 0.4
	_check("... a button (Use) lowers the drawbridge: up, then flat, a Yeet stands on it", up0 < 0.4 and flat > 0.99 and bridge.active and standing, "up %.2f, then %.2f, on it %s (y %.2f)" % [up0, flat, standing, pl.global_position.y])
	_cam(span.global_position + Vector3(-3, 4, 6), span.global_position + Vector3(2, 0, 0))
	await _wait(0.1)
	await _shot("y22_drawbridge")
	pl.respawn(Vector3(15, 0, -11), 0.0)
	btn.server_used(pl)
	await _wait(3.6)
	_check("... pressed again, it rises", span.global_basis.y.dot(Vector3.UP) < 0.4 and not bridge.active, "up %.2f" % span.global_basis.y.dot(Vector3.UP))


## The cell of a model's part by its name.
func _part(d: ModelDestructible, part_name: String) -> int:
	for i in d.part_meshes.size():
		if String(d.part_meshes[i].name) == part_name:
			return i
	return -1


func _face(q: Player, at: Vector3) -> void:
	var to := at - q.eye_position()
	q.yaw = atan2(-to.x, -to.z)
	q.pitch = atan2(to.y, Vector2(to.x, to.z).length())


## Monsters of your own: the Scarecrow's numbers, its mesh (parts tagged from their names, the
## joints from their origins, glowing eyes), drawn in the horde, its share of a wave; and a
## theme's monster slot (a Horde made with the map's theme carrying one).
func _monsters() -> void:
	var h: Horde = world.horde
	var k := Horde.CUSTOM + "0"
	var d: Dictionary = h.defs.get(k, {})
	_check("monsters of your own (a MonsterType on the Heart): the Scarecrow, its numbers", h.types.has(k) and d.get("name") == "Scarecrow" and d.get("like") == "shambler" and is_equal_approx(d.get("hp", 0.0), 55.0) and is_equal_approx(d.get("burn", 0.0), 2.5),
		"%s" % [d])
	if not h.types.has(k):
		return
	var mesh := h.mesh_of(k) as ArrayMesh
	var tags := {}
	var glows := false
	for s in mesh.get_surface_count():
		for uv: Vector2 in mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV]:
			tags[int(round(uv.x))] = true
			glows = glows or uv.y > 0.5
	var joints: Dictionary = mesh.get_meta("joints", {})
	var hips_ok: bool = joints.has(1) and absf((joints[1] as Vector3).y - 0.8) < 0.01 and joints.has(3) and absf((joints[3] as Vector3).y - 1.35) < 0.01
	var mat := mesh.surface_get_material(0) as ShaderMaterial
	var legs: Vector4 = mat.get_shader_parameter("legs") if mat else Vector4.ZERO
	_check("... its model's parts (Torso, Leg_L... Head) tagged to swing, from their joints; its eyes glow", tags.size() == 6 and hips_ok and absf(legs.x - 0.8) < 0.01 and glows and MonsterLook.notes(h.types[k].model).is_empty(),
		"tags %s, joints %s, glow %s" % [tags.keys(), joints, glows])
	var crows := []
	for i in 4:
		crows.append(h.server_spawn(Vector3(2.0 + i * 1.3, 0, 4.0 - i * 0.6), k))
	await _wait(0.3)
	var drawn: int = h._draw[k][0].multimesh.visible_instance_count
	_check("... spawned, drawn in a batch of their own", (crows[0] as Horde.Monster).hp == 55.0 and drawn == 4, "%d drawn" % drawn)
	_cam(Vector3(8.5, 2.2, 9.5), Vector3(4.0, 1.0, 3.5))
	await _wait(0.4)
	await _shot("y20_scarecrows")
	for m in crows:
		h._kill(m, "hit")
	# Its share of the waves: about 0.3 of them, from wave 1.
	var mode := world.mode_logic as ModeMegaYeet
	var was_wave := mode.wave
	mode.wave = 1
	mode._brutes = 0
	var n := 0
	for i in 1000:
		if mode._pick_kind() == k:
			n += 1
	mode.wave = was_wave
	_check("... its share of the waves (Share 0.3), and what the wave says when it comes", absf(n / 1000.0 - 0.3) < 0.06 and h.announcement(k).begins_with("SCARECROWS!"), "%.2f of them" % (n / 1000.0))
	# A theme's monster slot: a Horde made for a map whose theme gives the runners a model.
	var settings: MapSettings = null
	for s in world.arena.find_children("*", "MapSettings", true, false):
		settings = s
	var theme := MapTheme.new()
	theme.monster_runner = h.types[k].model
	var old_theme: MapTheme = settings.theme if settings else null
	if settings:
		settings.theme = theme
	var h2 := Horde.new()
	h2.world = world
	var holder := Node3D.new()
	holder.add_child(h2)
	world.add_child(holder)
	var themed: bool = h2._models.get("runner") == theme.monster_runner and h2.defs.runner.hp == Horde.KINDS.runner.hp and h2._draw["runner"][0].multimesh.mesh == MonsterLook.from_model(theme.monster_runner)
	holder.queue_free()
	if settings:
		settings.theme = old_theme
	_check("a map theme's monster slot: the runners in a model of your own, their numbers as they were", settings != null and themed, "settings %s" % (settings != null))


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
