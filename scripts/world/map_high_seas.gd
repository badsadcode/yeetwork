class_name MapHighSeas
extends RefCounted
## "High Seas": the container ship MV Bad Decisions on the open ocean. The whole map rides
## the ship (Arena.carrier), which heaves, pitches and rolls on the sculpted ocean's swell.
## Phase 1: hull, deck, container stacks with aisles, the stern superstructure (bridge),
## the raised bow, ramps and pads, loose cargo that slides when the deck tilts.
## Phase 2 (around the ship): overboard isn't the end (the sea is swimmable, ladders on the
## hull lead back aboard); the bridge is a room with breakable windows and the ship's horn,
## reached by ladders through hatches in its wings; lashing bridges with ladders span the
## gaps between the container bays. The engine room below deck, built from Fixtures; a deck
## crane forward sweeping its swinging load over the stacks.
## Red team at the bow, Blue at the stern.
## Local space: origin on the waterline amidships, bow toward +X, starboard toward +Z.

const DECK := 8.0 # main deck height above the waterline
const FORE := 10.5 # forecastle deck at the bow
const HULL_DARK := Color(0.12, 0.17, 0.3)
const HULL_RED := Color(0.62, 0.12, 0.1)
const DECK_COL := Color(0.36, 0.48, 0.44)
const WHITE := Color(0.92, 0.93, 0.95)
const STEEL := Color(0.5, 0.56, 0.64)
const CONTAINER_COLORS := [
	Color(0.12, 0.38, 0.75), Color(0.78, 0.16, 0.12), Color(0.95, 0.55, 0.1), Color(0.2, 0.58, 0.3),
	Color(0.95, 0.8, 0.15), Color(0.55, 0.58, 0.62), Color(0.1, 0.55, 0.6), Color(0.62, 0.22, 0.45),
]
const CONT := Vector3(12.2, 2.6, 2.44) # a 40 ft container
## The engine room below deck, under the superstructure: x, its half-width, floor and ceiling.
const ROOM_X := Vector2(-63.5, -44.0)
const ROOM_Z := 9.0
const ROOM_FLOOR := 1.5
const ROOM_TOP := 7.4
## Its two hatches in the deck (XZ), by Blue's base, with ladders down.
const HATCHES := [Rect2(-45.6, 5.7, 1.6, 1.6), Rect2(-45.6, -7.3, 1.6, 1.6)]

static var _cont_mats := {}


## Variants (map keys): the sea state and the sky.
const VARIANTS := {
	"highseas": ["ocean", "tropical", Vector3(-38, -60, 0)],
	"highseas_dusk": ["calm", "sunset", Vector3(-12, -110, 0)],
	"highseas_storm": ["stormy", "storm", Vector3(-55, -40, 0)],
	"highseas_extreme": ["extreme", "storm", Vector3(-62, -25, 0)],
}


static func build(a: Arena, key := "highseas") -> void:
	a.kill_y = -25.0
	Liquid.style = "sculpted" # the ship rides the sculpted ocean's swell
	var v: Array = VARIANTS.get(key, VARIANTS.highseas)
	var sea: String = Game.sea_override if Game.sea_override in Liquid.SCULPTED else v[0]
	var ocean := Liquid.create_ocean(0.0, sea)
	ocean.swimmable = true # (overboard: swim to a ladder and climb back aboard)
	a.add_child(ocean)
	var settings := MapSettings.new()
	settings.ocean = true
	settings.ocean_level = 0.0
	settings.sun_rotation_degrees = v[2]
	a.environment_preset(v[1], settings)
	settings.free()
	var ship := Ship.new()
	ship.name = "Ship"
	ship.ocean = ocean
	ship.sea = sea
	if sea == "extreme":
		ship.max_roll = deg_to_rad(20.0) # (a hurricane throws her about)
	ship.world = a.world
	a.add_child(ship)
	a.carrier = ship
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_hull(ship)
	_superstructure(a, ship)
	_engine_room(a, ship)
	_containers(ship, rng)
	_crane(a, ship)
	_bow(a, ship)
	_hull_ladders(a, ship)
	_gameplay(a, ship)
	_cargo(a, rng)
	# Bots coming off the forecastle go round by its ramps (its back edge is a 2.5 m drop).
	a.avoid_rects.append(Rect2(Vector2(59.0, -7.5), Vector2(2.0, 15.0)))
	for h: Rect2 in HATCHES: # (and round the engine room's hatches)
		a.avoid_rects.append(h)


# --- Helpers (everything is a child of the ship) --------------------------------------

static func _box(ship: Ship, center: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY, solid := true, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.transform = Transform3D(basis, center)
	mi.material_override = mat if mat else Mats.world(color, 0.7)
	ship.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.transform = mi.transform
		ship.add_child(cs)
	return mi


## A flat slab over x0..x1, z0..z1 (y0..y1) with rectangular holes (XZ): boxes round them.
static func _slab(ship: Ship, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, holes: Array, color: Color) -> void:
	var xs := [x0, x1]
	var zs := [z0, z1]
	for h: Rect2 in holes:
		xs.append_array([h.position.x, h.end.x])
		zs.append_array([h.position.y, h.end.y])
	xs.sort()
	zs.sort()
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		if xb - xa < 0.001:
			continue
		# Runs of solid cells along z in this column, one box each.
		var start := NAN
		for j in zs.size():
			var solid := false
			if j < zs.size() - 1:
				if float(zs[j + 1]) - float(zs[j]) < 0.001:
					continue # (a zero-width cell: the run goes on)
				var mid := Vector2((xa + xb) * 0.5, (float(zs[j]) + float(zs[j + 1])) * 0.5)
				solid = not holes.any(func(h: Rect2) -> bool: return h.has_point(mid))
			if solid and is_nan(start):
				start = zs[j]
			elif not solid and not is_nan(start):
				var zb: float = zs[j]
				_box(ship, Vector3((xa + xb) * 0.5, (y0 + y1) * 0.5, (start + zb) * 0.5), Vector3(xb - xa, y1 - y0, zb - start), color)
				start = NAN


## A slab whose top runs from `from` to `to` (ship-local), like Arena.ramp.
static func _ramp(ship: Ship, from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var dir := to - from
	var x := dir.normalized()
	var side := x.cross(Vector3.UP).normalized()
	var y := side.cross(x).normalized()
	var basis := Basis(x, y, x.cross(y))
	_box(ship, (from + to) * 0.5 - y * 0.25, Vector3(dir.length(), 0.5, width), color, basis)


## A vertical prism from an XZ outline (convex), y0..y1: bow and stern ends of the hull.
static func _prism(ship: Ship, outline: PackedVector2Array, y0: float, y1: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var a0 := Vector3(a.x, y0, a.y)
		var b0 := Vector3(b.x, y0, b.y)
		var a1 := Vector3(a.x, y1, a.y)
		var b1 := Vector3(b.x, y1, b.y)
		for v in [a0, b1, b0, a0, a1, b1]:
			st.add_vertex(v)
		pts.append(a0)
		pts.append(a1)
	for i in range(1, n - 1): # top and bottom fans
		for v in [Vector3(outline[0].x, y1, outline[0].y), Vector3(outline[i + 1].x, y1, outline[i + 1].y), Vector3(outline[i].x, y1, outline[i].y)]:
			st.add_vertex(v)
		for v in [Vector3(outline[0].x, y0, outline[0].y), Vector3(outline[i].x, y0, outline[i].y), Vector3(outline[i + 1].x, y0, outline[i + 1].y)]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.world(color, 0.7)
	ship.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	cs.shape = sh
	ship.add_child(cs)


static func _pad(ship: Ship, pos: Vector3, velocity: Vector3) -> void:
	var t := TriggerVolume.new()
	t.position = pos + Vector3(0, 0.6, 0)
	ship.add_child(t)
	t.setup(TriggerVolume.Kind.JUMP_PAD, Vector3(2.4, 1.2, 2.4), velocity)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 1.3
	cm.height = 0.2
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.1, 0)
	mi.material_override = Mats.glow(Arena.C_PAD, 2.5)
	ship.add_child(mi)
	var arrow := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = 0.5
	am.height = 0.6
	arrow.mesh = am
	arrow.position = pos + Vector3(0, 0.6, 0)
	arrow.material_override = Mats.glow(Arena.C_PAD.lightened(0.4), 3.0)
	ship.add_child(arrow)


## A ladder from `bottom` up to `top_y` against a wall, climbed on its `out` side (ship-local
## directions). At the top it carries you `over` (ladder-local: x along it, y up, z out).
static func _ladder(a: Arena, ship: Ship, bottom: Vector3, top_y: float, out: Vector3, over: Vector3, from_sea := true) -> void:
	var h := top_y - bottom.y
	var side := Vector3.UP.cross(out).normalized()
	var basis := Basis(side, Vector3.UP, out)
	var yellow := Mats.plastic(Color(0.95, 0.75, 0.15), 0.4)
	for s in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.07, h, 0.07)
		rail.mesh = rm
		rail.transform = Transform3D(basis, bottom + basis * Vector3(s * 0.25, h * 0.5, 0.1))
		rail.material_override = yellow
		ship.add_child(rail)
	var rungs := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rung := BoxMesh.new()
	rung.size = Vector3(0.5, 0.05, 0.05)
	mm.mesh = rung
	mm.instance_count = int(h / 0.35)
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(basis, bottom + basis * Vector3(0, 0.25 + i * 0.35, 0.1)))
	rungs.multimesh = mm
	rungs.material_override = yellow
	ship.add_child(rungs)
	var t := TriggerVolume.new()
	t.transform = Transform3D(basis, bottom + basis * Vector3(0, h * 0.5, 0.5))
	ship.add_child(t)
	t.setup(TriggerVolume.Kind.LADDER, Vector3(1.5, h, 1.0), over)
	# Where a swimming bot heads for (just off its foot), and how tall it is.
	var foot := Node3D.new()
	foot.position = bottom + out * 0.8
	foot.set_meta("height", h)
	foot.set_meta("into", -out) # (which way you face to climb it)
	ship.add_child(foot)
	if from_sea:
		a.ladders.append(foot)
	else:
		ship.hold_ladders.append(foot)


## Ladders up the hull out of the sea, on both sides and at the stern (over the rail at the top).
static func _hull_ladders(a: Arena, ship: Ship) -> void:
	for x in [-40.0, -10.0, 20.0, 46.0]:
		for s in [-1, 1]:
			_ladder(a, ship, Vector3(x, -1.8, s * 16.02), DECK + 1.5, Vector3(0, 0, s), Vector3(0, 3.0, -6.0))
	_ladder(a, ship, Vector3(-72.02, -1.8, 0.0), DECK + 1.5, Vector3(-1, 0, 0), Vector3(0, 3.0, -6.0))


## A breakable glass pane (ship-local), `size` across (local x) by high, facing `normal`.
static func _glass(a: Arena, ship: Ship, center: Vector3, normal: Vector3, size: Vector2) -> void:
	var along := Vector3.UP.cross(normal).normalized()
	var d := Destructible.new()
	d.transform = Transform3D(Basis(along, Vector3.UP, normal), center)
	ship.add_child(d)
	d.setup(a.destructibles.size(), size, 0.08, Color(0.72, 0.86, 0.95), ["bottom", "top"], "glass")
	a.destructibles.append(d)


static func _light(ship: Ship, pos: Vector3, color: Color, range_m: float, energy := 2.0, attenuation := 1.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_m
	l.omni_attenuation = attenuation
	l.light_energy = energy
	ship.add_child(l)


## A team's glowing flag pedestal on deck (like Arena.flag_stand, but riding the ship).
static func _flag_stand(a: Arena, ship: Ship, team: int, stand: Vector3) -> void:
	var tc := Game.team_color(team)
	a.flag_stands[team] = stand + Vector3(0, 0.4, 0)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.6
	cm.height = 0.4
	ped.mesh = cm
	ped.position = stand + Vector3(0, 0.2, 0)
	ped.material_override = Mats.glow(tc, 2.0)
	ship.add_child(ped)
	_light(ship, stand + Vector3(0, 3, 0), tc, 10.0, 2.5)


static func container_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _cont_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://scripts/world/container.gdshader")
		m.set_shader_parameter("paint", color)
		m.set_shader_parameter("half_size", CONT * 0.5)
		_cont_mats[key] = m
	return _cont_mats[key]


# --- The ship ---------------------------------------------------------------------------

static func _hull(ship: Ship) -> void:
	# Main hull: red antifouling below the waterline, dark blue above, a white line.
	_box(ship, Vector3(-3, -4.5, 0), Vector3(126, 9, 32), HULL_RED)
	# (The hull tops stop 10 cm under the deck plating: two surfaces at one height flicker.)
	# (y 0..7.9 on top of the red, round the engine room: ahead of it, behind it, under it,
	# beside it, and its ceiling with the hatches)
	var rx0 := ROOM_X.x
	var rx1 := ROOM_X.y
	var rc := (rx0 + rx1) * 0.5
	var rl := rx1 - rx0
	_box(ship, Vector3((-66.0 + rx0) * 0.5, 3.95, 0), Vector3(rx0 + 66.0, 7.9, 32), HULL_DARK)
	_box(ship, Vector3((rx1 + 60.0) * 0.5, 3.95, 0), Vector3(60.0 - rx1, 7.9, 32), HULL_DARK)
	_box(ship, Vector3(rc, ROOM_FLOOR * 0.5, 0), Vector3(rl, ROOM_FLOOR, 32), HULL_DARK)
	for s in [-1, 1]:
		_box(ship, Vector3(rc, (ROOM_FLOOR + 7.9) * 0.5, s * (ROOM_Z + 16.0) * 0.5), Vector3(rl, 7.9 - ROOM_FLOOR, 16.0 - ROOM_Z), HULL_DARK)
	_slab(ship, rx0, rx1, -ROOM_Z, ROOM_Z, ROOM_TOP, 7.9, HATCHES, HULL_DARK)
	_box(ship, Vector3(-3, 0.6, 0), Vector3(126.1, 0.35, 32.1), WHITE, Basis.IDENTITY, false)
	# Deck surface (slightly proud of the hull top, green deck paint).
	_slab(ship, -66.0, 60.0, -15.6, 15.6, DECK - 0.1, DECK, HATCHES, DECK_COL)
	# Stern: rounded transom.
	_prism(ship, PackedVector2Array([Vector2(-66, -16), Vector2(-70, -14), Vector2(-72, -9), Vector2(-72, 9), Vector2(-70, 14), Vector2(-66, 16)]), -6.0, DECK - 0.1, HULL_DARK)
	_box(ship, Vector3(-69, DECK - 0.05, 0), Vector3(5.9, 0.1, 17.5), DECK_COL)
	# Bulwarks: low steel walls along both sides (falling overboard needs a push or a jump).
	for s in [-1, 1]:
		_box(ship, Vector3(-3, DECK + 0.55, s * 15.8), Vector3(126, 1.1, 0.4), STEEL)
		_box(ship, Vector3(-3, DECK + 1.15, s * 15.8), Vector3(126, 0.12, 0.6), WHITE, Basis.IDENTITY, false)
	_box(ship, Vector3(-71.8, DECK + 0.55, 0), Vector3(0.4, 1.1, 18), STEEL)


static func _bow(a: Arena, ship: Ship) -> void:
	var outline := PackedVector2Array([Vector2(60, -16), Vector2(68, -13), Vector2(75, -7), Vector2(78, 0), Vector2(75, 7), Vector2(68, 13), Vector2(60, 16)])
	_prism(ship, outline, -9.0, FORE - 0.1, HULL_DARK)
	_box(ship, Vector3(69, FORE - 0.05, 0), Vector3(16, 0.1, 22), DECK_COL)
	# Bulwark around the forecastle.
	for i in outline.size() - 1:
		var p0 := Vector3(outline[i].x, FORE + 0.55, outline[i].y)
		var p1 := Vector3(outline[i + 1].x, FORE + 0.55, outline[i + 1].y)
		var mid := (p0 + p1) * 0.5
		var dir := p1 - p0
		var basis := Basis(Vector3.UP, -atan2(dir.z, dir.x))
		_box(ship, mid, Vector3(dir.length(), 1.1, 0.4), STEEL, basis)
	# Stairs-ramps up to the forecastle on both sides, and the front of it as a wall.
	for s in [-1, 1]:
		_ramp(ship, Vector3(52, DECK, s * 9.5), Vector3(60, FORE, s * 9.5), 4.0, STEEL)
	# Anchor windlasses and a mast (cover and landmarks).
	for s in [-1, 1]:
		_box(ship, Vector3(70, FORE + 0.8, s * 4.5), Vector3(2.4, 1.6, 1.8), Color(0.3, 0.32, 0.36))
		_box(ship, Vector3(70, FORE + 1.0, s * 3.2), Vector3(1.0, 1.0, 1.0), HULL_RED)
	_box(ship, Vector3(64, FORE + 6.0, 0), Vector3(0.6, 12.0, 0.6), WHITE)
	_light(ship, Vector3(64, FORE + 12.2, 0), Color(1.0, 0.95, 0.8), 18.0, 1.5)
	_flag_stand(a, ship, Game.TEAM_RED, Vector3(70, FORE, 0))


static func _superstructure(a: Arena, ship: Ship) -> void:
	# Accommodation block at the stern: x -64..-50, five decks high, the bridge on top.
	_box(ship, Vector3(-57, DECK + 9.0, 0), Vector3(14, 18, 22), WHITE)
	# Window bands on every deck.
	for lvl in 5:
		var y := DECK + 2.0 + lvl * 3.4
		_box(ship, Vector3(-49.96, y, 0), Vector3(0.1, 1.0, 19), Color(0.15, 0.22, 0.32), Basis.IDENTITY, false)
	_bridge(a, ship)
	# Funnel with the company stripe.
	_box(ship, Vector3(-62, DECK + 24, 0), Vector3(4, 10, 6), Color(0.15, 0.15, 0.18))
	_box(ship, Vector3(-62, DECK + 25, 0), Vector3(4.05, 2.0, 6.05), Color(0.95, 0.55, 0.1), Basis.IDENTITY, false)
	# Balcony in front of the third deck, reached by a ramp on the starboard side.
	var balc := DECK + 6.0
	_box(ship, Vector3(-47.75, balc - 0.2, 0), Vector3(4.5, 0.4, 30), STEEL)
	_box(ship, Vector3(-45.6, balc + 0.55, 0), Vector3(0.2, 1.1, 24), WHITE)
	_ramp(ship, Vector3(-36.0, DECK, 13.8), Vector3(-45.5, balc, 13.8), 3.0, STEEL)
	# Pads: balcony to the bridge roof, deck to the balcony (port side).
	_pad(ship, Vector3(-47.75, balc, -6.0), Vector3(-5.5, 15.5, 0.0))
	_pad(ship, Vector3(-44.0, DECK, -12.0), Vector3(-2.2, 12.5, 5.0))
	_light(ship, Vector3(-47, DECK + 4.0, 0), Color(1.0, 0.85, 0.6), 14.0, 1.5)
	_light(ship, Vector3(-55, DECK + 23.0, 0), Color(0.6, 0.85, 1.0), 12.0, 1.0)
	_flag_stand(a, ship, Game.TEAM_BLUE, Vector3(-46.5, DECK, 0))


## The wheelhouse on top (DECK+18..21), with bridge wings spanning the full beam: a room
## you can get into. Big windows of breakable glass look forward over the cargo; the ship's
## horn stands at the console. In each wing a hatch in the floor, with a ladder from the main
## deck below, is the way in (the roof is still reached by the balcony's pad).
static func _bridge(a: Arena, ship: Ship) -> void:
	var floor_y := DECK + 18.0
	# Floor (its top 5 cm over the block's, no flicker), with a hatch in each wing.
	_box(ship, Vector3(-55, floor_y - 0.1, 0), Vector3(10, 0.3, 27.2), WHITE)
	for s in [-1, 1]:
		_box(ship, Vector3(-58, floor_y - 0.1, s * 14.8), Vector3(4, 0.3, 2.4), WHITE)
		_box(ship, Vector3(-52.3, floor_y - 0.1, s * 14.8), Vector3(4.6, 0.3, 2.4), WHITE)
		_box(ship, Vector3(-55.3, floor_y - 0.1, s * 15.8), Vector3(1.4, 0.3, 0.4), WHITE)
	# Walls: back and sides solid; the front a sill, posts and a lintel round the glass.
	_box(ship, Vector3(-59.8, floor_y + 1.5, 0), Vector3(0.4, 3.0, 32), WHITE)
	for s in [-1, 1]:
		_box(ship, Vector3(-55, floor_y + 1.5, s * 15.8), Vector3(10, 3.0, 0.4), WHITE)
		_box(ship, Vector3(-50.2, floor_y + 1.75, s * 14.6), Vector3(0.4, 1.5, 2.0), WHITE)
	_box(ship, Vector3(-50.2, floor_y + 0.5, 0), Vector3(0.4, 1.0, 32), WHITE)
	_box(ship, Vector3(-50.2, floor_y + 2.75, 0), Vector3(0.4, 0.5, 32), WHITE)
	_box(ship, Vector3(-55, DECK + 21.1, 0), Vector3(10.6, 0.2, 32.6), Color(0.25, 0.28, 0.32))
	# Four panes looking forward.
	for k in 4:
		_glass(a, ship, Vector3(-50.2, floor_y + 1.75, -10.2 + k * 6.8), Vector3(1, 0, 0), Vector2(6.8, 1.5))
	# The console under the windows, the horn's lever on it, a light.
	_box(ship, Vector3(-51.2, floor_y + 0.45, 0), Vector3(1.2, 0.9, 6.0), Color(0.22, 0.24, 0.28))
	_box(ship, Vector3(-51.25, floor_y + 0.92, 0), Vector3(1.0, 0.04, 5.6), Color(0.1, 0.45, 0.4), Basis.IDENTITY, false)
	var horn := ShipHorn.new()
	horn.position = Vector3(-51.4, floor_y + 0.9, 2.0)
	ship.add_child(horn)
	horn.world = a.world
	horn.puzzle_index = a.puzzle.size()
	a.puzzle.append(horn)
	_light(ship, Vector3(-55, floor_y + 2.6, 0), Color(1.0, 0.92, 0.75), 12.0, 1.2)
	# Ladders from the main deck up through the hatches (climbed facing outboard).
	for s in [-1, 1]:
		_ladder(a, ship, Vector3(-55.3, DECK, s * 15.3), floor_y + 1.2, Vector3(0, 0, -s), Vector3(-5.0, 2.0, 0.0))


## The engine room below deck (ROOM_X, under the superstructure), built from Fixtures: the
## main engine thumping (it shakes the room), two generators, pumps, pipes (one leaks steam
## that scalds), ventilation fans, a switchboard that zaps whoever leans on it, a radio left
## on. Down the two hatches by Blue's base, ladders back up. The sea stays out of it however
## far she heels (Liquid.dry_box), and bots knocked down a hatch climb back out.
static func _engine_room(a: Arena, ship: Ship) -> void:
	var f := ROOM_FLOOR
	var rx0 := ROOM_X.x
	var rx1 := ROOM_X.y
	var rc := (rx0 + rx1) * 0.5
	var rl := rx1 - rx0
	var h := ROOM_TOP - f
	ship.hold = AABB(Vector3(rx0, f - 1.0, -ROOM_Z), Vector3(rl, DECK - f + 1.0, ROOM_Z * 2.0))
	ship.ocean.dry_node = ship
	ship.ocean.dry_box = ship.hold
	# Inside: steel plating on the floor, pale green-grey walls (just in front of the hull's).
	var plate := Color(0.46, 0.48, 0.48)
	var wall := Color(0.55, 0.62, 0.58)
	_box(ship, Vector3(rc, f + 0.03, 0), Vector3(rl, 0.06, ROOM_Z * 2.0), plate, Basis.IDENTITY, false)
	for s in [-1, 1]:
		_box(ship, Vector3(rc, f + h * 0.5, s * (ROOM_Z - 0.03)), Vector3(rl, h, 0.06), wall, Basis.IDENTITY, false)
		_box(ship, Vector3(rc, f + 0.4, s * (ROOM_Z - 0.06)), Vector3(rl, 0.8, 0.02), Color(0.2, 0.3, 0.26), Basis.IDENTITY, false)
	for x in [rx0 + 0.03, rx1 - 0.03]:
		_box(ship, Vector3(x, f + h * 0.5, 0), Vector3(0.06, h, ROOM_Z * 2.0), wall, Basis.IDENTITY, false)
	# The hatches: yellow edges round them on deck, ladders down the forward wall.
	var yellow := Color(0.95, 0.75, 0.15)
	for r: Rect2 in HATCHES:
		var c := r.get_center()
		_box(ship, Vector3(c.x, DECK + 0.01, r.position.y), Vector3(r.size.x + 0.3, 0.02, 0.15), yellow, Basis.IDENTITY, false)
		_box(ship, Vector3(c.x, DECK + 0.01, r.end.y), Vector3(r.size.x + 0.3, 0.02, 0.15), yellow, Basis.IDENTITY, false)
		_box(ship, Vector3(r.position.x, DECK + 0.01, c.y), Vector3(0.15, 0.02, r.size.y), yellow, Basis.IDENTITY, false)
		_ladder(a, ship, Vector3(rx1, f, c.y), DECK + 1.2, Vector3(-1, 0, 0), Vector3(0.0, 3.0, -3.0), false)
	# Caged lamps down the ceiling (none forward of x -50: their light would reach through the
	# deck onto the first bay's containers).
	var lamp := Mats.plastic(Color(1.0, 0.9, 0.7), 0.4, 3.0)
	for x in [-60.0, -55.0, -50.0]:
		for z in [-4.5, 4.5]:
			_box(ship, Vector3(x, ROOM_TOP - 0.12, z), Vector3(1.2, 0.16, 0.3), Color(0.2, 0.2, 0.22), Basis.IDENTITY, false)
			_box(ship, Vector3(x, ROOM_TOP - 0.24, z), Vector3(1.0, 0.1, 0.18), Color.WHITE, Basis.IDENTITY, false, lamp)
		_light(ship, Vector3(x, ROOM_TOP - 0.5, 0), Color(1.0, 0.88, 0.68), 8.0, 5.0, 0.6)
	# The main engine down the middle (its collision the ship's: fixtures on her aren't solid).
	_fixture(a, ship, "engine", Vector3(-54.5, f, 0), 0.0, Vector3.ONE * 1.8, {"volume_db": 6.0, "reach": 34.0, "breakable": true, "repair_time": 30.0})
	_solid(ship, Vector3(-54.5, f + 1.3, 0), Vector3(5.8, 2.6, 2.9))
	# Generators aft, the switchboard between them (a radio on it), pumps and pipes along the
	# sides, fans high on the walls.
	var creak: Array[String] = ["creak"]
	for s in [-1, 1]:
		_fixture(a, ship, "generator", Vector3(-61.0, f, s * 5.0), PI * 0.5, Vector3.ONE * 1.2, {"breakable": true, "pitch": 0.9 + s * 0.05})
		_solid(ship, Vector3(-61.0, f + 0.66, s * 5.0), Vector3(1.25, 1.32, 2.1))
		_fixture(a, ship, "pump", Vector3(-48.5, f, s * 8.0), 0.0, Vector3.ONE, {"pitch": 0.8, "one_shot_sounds": creak})
		_solid(ship, Vector3(-48.5, f + 0.75, s * 8.0), Vector3(1.0, 1.5, 1.0))
		_fixture(a, ship, "pipes", Vector3(-57.0, f, s * 8.5), PI * 0.5, Vector3.ONE * 1.6, {"volume_db": -8.0, "reach": 10.0})
		_fixture(a, ship, "fan", Vector3(-51.5, f + 4.0, s * 8.7), 0.0 if s < 0 else PI, Vector3.ONE, {"volume_db": -6.0, "reach": 12.0})
	_fixture(a, ship, "box", Vector3(-63.2, f, 0), 0.0, Vector3(0.6, 2.0, 3.2), {"sound": "buzz", "effect": "sparks", "effect_rate": 0.5,
		"hazard": "electric", "hazard_radius": 0.9, "light_energy": 0.8, "light_color": Color(1.0, 0.3, 0.2), "light_pulse": 1.2,
		"breakable": true, "volume_db": -4.0, "reach": 10.0})
	_solid(ship, Vector3(-63.2, f + 1.0, 0), Vector3(0.6, 2.0, 3.2))
	_fixture(a, ship, "radio", Vector3(-63.2, f + 2.0, 1.0), PI * 0.5, Vector3.ONE, {"volume_db": -8.0, "reach": 8.0})
	# A leaking joint by the port pump: steam that scalds.
	_fixture(a, ship, "pipes", Vector3(-46.5, f, -8.6), PI * 0.5, Vector3.ONE, {"hazard": "hot", "hazard_radius": 0.7, "effect_rate": 1.6, "volume_db": -4.0, "reach": 9.0})


## The deck crane forward of the last bay (ShipCrane): its jib sweeps over the forward stacks,
## the container hanging from it swinging as she rolls (ride it; it sweeps you off the tops).
## Its machinery house on the pedestal hums and creaks.
static func _crane(a: Arena, ship: Ship) -> void:
	var at := Vector3(49.5, DECK, 0)
	var crane := ShipCrane.new()
	crane.ship = ship
	crane.position = at
	ship.add_child(crane)
	_solid(ship, at + Vector3(0, crane.height * 0.5, 0), Vector3(2.0, crane.height, 2.0))
	var creak: Array[String] = ["creak", "metal"]
	_fixture(a, ship, "box", at + Vector3(-0.2, crane.height - 1.6, 0), 0.0, Vector3(2.6, 1.6, 2.4), {"sound": "engine",
		"pitch": 1.6, "volume_db": -6.0, "reach": 24.0, "one_shot_sounds": creak, "one_shot_every": Vector2(3.0, 8.0)})


## A Fixture on the ship (ship-local), registered with the map's puzzle pieces.
static func _fixture(a: Arena, ship: Ship, kind: String, pos: Vector3, yaw: float, scale: Vector3, props: Dictionary) -> Fixture:
	var fx := Fixture.new()
	fx.kind = kind
	fx.solid = false # (a StaticBody wouldn't ride the ship: _solid gives it the ship's collision)
	for k in props:
		fx.set(k, props[k])
	fx.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), pos)
	ship.add_child(fx)
	fx.world = a.world
	fx.puzzle_index = a.puzzle.size()
	a.puzzle.append(fx)
	return fx


## Collision on the ship (ship-local box) with nothing drawn: a fixture's bulk.
static func _solid(ship: Ship, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = center
	ship.add_child(cs)


## Six bays of container stacks (1-3 high) between the superstructure and the bow, with
## side walkways, a centre aisle through alternate bays and 3 m gaps between bays.
static func _containers(ship: Ship, rng: RandomNumberGenerator) -> void:
	var a := ship.get_parent() as Arena
	var bay_x := [-35.9, -20.7, -5.5, 9.7, 24.9, 40.1]
	var opened := 0
	var lashed_n := 0
	var rows := []
	for r in 10:
		rows.append(-11.25 + r * 2.5)
	var pads_at := []
	for b in bay_x.size():
		var bx: float = bay_x[b]
		for r in rows.size():
			var z: float = rows[r]
			var aisle := (b % 2 == 0) and absf(z) < 2.0
			var h := 0 if aisle else rng.randi_range(1, 3)
			if rng.randf() < 0.08 and not aisle:
				h = 0 # an empty slot here and there: a hideout in the stack
			if h == 0:
				continue
			# A few stand open on the deck (a hideout, some with a pickup inside); a few top
			# containers up high are lashed down in a way that can give (they can break loose).
			if h == 1 and absf(z) > 3.0 and opened < 4 and rng.randf() < 0.35:
				_open_container(a, ship, Vector3(bx, DECK, z), CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()], b % 2 == 0, opened < 2)
				opened += 1
				continue
			var lashed := h >= 2 and lashed_n < 8 and rng.randf() < 0.22
			if lashed:
				lashed_n += 1
			for k in h:
				var c: Color = CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()]
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = CONT
				mi.mesh = bm
				mi.position = Vector3(bx, DECK + CONT.y * (k + 0.5), z)
				if rng.randf() < 0.5:
					mi.rotation.y = PI # doors at the other end
				mi.material_override = container_material(c)
				ship.add_child(mi)
				if k == h - 1 and lashed:
					_lash(a, ship, mi, c)
			# One collision box per stack (a lashed top container has its own).
			var solid := h - 1 if lashed else h
			if solid > 0:
				var cs := CollisionShape3D.new()
				var sh := BoxShape3D.new()
				sh.size = Vector3(CONT.x, CONT.y * solid, CONT.z)
				cs.shape = sh
				cs.position = Vector3(bx, DECK + CONT.y * solid * 0.5, z)
				ship.add_child(cs)
		# Steel ramps up onto the first tier from the bay gaps, and a pad to the top.
		if b % 2 == 1:
			_ramp(ship, Vector3(bx - 6.1 - 3.0 + 0.2, DECK, 13.0), Vector3(bx - 6.1 + 0.4, DECK + CONT.y, 13.0), 2.6, STEEL)
		pads_at.append(Vector3(bx + 7.6, DECK, 6.0 * (1 if b % 2 == 0 else -1)))
	for p: Vector3 in pads_at:
		_pad(ship, p, Vector3(0.0, 14.0, -signf(p.z) * 1.2))
	_lashing_bridges(ship, bay_x, pads_at)


## A top container held by lashings that can give (World: explosions, pushes, lightning and a
## storm's rolling wear them down; it creaks, then breaks loose as a sliding prop). Its own
## collision; the rods are yellow X braces on its ends.
static func _lash(a: Arena, ship: Ship, mi: MeshInstance3D, color: Color) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = CONT
	cs.shape = sh
	cs.transform = mi.transform
	ship.add_child(cs)
	var rods := Node3D.new()
	rods.transform = mi.transform
	ship.add_child(rods)
	var yellow := Mats.plastic(Color(0.95, 0.75, 0.15), 0.4)
	for ex in [-1, 1]:
		for d in [-1, 1]:
			var rod := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.05, 3.3, 0.05)
			rod.mesh = rm
			rod.material_override = yellow
			rod.position = Vector3(ex * (CONT.x * 0.5 + 0.06), -0.4, 0)
			rod.rotation.x = d * 0.6
			rods.add_child(rod)
	a.lashed.append([mi, cs, rods, mi.transform, color])


## A container standing open on the deck: hollow, doors swung wide at one end (toward the
## bay gap), a warm lamp inside; `pickup`: a pickup waits in it.
static func _open_container(a: Arena, ship: Ship, at: Vector3, color: Color, door_aft: bool, pickup: bool) -> void:
	var paint := Mats.world(color, 0.6)
	var inner := Mats.world(color.darkened(0.2), 0.8)
	var hx := CONT.x * 0.5
	var hz := CONT.z * 0.5
	var y := at.y + CONT.y * 0.5
	var dir := -1.0 if door_aft else 1.0 # (which end is open)
	# Roof, two long sides and the closed end (outer paint, the inside darker).
	_box(ship, Vector3(at.x, at.y + CONT.y - 0.05, at.z), Vector3(CONT.x, 0.1, CONT.z), color, Basis.IDENTITY, true, paint)
	for s in [-1, 1]:
		_box(ship, Vector3(at.x, y, at.z + s * (hz - 0.05)), Vector3(CONT.x, CONT.y, 0.1), color, Basis.IDENTITY, true, paint)
		_box(ship, Vector3(at.x, y, at.z + s * (hz - 0.12)), Vector3(CONT.x - 0.2, CONT.y - 0.2, 0.02), color, Basis.IDENTITY, false, inner)
	_box(ship, Vector3(at.x - dir * (hx - 0.05), y, at.z), Vector3(0.1, CONT.y, CONT.z), color, Basis.IDENTITY, true, paint)
	_box(ship, Vector3(at.x, at.y + 0.03, at.z), Vector3(CONT.x - 0.2, 0.06, CONT.z - 0.2), color, Basis.IDENTITY, false, Mats.world(Color(0.3, 0.26, 0.22), 0.9))
	# The doors, swung out flat against the next stacks' ends.
	for s in [-1, 1]:
		var hinge := Vector3(at.x + dir * hx, y, at.z + s * hz)
		_box(ship, hinge + Vector3(dir * 0.1, 0, s * 0.62), Vector3(0.08, CONT.y - 0.1, 1.2), color, Basis(Vector3.UP, s * dir * 1.75), false, paint)
	_light(ship, Vector3(at.x - dir * 2.0, at.y + CONT.y - 0.4, at.z), Color(1.0, 0.82, 0.6), 10.0, 1.8)
	if pickup:
		var ps := PickupSpawn.new()
		ps.kind = "random"
		ps.position = Vector3(at.x - dir * 4.0, at.y, at.z)
		ps.set_meta("doorway", Vector3(at.x + dir * hx, at.y, at.z)) # (ship-local: where it opens)
		ship.add_child(ps)
		a.pickups.append(ps)


## Lashing bridges: steel walkways across the gaps between bays, two containers up, with
## ladders from the side walkways (on the side without the gap's ramp). They leave the
## gap's jump pad clear.
static func _lashing_bridges(ship: Ship, bay_x: Array, pads_at: Array) -> void:
	var a := ship.get_parent() as Arena
	var y := DECK + CONT.y * 2.0
	for g in bay_x.size() - 1:
		var gx: float = (float(bay_x[g]) + float(bay_x[g + 1])) * 0.5
		var pad: Vector3 = pads_at[g]
		# Two spans either side of the pad's column.
		var gap0 := pad.z - 1.7
		var gap1 := pad.z + 1.7
		for span in [[-12.6, gap0], [gap1, 12.6]]:
			var z0: float = span[0]
			var z1: float = span[1]
			if z1 - z0 < 1.0:
				continue
			_box(ship, Vector3(gx, y - 0.15, (z0 + z1) * 0.5), Vector3(1.8, 0.3, z1 - z0), STEEL)
			for rx in [-0.85, 0.85]: # (thin rails along its edges)
				_box(ship, Vector3(gx + rx, y + 0.5, (z0 + z1) * 0.5), Vector3(0.06, 1.0, z1 - z0), Color(0.95, 0.75, 0.15), Basis.IDENTITY, false)
		# Ladders up from the side walkways (gaps 0, 2, 4 have a ramp on the starboard side).
		var sides := [-1] if g % 2 == 0 else [-1, 1]
		for s in sides:
			_ladder(a, ship, Vector3(gx, DECK, s * 13.1), y + 1.2, Vector3(0, 0, s), Vector3(0.0, 2.0, -5.0))


static func _gameplay(a: Arena, _ship: Ship) -> void:
	# Spawns (ship-local; Arena converts them when used).
	for z in [-6.0, -2.0, 2.0, 6.0]:
		a.spawn_points[Game.TEAM_RED].append(Vector3(66, FORE + 0.2, z))
	a.spawn_points[Game.TEAM_RED].append(Vector3(72, FORE + 0.2, 0))
	for z in [-9.0, -4.0, 4.0, 9.0]:
		a.spawn_points[Game.TEAM_BLUE].append(Vector3(-45.5, DECK + 0.2, z))
	a.spawn_points[Game.TEAM_BLUE].append(Vector3(-47.75, DECK + 6.2, 4.0))
	for x in [-33.0, -14.0, 6.0, 18.0, 27.5, 48.0]:
		for z in [-14.0, 14.0]:
			a.spawn_points[0].append(Vector3(x, DECK + 0.2, z))


## Loose cargo on the walkways and in the aisles: it slides and rolls when the deck tilts.
static func _cargo(a: Arena, rng: RandomNumberGenerator) -> void:
	var lying := Basis(Vector3.RIGHT, PI * 0.5) # barrels on their side roll across the deck
	var list := [
		["barrel", Vector3(-26, DECK + 0.5, -13.5), lying], ["barrel", Vector3(-24.5, DECK + 0.5, -13.5), lying],
		["barrel", Vector3(6, DECK + 0.5, 13.5), lying], ["boom_barrel", Vector3(20, DECK + 0.7, -14.0), Basis.IDENTITY],
		["boom_barrel", Vector3(-12, DECK + 0.7, 14.0), Basis.IDENTITY], ["barrel", Vector3(32, DECK + 0.5, 0.0), lying],
		["crate", Vector3(-30, DECK + 0.6, 14.0), Basis.IDENTITY], ["crate", Vector3(-30, DECK + 1.6, 14.0), Basis.IDENTITY],
		["crate", Vector3(13, DECK + 0.6, -14.2), Basis.IDENTITY], ["crate_big", Vector3(46, DECK + 0.9, 13.0), Basis.IDENTITY],
		["crate", Vector3(-6, DECK + 0.6, 0.0), Basis.IDENTITY], ["crate", Vector3(25, DECK + 0.6, 0.0), Basis.IDENTITY],
		["ball", Vector3(0, DECK + 0.5, -14.0), Basis.IDENTITY], ["ball", Vector3(28, DECK + 0.5, 14.0), Basis.IDENTITY],
		["beachball", Vector3(-38, DECK + 0.6, 0.0), Basis.IDENTITY], ["tire", Vector3(40, DECK + 0.4, -13.5), Basis.IDENTITY],
		["plank", Vector3(-18, DECK + 0.3, 13.8), Basis.IDENTITY], ["anvil", Vector3(55, DECK + 0.3, -12.0), Basis.IDENTITY],
		["couch", Vector3(-46, DECK + 6.6, -10.0), Basis.IDENTITY], ["cone", Vector3(55, DECK + 0.4, 12.0), Basis.IDENTITY],
		["crate", Vector3(68, FORE + 0.6, 9.0), Basis.IDENTITY], ["barrel", Vector3(66, FORE + 0.5, -9.0), lying],
	]
	for e in list:
		var b: Basis = e[2]
		b = Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)) * b
		a.initial_props.append([e[0], Transform3D(b, e[1])])
