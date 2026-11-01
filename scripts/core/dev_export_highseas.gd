extends Node
## Developer tool: saves High Seas (built in code: MapHighSeas) as a Map Kit scene, so it can
## be edited in the editor like any map. The builder notes everything it makes while this runs
## (MapHighSeas.recording: main.gd turns it on for this tour), each in the ship's frame and
## under the part of the ship it belongs to; this writes the same things as Map Kit pieces under
## a Vessel: ArenaBlocks (boxes, decoration without collision, hidden bulk), CSG polygons (the
## hull's shaped ends), Ladders, BreakableSlabs (the bridge's glass), JumpPadNodes, CargoContainers
## (closed, lashed, open with a pickup), Fixtures (the engine room's machines, the crane's
## house), a Crane, a Horn, a ShipHold (the engine room), lights, flag stands, spawn points and
## the loose cargo; MapSettings for the sea and sky (the variants change those: Arena).
## Usage: godot -- --host --map highseas --map-source code --bots 0 --tour x --tour-mode export_highseas
## Writes res://maps/high_seas.tscn (overwrites it: tweaks made in the editor would be lost).

const OUT := "res://maps/high_seas.tscn"

var world: Node
var out_dir := ""
var _root: Node3D
var _ship: Vessel
var _groups := {}
var _counts := {}


func _ready() -> void:
	await get_tree().create_timer(0.3).timeout
	var arena: Arena = world.arena
	if not world.map_key.begins_with("highseas") or MapHighSeas.rec.is_empty():
		push_error("export_highseas: run it on High Seas built in code (--map highseas --map-source code)")
		get_tree().quit(1)
		return
	_root = Node3D.new()
	_root.name = "HighSeas"
	var ms := MapSettings.new()
	ms.name = "MapSettings"
	ms.map_name = "High Seas"
	ms.author = "Yeetwork"
	ms.description = "The container ship MV Bad Decisions on the open ocean: she rolls with the swell, cargo slides, the sea is swimmable."
	ms.sky = "tropical"
	ms.sun_rotation_degrees = MapHighSeas.VARIANTS.highseas[2]
	ms.kill_height = arena.kill_y
	ms.ocean = true
	ms.ocean_level = 0.0
	ms.ocean_preset = "ocean"
	ms.ocean_swimmable = true
	ms.avoid_areas.assign(arena.avoid_rects)
	ms.playtest_mode = 1
	_root.add_child(ms)
	_ship = Vessel.new()
	_ship.name = "MVBadDecisions"
	var ship := arena.carrier as Ship
	_ship.length = ship.length
	_ship.beam = ship.beam
	_ship.roll = ship.roll_gain
	_ship.max_roll_degrees = rad_to_deg(ship.max_roll) if world.map_key != "highseas_extreme" else 16.0
	_ship.max_pitch_degrees = rad_to_deg(ship.max_pitch)
	_ship.heave = ship.heave_gain
	_ship.lag = ship.lag
	_ship.high_seas_weather = true
	_root.add_child(_ship)
	for e: Dictionary in MapHighSeas.rec:
		_convert(e)
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
		_add("Cargo", ps, "Cargo")
	_own(_root, _root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("EXPORT HIGH SEAS %s: %d pieces -> %s" % ["OK" if err == OK else "FAILED " + error_string(err), MapHighSeas.rec.size(), OUT])
	_root.free()
	get_tree().quit(0 if err == OK else 1)


func _convert(e: Dictionary) -> void:
	var sec: String = e.section
	match e.t:
		"box":
			var b := ArenaBlock.new()
			b.size = e.size
			b.color = e.color
			b.solid = e.solid
			b.emission = e.emission
			b.transform = Transform3D(e.basis, e.center)
			_add(sec, b, "Block" if e.solid else "Trim")
		"solid":
			var b := ArenaBlock.new()
			b.size = e.size
			b.transform = Transform3D(Basis.IDENTITY, e.center)
			b.visible = false # (a machine's bulk: felt, not seen)
			_add(sec, b, "Bulk")
		"prism":
			var c := CSGPolygon3D.new()
			c.polygon = e.outline
			c.mode = CSGPolygon3D.MODE_DEPTH
			c.depth = float(e.y1) - float(e.y0)
			c.use_collision = true
			# (its outline in X and Z, extruded up from its bottom: the polygon's plane turned flat,
			# the extrusion (its -Z) pointing up)
			c.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, float(e.y0), 0))
			c.material = Mats.world(e.color, 0.7)
			_add(sec, c, "HullEnd")
		"pad":
			var p := JumpPadNode.new()
			p.position = e.pos
			p.velocity_override = e.velocity
			_add(sec, p, "JumpPad")
		"ladder":
			var l := Ladder.new()
			l.transform = Transform3D(e.basis, e.bottom)
			l.height = e.height
			l.top_throw = e.over
			_add(sec, l, "Ladder")
		"glass":
			var g := BreakableSlab.new()
			g.transform = Transform3D(e.basis, e.center)
			g.size = e.size
			g.thickness = 0.08
			g.material = "glass"
			g.color = Color(0.72, 0.86, 0.95)
			g.anchor_bottom = true
			g.anchor_top = true
			_add(sec, g, "Window")
		"light":
			var l := OmniLight3D.new()
			l.position = e.pos
			l.light_color = e.color
			l.omni_range = e.range
			l.light_energy = e.energy
			l.omni_attenuation = e.attenuation
			_add(sec, l, "Light")
		"flag":
			var f := FlagStand.new()
			f.team = 0 if e.team == Game.TEAM_RED else 1
			f.position = e.stand
			_add("Gameplay", f, "FlagRed" if e.team == Game.TEAM_RED else "FlagBlue")
		"horn":
			var h := Horn.new()
			h.position = e.pos
			_add(sec, h, "Horn")
		"crane":
			var c := Crane.new()
			c.position = e.pos
			c.height = e.height
			c.jib = e.jib
			c.cable = e.cable
			c.heading = rad_to_deg(e.heading)
			c.sweep = rad_to_deg(e.sweep)
			c.period = e.period
			c.load_size = e.load_size
			c.load_color = e.load_color
			_add(sec, c, "Crane")
		"fixture":
			var fx := Fixture.new()
			fx.kind = e.kind
			fx.solid = false # (on a ship its bulk is a hidden block: the ship's collision)
			for k in e.props:
				fx.set(k, e.props[k])
			fx.transform = e.xf
			_add(sec, fx, "Machine")
		"container":
			var c := CargoContainer.new()
			c.position = e.pos
			if e.flip:
				c.rotation.y = PI
			c.color = e.color
			c.lashed = e.lashed
			_add(sec, c, "Container")
		"open_container":
			var c := CargoContainer.new()
			c.position = e.pos
			c.color = e.color
			c.open = true
			c.doors_aft = e.door_aft
			c.pickup = e.pickup
			_add(sec, c, "OpenContainer")
		"hold":
			var box: AABB = e.box
			var h := ShipHold.new()
			h.position = Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
			h.size = box.size
			_add(sec, h, "Hold")
		_:
			push_warning("export_highseas: %s not converted" % e.t)


## Under the ship, in its part's group, with a numbered name.
func _add(group: String, n: Node, base: String) -> void:
	if not _groups.has(group):
		var g := Node3D.new()
		g.name = group
		_ship.add_child(g)
		_groups[group] = g
	var k := "%s/%s" % [group, base]
	_counts[k] = int(_counts.get(k, 0)) + 1
	n.name = "%s%d" % [base, _counts[k]]
	(_groups[group] as Node3D).add_child(n)


static func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)
