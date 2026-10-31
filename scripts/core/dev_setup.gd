extends Node
## Developer check for the match setup's rules, run on the Fortress as a deathmatch (Sandbox):
## which maps suit which modes (CTF needs flag stands, the sports their goals, hoops or net,
## Puzzle a puzzle level; the rest any map but a puzzle level), the host's MegaYeet rules
## reaching the Heart, and a mode's unused pieces out of sight (no Heart, rifts, zones or
## traps in a deathmatch on a fortress). Exits 1 if a step fails.
## Usage: godot -- --host --map res://maps/fortress.tscn --bots 0 --tour x --tour-mode setup

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	var fits := func(mode: int, key: String) -> bool:
		return Game.mode_fits(mode, Game.map_info(key))
	var M := Game.Mode
	_check("CTF: maps with two flag stands (Prime, High Seas), not the sports or the Fortress", fits.call(M.CTF, "prime") and fits.call(M.CTF, "highseas") and not fits.call(M.CTF, "res://maps/yeetball_stadium.tscn") and not fits.call(M.CTF, "res://maps/fortress.tscn"), "")
	_check("the sports: only their own courts", fits.call(M.YEETBALL, "res://maps/yeetball_stadium.tscn") and not fits.call(M.YEETBALL, "prime") and fits.call(M.HOOPS, "res://maps/hoops_court.tscn") and not fits.call(M.HOOPS, "res://maps/yeetball_stadium.tscn") and fits.call(M.VOLLEY, "res://maps/volley_beach.tscn"), "")
	_check("Puzzle: only puzzle levels", fits.call(M.PUZZLE, "res://maps/pump_house.tscn") and not fits.call(M.PUZZLE, "prime"), "")
	_check("Sandbox: any map (puzzle levels too); MegaYeet: any but a puzzle level", fits.call(M.SANDBOX, "res://maps/pump_house.tscn") and fits.call(M.SANDBOX, "highseas") and fits.call(M.MEGAYEET, "prime") and fits.call(M.MEGAYEET, "res://maps/fortress.tscn") and not fits.call(M.MEGAYEET, "res://maps/pump_house.tscn"), "")
	var h := FortressHeart.new()
	ModeMegaYeet.apply_rules(h, {"custom": false, "health": 50.0})
	var kept := h.health == 1000.0
	ModeMegaYeet.apply_rules(h, {"custom": true, "health": 2500.0, "bite": 12.0, "boss_every": 3, "max_monsters": 90})
	_check("the host's MegaYeet rules reach the Heart (the map's own unless Custom)", kept and h.health == 2500.0 and h.bite == 12.0 and h.boss_every == 3 and h.max_monsters == 90, "")
	h.free()
	var shown := []
	_visible_pieces(world.arena, shown)
	_check("a deathmatch on the Fortress: no Heart, rifts, zones or traps", world.mode == M.SANDBOX and shown.is_empty() and world.horde == null, "showing %s" % [shown])
	print("SETUP CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _visible_pieces(n: Node, out: Array) -> void:
	for c in n.get_children():
		if (c is FortressHeart or c is DefenseZone or c is MonsterSpawn or c is TrapSpot) and (c as Node3D).is_visible_in_tree():
			out.append(c.name)
		_visible_pieces(c, out)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1
