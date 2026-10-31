extends Node
## Developer check for map themes (MapTheme): the example garden's theme reaches its pieces
## and props (a mushroom jump pad, hay bales for crates, a tree stump flag stand), a piece's
## own model wins over the theme, a theme model hides the built-in look but keeps collision,
## named moving parts are taken from the model (a seesaw's "Plank"), pickups take the
## theme's items. Exits 1 if a step fails.
## Usage: godot -- --host --map res://custom/example_garden/example_garden.tscn --mode sandbox --bots 0 --port 24700 --tour <dir> --tour-mode themes

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("THEME CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(0.8)
	var arena = world.arena
	var theme: MapTheme = arena.map_settings.theme if arena.map_settings else null
	_check("the map has a theme", theme != null and theme.crate != null, "%s" % theme)
	# The jump pad (built by the arena) and the flag stand: the theme's models.
	_check("jump pads take the theme's model", _find_named(arena, "MushroomPad") != null, "")
	_check("flag stands take the theme's model", _find_named(arena, "TreeStump") != null, "")
	# Crates: the hay bale, still a 1 m box to collide with.
	var crate: Prop = null
	for p in world.props.values():
		if is_instance_valid(p) and p.kind == "crate":
			crate = p
			break
	var hay := _find_named(crate, "HayBale") if crate else null
	var shape: CollisionShape3D = null
	if crate:
		for c in crate.get_children():
			if c is CollisionShape3D:
				shape = c
	_check("crates look like the theme's, collide the same", hay != null and hay.visible and shape != null and (shape.shape as BoxShape3D).size.is_equal_approx(Vector3.ONE), "")
	# A piece made here: the theme's model in, the built-in look hidden, collision kept.
	theme.beacon = load("res://custom/example_garden/hay_bale.tscn")
	var beacon := Beacon.new()
	_map_root(arena).add_child(beacon) # (inside the map: the theme is found up the tree)
	await _wait(0.1)
	var b_model := _find_named(beacon, "HayBale")
	var hidden := 0
	var shown := 0
	for m in _meshes(beacon._parts):
		if b_model and (m == b_model or b_model.is_ancestor_of(m)):
			continue
		if m.visible:
			shown += 1
		else:
			hidden += 1
	var body := _find_class(beacon, "StaticBody3D")
	_check("a theme model replaces the built-in look, collision stays", b_model != null and hidden > 0 and shown == 0 and body != null, "hidden %d, shown %d" % [hidden, shown])
	# Its own model wins over the theme.
	beacon.model = load("res://custom/example_garden/tree_stump.tscn")
	await _wait(0.1)
	_check("a piece's own model wins over the theme", _find_named(beacon, "TreeStump") != null and _find_named(beacon, "HayBale") == null, "")
	beacon.queue_free()
	theme.beacon = null
	# A seesaw whose model has a "Plank": the plank tips with the seesaw.
	var scene := _plank_scene()
	theme.seesaw = scene
	var see := Seesaw.new()
	_map_root(arena).add_child(see)
	see._rebuild()
	await _wait(0.1)
	var plank := _find_named(see, "Plank")
	_check("named parts go where they move (a seesaw's Plank)", plank != null and see._body.is_ancestor_of(plank), "")
	see.queue_free()
	theme.seesaw = null
	# Pickups: the theme's item for its kind.
	theme.pickup_health = load("res://custom/example_garden/hay_bale.tscn")
	var pk := PickupSpawn.new()
	pk.kind = "health"
	_map_root(arena).add_child(pk)
	await _wait(0.1)
	_check("pickups take the theme's item", _find_named(pk, "HayBale") != null, "")
	pk.queue_free()
	theme.pickup_health = null
	_look(Vector3(10, 3.0, 3.0), Vector3(5.5, 0.5, -2.5))
	await _wait(0.6)
	_shot("t01_garden_theme")
	print("THEME CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _plank_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Seesaw"
	var plank := MeshInstance3D.new()
	plank.name = "Plank"
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 0.3, 1.5)
	plank.mesh = bm
	root.add_child(plank)
	plank.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## The map scene's root under the arena (where MapSettings is).
func _map_root(arena: Node) -> Node:
	for c in arena.get_children():
		if MapTheme._find_settings(c) or c is MapSettings:
			return c
	return arena


func _find_named(n: Node, nm: String) -> Node3D:
	if n == null:
		return null
	return n.find_child(nm, true, false) as Node3D


func _find_class(n: Node, cls: String) -> Node:
	for c in n.get_children(true):
		if c.is_class(cls):
			return c
		var f := _find_class(c, cls)
		if f:
			return f
	return null


func _meshes(n: Node, out: Array = []) -> Array:
	for c in n.get_children(true):
		if c is MeshInstance3D:
			out.append(c)
		_meshes(c, out)
	return out


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _look(eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var pl: Player = world.local_player
	var to := target - eye
	pl.respawn(eye - Vector3(0, Player.EYE_STAND, 0), 0.0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
