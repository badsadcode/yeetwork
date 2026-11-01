extends Node
## Developer check for High Seas' cargo (phase 2): containers lashed down in a way that can
## give, open containers (hideouts, pickups inside); a blast frees a lashed container (a heavy
## prop now); a long storm roll strains the lashings until one gives; a container overboard
## floats; cargo drifting far off comes back; the deck crane slews, its load hangs under the
## jib, a Yeet rides it, and it sweeps one off the stack tops. Screenshots. Exits 1 if a step
## fails.
## Usage: godot -- --host --map highseas --bots 0 --port 24700 --tour <dir> --tour-mode shipcargo

var world: Node
var out_dir := ""
var _failed := 0
var ship: Ship
var pl: Player


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func():
		print("SHIP CARGO CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	ship = world.arena.carrier
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	world.hud.visible = false
	var lashed: Array = world.arena.lashed
	var pickups_aboard: int = world.arena.pickups.filter(func(ps): return ship.is_ancestor_of(ps)).size()
	_check("lashed containers and open containers (with pickups)", lashed.size() >= 4 and pickups_aboard >= 2, "%d lashed, %d pickups in containers" % [lashed.size(), pickups_aboard])
	var deck := MapHighSeas.DECK
	# A close look at a lashed container's rods (one mid-ships), and into an open one.
	var li := 0
	for i in lashed.size():
		var o: Vector3 = (lashed[i][3] as Transform3D).origin
		if absf(o.x) < absf((lashed[li][3] as Transform3D).origin.x):
			li = i
	var l0: Transform3D = lashed[li][3]
	var sz := signf(l0.origin.z) if l0.origin.z != 0.0 else 1.0
	_look(l0.origin + Vector3(-8.2, 0.4, sz * 1.5), l0.origin + Vector3(-6.1, -0.6, 0)) # (in the bay gap, at its end)
	await _wait(0.5)
	await _shot("c01_lashed")
	var open_ps: PickupSpawn = world.arena.pickups.filter(func(ps): return ship.is_ancestor_of(ps))[0]
	var door: Vector3 = open_ps.get_meta("doorway")
	var into: Vector3 = (ship.global_transform.affine_inverse() * open_ps.global_position)
	var out := (door - into).normalized()
	_look(door + out * 1.6 + Vector3(0, 1.6, 0), into + Vector3(0, 0.6, 0))
	await _wait(0.5)
	await _shot("c02_open_container")
	# A blast by a lashed container frees it: a heavy prop slides where it stood.
	var top: Vector3 = ship.global_transform * (l0.origin + Vector3(0, MapHighSeas.CONT.y * 0.5 + 0.6, 0))
	var barrel: Prop = world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, top))
	await get_tree().physics_frame
	world.server_explode(barrel)
	await _wait(0.6)
	# (the nearest container prop to where it stood: the blast may have shoved it a good way)
	var freed: Prop = null
	var near := 15.0
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.kind == "container" and p.global_position.distance_to(ship.global_transform * l0.origin) < near:
			near = p.global_position.distance_to(ship.global_transform * l0.origin)
			freed = p
	_check("a blast breaks a container's lashings: it's loose (a heavy prop)", world._cargo_loose.has(li) and freed != null and not (lashed[li][0] as Node3D).visible and freed.mass > 500.0,
		"loose %s, prop %s" % [world._cargo_loose.has(li), freed != null])
	await _wait(1.2) # (the smoke clears a little)
	_look(l0.origin + Vector3(-9.0, 9.0, sz * 7.0), l0.origin + Vector3(0, -2.0, 0))
	await _wait(0.4)
	await _shot("c03_broken_loose")
	# A long storm roll: the lashings creak and give, one after another.
	var before: int = world._cargo_loose.size()
	for k in 240:
		world._server_cargo(0.25, 0.3) # (a minute of rolling about 17 degrees)
	_check("a long storm roll strains the lashings until one gives", world._cargo_loose.size() > before, "%d -> %d loose" % [before, world._cargo_loose.size()])
	# A container overboard floats.
	if freed:
		freed.global_position = ship.global_transform * Vector3(0, 0.5, 30)
		freed.linear_velocity = Vector3.ZERO
		await _wait(4.0)
		# (afloat: near the surface where it is, crest or trough, not some fixed height)
		var fp: Vector3 = freed.global_position if is_instance_valid(freed) else Vector3(0, -99, 0)
		var sea: float = ship.ocean.height_at(fp.x, fp.z)
		_check("a container overboard floats", is_instance_valid(freed) and fp.y > sea - 2.0, "y %.1f, the sea there %.1f" % [fp.y, sea])
	# Cargo drifting far off comes back (like a prop fallen out of the map).
	var far: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, ship.global_position + Vector3(0, 1, 160)))
	var far_id := far.prop_id
	await _wait(1.6)
	_check("cargo drifting far off goes (and map props come back)", world.get_prop(far_id) == null, "")
	# The deck crane.
	var crane: ShipCrane = null
	for c in ship.find_children("*", "ShipCrane", true, false): # (on the ship, or in its Crane piece)
		crane = c
	var load: AnimatableBody3D = crane._load
	var h0: float = crane._slew.rotation.y
	var p0 := load.global_position
	await _wait(2.0)
	var tip: Vector3 = crane.global_transform * (crane._slew.position + Basis(Vector3.UP, crane._slew.rotation.y) * Vector3(crane.jib, 0, 0))
	var under := Vector2(load.global_position.x - tip.x, load.global_position.z - tip.z).length()
	_check("the crane slews, its load hanging under the jib", absf(crane._slew.rotation.y - h0) > 0.01 and load.global_position.distance_to(p0) > 0.1 and under < 4.0, "turned %.3f rad, load %.1f m off plumb" % [absf(crane._slew.rotation.y - h0), under])
	_look(ship.global_transform.affine_inverse() * load.global_position + Vector3(-14, 4, 10), ship.global_transform.affine_inverse() * load.global_position + Vector3(4, 0, 0))
	await _wait(0.3)
	await _shot("c05_crane")
	# Ride it: stand on top, it carries you.
	pl.respawn(load.global_position + Vector3(0, crane.load_size.y * 0.5 + 0.2, 0), 0.0)
	await _wait(3.0)
	var on: Vector3 = load.global_transform.affine_inverse() * pl.global_position
	_check("ride the load: it carries a Yeet standing on it", absf(on.y - crane.load_size.y * 0.5) < 0.4 and absf(on.x) < crane.load_size.x * 0.5 + 0.3 and absf(on.z) < crane.load_size.z * 0.5 + 0.3, "on it at %s" % on)
	# Swept by it: wait till it's moving, stand in its way.
	var knocked := false
	for tries in 6:
		var was := load.global_position
		await get_tree().physics_frame
		var vel := (load.global_position - was) * Engine.physics_ticks_per_second
		if vel.length() < 1.5:
			await _wait(1.0)
			continue
		var ahead := vel.normalized()
		ahead.y = 0.0
		pl.respawn(load.global_position + ahead.normalized() * 2.0 - Vector3(0, 1.0, 0), 0.0)
		for k in 20:
			await get_tree().physics_frame
			if pl.velocity.length() > 4.0:
				knocked = true
				break
		if knocked:
			break
	_check("the load sweeps a Yeet in its way", knocked, "v %.1f" % pl.velocity.length())
	print("SHIP CARGO CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Which way an open container's doors face (its pickup sits toward the closed end).
func _door_dir(local_pickup: Vector3) -> float:
	var best := INF
	var out := 1.0
	for bx in [-35.9, -20.7, -5.5, 9.7, 24.9, 40.1]:
		if absf(local_pickup.x - bx) < best:
			best = absf(local_pickup.x - bx)
			out = 1.0 if local_pickup.x < bx else -1.0
	return out


func _look(eye_local: Vector3, target_local: Vector3) -> void:
	var eye: Vector3 = ship.global_transform * eye_local
	var to: Vector3 = ship.global_transform * target_local - eye
	pl.respawn(eye - Vector3(0, Player.EYE_STAND, 0), 0.0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	if pl.gun:
		pl.gun.set_viewmodel_visible(false)
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
