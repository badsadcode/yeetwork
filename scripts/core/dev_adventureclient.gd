extends Node
## Developer check for the Adventure mode over the network, on a client (dev_adventure
## --with-client on the host): joining in chapter 1, moving on with the host to chapter 2 in a new
## World, there with everyone, a door the host opens opening here, its own moves reaching the host;
## joining late, straight into chapter 2, that door open. Exits 1 if a step fails.
## Usage (host first): godot -- --host --map res://adventures/two_small_rooms.adventure.tres --mode adventure --port 24795 --tour x --tour-mode adventure --with-client
##                     godot -- --join 127.0.0.1 --port 24795 --tour x --tour-mode adventureclient

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("ADVENTURE CLIENT CHECK FAILED (timed out)")
		get_tree().quit(1))
	for k in 100:
		await get_tree().create_timer(0.1).timeout
		if world.local_player != null and not world.adventure_info.is_empty():
			break
	var first := world
	var chapter: int = world.adventure_info.get("chapter", -1)
	if chapter == 0:
		_check("a client joins in chapter 1: its map, its name", world.map_key.ends_with("room1.tscn") and world.adventure_info.title == "The Button", "%s" % [world.adventure_info])
		for k in 150:
			await get_tree().create_timer(0.1).timeout
			if world != first and world.local_player != null and world.players.size() >= 2:
				break
		_check("... and moves on with the host: a new World, chapter 2, both there", world != first and world.map_key.ends_with("room2.tscn") and world.adventure_info.get("chapter", -1) == 1 and world.players.size() >= 2 and world.local_player != null, "%s, %d players" % [world.map_key, world.players.size()])
		# Both ways over the new World: the host's crate opens a door here, our moves reach it.
		var door: PuzzleDoor = _door()
		for k in 60:
			await get_tree().create_timer(0.1).timeout
			if door and door.active:
				break
		_check("... the door the host opens opens here too", door != null and door.active, "")
		var pl: Player = world.local_player
		for k in 30:
			pl.global_position = Vector3(-5, 0.1, 6)
			await get_tree().create_timer(0.1).timeout
	else:
		var door: PuzzleDoor = _door()
		_check("a client joining late lands in chapter 2, its door already open", chapter == 1 and world.map_key.ends_with("room2.tscn") and world.players.size() >= 2 and door != null and door.active, "chapter %d, %s" % [chapter + 1, world.map_key])
	print("ADVENTURE CLIENT CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _door() -> PuzzleDoor:
	for n in world.arena.puzzle:
		if n is PuzzleDoor:
			return n
	return null


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1
