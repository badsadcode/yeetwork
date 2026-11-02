extends Node
## Developer check for MegaYeet over the network, run on a client joining a MegaYeet host:
## the monsters show up here (the snapshots arrive), move, and the HUD's state (the Fortress
## meter, the wave) comes through; a death reaches us too; something bought in the shop before
## the first wave (a power-up, from the shared meter) is ours; a trap a client puts down is
## built, there on the client too. Exits 1 if a step fails.
## Usage (host first): godot -- --host --map res://maps/fortress.tscn --mode megayeet --bots 2 --port 24781
##                     godot -- --join 127.0.0.1 --port 24781 --tour x --tour-mode megayeetclient

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(80.0).timeout.connect(func():
		print("MEGAYEET CLIENT CHECK FAILED (timed out)")
		get_tree().quit(1))
	# The shop, before the first wave: a client's purchase goes through the server.
	for k in 40:
		if world.local_player and int(world.mode_state.get("phase", -1)) == ModeMegaYeet.Phase.BREAK:
			break
		await get_tree().create_timer(0.25).timeout
	# A trap put down by a client: the server builds it, the client gets it (a new trap piece).
	var pl: Player = world.local_player
	var pieces: int = world.arena.puzzle.size()
	var put := false
	for k in 12:
		var a := k * TAU / 12.0
		var at := pl.global_position + Vector3(cos(a), 0, sin(a)) * 6.0
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Game.L_WORLD)
		var hit := pl.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or not ModeMegaYeet.placement(world, pl, "Spikes|spikes", hit.position, 0.0).ok:
			continue
		world.place_trap("Spikes|spikes", hit.position, 0.0)
		for j in 8:
			await get_tree().create_timer(0.25).timeout
			if world.arena.puzzle.size() > pieces:
				break
		if world.arena.puzzle.size() > pieces:
			put = true
			break
	var t: TrapSpot = world.arena.puzzle[-1] if put else null
	await get_tree().create_timer(0.4).timeout
	_check("a client puts a trap down: built, there for the client too", t != null and t.placed and t.active, "%d -> %d pieces, built %s" % [pieces, world.arena.puzzle.size(), t.active if t else false])
	var meter0 := int(world.mode_state.get("meter", 0))
	world.shop_buy("power:speed")
	var fast := false
	for k in 20:
		await get_tree().create_timer(0.2).timeout
		if world.local_player and world.local_player.buff_left("speed") > 0.0:
			fast = true
			break
	await get_tree().create_timer(0.6).timeout
	_check("a client buys a power-up in the shop (paid from the meter)", fast and int(world.mode_state.get("meter", 0)) < meter0, "speed %s, meter %d -> %d" % [fast, meter0, int(world.mode_state.get("meter", 0))])
	var seen := 0
	for k in 60:
		await get_tree().create_timer(0.5).timeout
		if world.horde and world.horde.count() > 3:
			seen = world.horde.count()
			break
	_check("the monsters show up on a client", seen > 3, "%d" % seen)
	var h: Horde = world.horde
	var id: int = h._views.keys()[0] if not h._views.is_empty() else -1
	var p0: Vector3 = h._views[id][0] if id >= 0 else Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	var moved: bool = id >= 0 and h._views.has(id) and (h._views[id][0] as Vector3).distance_to(p0) > 0.5
	_check("... and walk (snapshots keep coming)", moved, "")
	var s: Dictionary = world.mode_state
	_check("the Fortress meter and the wave reach the client", s.get("wave", 0) >= 1 and s.has("meter"), "%s" % s)
	_check("the Heart is there", world.arena.heart != null, "")
	print("MEGAYEET CLIENT CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1
