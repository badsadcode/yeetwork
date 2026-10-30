extends Node
## Developer tool: saves a code-built map (Prime, Facing) as a Map Kit scene, so it can be
## edited in the editor. The builders in Arena tag what they make; this walks the arena and
## writes Map Kit nodes (ArenaBlock, BreakableSlab, JumpPadNode, LiftPlatform, FlagStand,
## HazardVolume, SpawnPoint, PropSpawn), lights, glow strips and the remaining decoration.
## Usage: godot -- --host --map prime --map-source code --bots 0 --tour x --tour-mode export_maps
## Writes res://maps/<key>.tscn (overwrites it: tweaks made in the editor would be lost).

const NAMES := {"prime": ["Prime", "Yeetwork Prime", "sunset",
		"The original arena: a walled 90s arena around a pit of bouncy acid, a central tower with a ring of dodgeballs, team halls and side lanes."],
	"facing": ["Facing", "Facing Yeets", "space",
		"Two towers facing each other on an asteroid strip in space: a central hill, launch shafts, a sniper floor and a roof full of anvils."]}

var world: Node
var out_dir := ""
var _root: Node3D
var _groups := {}
var _counts := {}


func _ready() -> void:
	await get_tree().create_timer(0.3).timeout
	var arena: Arena = world.arena
	var key: String = world.map_key
	if not NAMES.has(key):
		push_error("export_maps: only prime and facing are built in code (got %s)" % key)
		get_tree().quit(1)
		return
	var info: Array = NAMES[key]
	_root = Node3D.new()
	_root.name = info[0]
	var ms := MapSettings.new()
	ms.name = "MapSettings"
	ms.map_name = info[1]
	ms.author = "Yeetwork"
	ms.description = info[3]
	ms.sky = info[2]
	ms.kill_height = arena.kill_y
	ms.avoid_areas.assign(arena.avoid_rects)
	ms.playtest_mode = 1
	_root.add_child(ms)
	for g in ["Geometry", "Breakables", "Gameplay", "Spawns", "Props", "Lights", "Decor"]:
		var n := Node3D.new()
		n.name = g
		_root.add_child(n)
		_groups[g] = n
	for c in arena.get_children():
		_convert(c, arena)
	for team in arena.flag_stands:
		var f := FlagStand.new()
		f.team = 0 if team == 1 else 1
		f.position = arena.flag_stands[team] - Vector3(0, 0.4, 0)
		_add("Gameplay", f, "Flag" + ("Red" if team == 1 else "Blue"))
	for team in [0, 1, 2]:
		for p: Vector3 in arena.spawn_points[team]:
			var sp := SpawnPoint.new()
			sp.team = team
			sp.position = p - Vector3(0, 0.2, 0)
			_add("Spawns", sp, ["Spawn", "SpawnRed", "SpawnBlue"][team])
	for e: Array in arena.initial_props:
		var ps := PropSpawn.new()
		ps.kind = e[0]
		ps.transform = e[1]
		_add("Props", ps, String(e[0]).capitalize().replace(" ", ""))
	_own(_root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, Arena.MAPKIT_SCENES[key])
	print("EXPORT %s -> %s: %s (%s)" % [key, Arena.MAPKIT_SCENES[key], error_string(err), _counts])
	get_tree().quit(0 if err == OK else 1)


func _convert(c: Node, arena: Arena) -> void:
	if c.has_meta("mk_part") or c is WorldEnvironment or c is DirectionalLight3D or String(c.name).begins_with("Backdrop") \
			or c is Clouds or c is Weather or c is Rain or (c is Liquid and not c.has_meta("mk")) or c is CPUParticles3D:
		return # made by the Map Kit node, or by MapSettings' sky
	if c.has_meta("mk"):
		var m: Dictionary = c.get_meta("mk")
		match m.type:
			"block":
				var b := ArenaBlock.new()
				b.transform = (c as Node3D).transform
				b.size = m.size
				b.color = m.color
				b.emission = m.emission
				_add("Geometry", b, "Block")
			"glow":
				_add("Decor", _copy(c), "Glow")
			"slab":
				var s := BreakableSlab.new()
				s.transform = (c as Node3D).transform
				s.size = m.size
				s.thickness = m.thickness
				s.material = m.material
				s.color = m.color
				s.hp_scale = m.hp_scale
				s.anchor_bottom = m.anchors.has("bottom")
				s.anchor_top = m.anchors.has("top")
				s.anchor_left = m.anchors.has("left")
				s.anchor_right = m.anchors.has("right")
				_add("Breakables", s, "Slab")
			"pad":
				var j := JumpPadNode.new()
				j.position = m.pos
				j.velocity_override = m.velocity
				j.target = Vector3(m.velocity.x, 0, m.velocity.z) * 0.6 # (the editor's arc follows the velocity)
				_add("Gameplay", j, "JumpPad")
			"lift":
				var l := LiftPlatform.new()
				l.position = m.a
				l.travel = m.b - m.a
				l.period = m.period
				l.phase = m.phase
				l.size = m.size
				_add("Gameplay", l, "Lift")
			"flag":
				pass # FlagStands come from arena.flag_stands
			"hazard":
				var h := HazardVolume.new()
				h.transform = m.xf
				h.kind = m.kind
				h.size = m.size
				h.damage = m.damage
				h.wind = m.wind
				h.fire_color = m.fire_color
				_add("Gameplay", h, String(m.kind).capitalize())
		return
	if c is OmniLight3D:
		_add("Lights", _copy(c), "Light")
	elif arena._spinners.has(c):
		var sp := Spinner.new()
		sp.transform = (c as Node3D).transform
		for k in c.get_children():
			sp.add_child(_copy(k))
		_add("Decor", sp, "Spinner")
	elif c is Node3D:
		_add("Decor", _copy(c), c.get_class())


func _copy(n: Node) -> Node:
	var d := n.duplicate()
	for k in d.get_meta_list():
		d.remove_meta(k)
	return d


func _add(group: String, n: Node, base: String) -> void:
	_counts[group] = _counts.get(group, 0) + 1
	n.name = "%s%d" % [base, _counts[group]]
	(_groups[group] as Node).add_child(n)


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = _root
		if c.scene_file_path == "":
			_own(c)
