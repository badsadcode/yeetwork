extends Node
## Developer check for MegaYeet over the network, run on a client joining a MegaYeet host:
## the monsters show up here (the snapshots arrive), move, and the HUD's state (the Fortress
## meter, the wave) comes through; a death reaches us too. Exits 1 if a step fails.
## Usage (host first): godot -- --host --map res://maps/fortress.tscn --mode megayeet --bots 2 --port 24781
##                     godot -- --join 127.0.0.1 --port 24781 --tour x --tour-mode megayeetclient

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(80.0).timeout.connect(func():
		print("MEGAYEET CLIENT CHECK FAILED (timed out)")
		get_tree().quit(1))
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
