extends Node
## Developer check for "Make your own versions" over the network, run on a client joining a
## Make Your Own Workshop host: the oil drums (a PropType) arrive as oil drums, with their
## model and weight, and the thorn bed trap has its own model. Exits 1 if a step fails.
## Usage (host first): godot -- --host --map res://custom/make_your_own/workshop.tscn --bots 0 --port 24812
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
		drums = world.props.values().filter(func(p): return p.ptype != null)
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
	print("MAKE YOUR OWN CLIENT CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1
