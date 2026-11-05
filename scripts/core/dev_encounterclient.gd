extends Node
## Developer check for Encounter over the network, on a client (dev_encounter --with-client on the
## host). The first: the host walks in; the rifts open here, monsters are drawn here, the HUD says
## how many; everyone down: back alive here, the monsters gone, the rifts shut; it starts again.
## The second joins with the fight on: the rifts open, monsters there; the host wins: the door
## opens here, the rifts shut, the HUD clear. Exits 1 if a step fails.
## Usage (host first): godot -- --host --map res://adventures/the_cellar.adventure.tres --mode adventure --port 24796 --spooky off --tour x --tour-mode encounter --with-client
##                     godot -- --join 127.0.0.1 --port 24796 --tour x --tour-mode encounterclient

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(80.0).timeout.connect(func():
		print("ENCOUNTER CLIENT CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _until(func(): return world.local_player != null and world.horde != null, 10.0)
	await _wait(0.5)
	var horde: Horde = world.horde
	var fight: Encounter = _named("Fight")
	var rift: MonsterSpawn = _rift()
	_check("a level with a fight: monsters to draw here too", horde != null, "")
	if int(world.mode_state.get("fight", -1)) < 0:
		await _first(horde, fight, rift)
	else:
		await _late(horde, fight, rift)
	print("ENCOUNTER CLIENT CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _first(horde: Horde, fight: Encounter, rift: MonsterSpawn) -> void:
	await _until(func(): return rift.visible, 15.0)
	_check("the host walks in: the rifts open here", rift.visible, "")
	await _until(func(): return horde.count() >= 3, 8.0)
	_check("... the monsters are drawn here", horde.count() >= 3, "%d" % horde.count())
	await _wait(0.2)
	_check("... the HUD says how many", world.hud._objective.text.contains("left"), world.hud._objective.text)
	var pl: Player = world.local_player
	await _until(func(): return not pl.is_alive(), 12.0)
	_check("everyone falls: so do we", not pl.is_alive(), "")
	await _until(func(): return pl.is_alive() and not rift.visible, 6.0)
	await _wait(0.5)
	_check("... back alive here, the monsters gone, the rifts shut, not won", pl.is_alive() and horde.count() == 0 and not rift.visible and not fight.active, "%d monsters" % horde.count())
	await _until(func(): return rift.visible and horde.count() >= 1, 15.0)
	_check("it starts again: the rifts, the monsters", rift.visible and horde.count() >= 1, "")


func _late(horde: Horde, fight: Encounter, rift: MonsterSpawn) -> void:
	await _wait(0.5)
	_check("joining with a fight on: the rifts open", rift.visible, "")
	await _until(func(): return horde.count() >= 1, 3.0)
	_check("... the monsters there", horde.count() >= 1, "%d" % horde.count())
	await _until(func(): return fight.active, 25.0)
	await _wait(1.5)
	_check("the host wins: it's on here, the door opens, the rifts shut, the HUD clear", fight.active and _named("WayOn").active and not rift.visible and not world.hud._objective.text.contains("left"), world.hud._objective.text)


func _rift() -> MonsterSpawn:
	for s in world.arena.monster_spawns:
		if String(s.name) == "RiftNorth":
			return s
	return null


func _named(n: String) -> Variant:
	for p in world.arena.puzzle:
		if String(p.name) == n:
			return p
	return null


func _until(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return
		await get_tree().create_timer(0.1).timeout
		t += 0.1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1
