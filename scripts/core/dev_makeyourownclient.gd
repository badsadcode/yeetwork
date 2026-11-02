extends Node
## Developer check for "Make your own versions" over the network, run on a client joining a
## Make Your Own Workshop host: the oil drums (a PropType) arrive as oil drums, with their
## model and weight, and the thorn bed trap has its own model; the glass cabinets' and the shed
## door's parts are there to build their pieces from; the host's own gun (the Scrap gun) is
## what the client sees it carry. Exits 1 if a step fails.
## Usage (host first): godot -- --host --map res://custom/make_your_own/workshop.tscn --bots 0 --port 24812 --gun scrap_gun
##                     godot -- --join 127.0.0.1 --port 24812 --tour x --tour-mode makeyourownclient

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("MAKE YOUR OWN CLIENT CHECK FAILED (timed out)")
		get_tree().quit(1))
	var drums := []
	for k in 40:
		await get_tree().create_timer(0.25).timeout
		drums = world.props.values().filter(func(p): return p.ptype != null and p.ptype.display_name == "Oil drum")
		if drums.size() >= 4:
			break
	var d: Prop = drums[0] if not drums.is_empty() else null
	var model: bool = d != null and d.find_children("Drum", "", true, false).size() > 0
	_check("a client sees your own props (oil drums) with their model and numbers", drums.size() == 4 and model and is_equal_approx(d.mass, 60.0), "%d, model %s" % [drums.size(), model])
	var thorns: TrapSpot = null
	for n in world.arena.puzzle:
		if n is TrapSpot and (n as TrapSpot).trap_name != "":
			thorns = n
	_check("... and your own trap", thorns != null and thorns.find_children("Thorns", "", true, false).size() > 0, "")
	# What breaks into its parts: a client builds each part (a prop) from the same model.
	var cabs: Array = world.props.values().filter(func(p): return p.ptype != null and p.ptype.breaks_into_parts)
	var path: String = cabs[0].ptype.resource_path if not cabs.is_empty() else ""
	var handle := Prop.model_part(world, {"ptype": path, "part": 7})
	_check("... glass cabinets, and their parts to fly apart into", cabs.size() == 2 and PropType.parts_of(path).size() == 8 and not handle.is_empty() and handle[2] == "metal", "%d cabinets" % cabs.size())
	var shed: ModelDestructible = null
	for md in world.arena.destructibles:
		if md is ModelDestructible and (md as ModelDestructible).tear_off:
			shed = md
	var plank := Prop.model_part(world, {"mwall": shed.wall_id, "part": 0}) if shed else []
	_check("... the shed door tears off (its parts to build the torn-off door from)", shed != null and not plank.is_empty() and plank[2] == "wood", "")
	# A model playing its own animation: the windmill's sails turn here too.
	var mill: AnimatedModel = null
	for n in world.arena.puzzle:
		if n is AnimatedModel and String(n.name) == "Windmill":
			mill = n
	var sails := mill._inst.find_child("Sails", true, false) as Node3D if mill and mill._inst else null
	var x0 := sails.global_basis.x if sails else Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	_check("... the windmill (an AnimatedModel) turns for a client too", sails != null and sails.global_basis.x.angle_to(x0) > 0.2, "")
	# The host carries the Scrap gun (--gun): so it is for the client, its own actions and all.
	var host: Player = world.get_player(1)
	_check("... a player's own gun (the host's Scrap gun), seen by the client", host != null and host.gun_model == "scrap_gun" and host.gun._anim_players.size() == 1,
		"gun %s" % (host.gun_model if host else "no host"))
	print("MAKE YOUR OWN CLIENT CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1
