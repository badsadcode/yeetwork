class_name MapHighSeas
extends RefCounted
## "High Seas": the container ship MV Bad Decisions on the open ocean. The whole map rides
## the ship (Arena.carrier), which heaves, pitches and rolls on the sculpted ocean's swell.
## Phase 1: hull, deck, container stacks with aisles, the stern superstructure (bridge),
## the raised bow, ramps and pads, loose cargo that slides when the deck tilts.
## Red team at the bow, Blue at the stern. Falling overboard: the ocean.
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

static var _cont_mats := {}


static func build(a: Arena) -> void:
	a.kill_y = -25.0
	Liquid.style = "sculpted" # the ship rides the sculpted ocean's swell
	var sea := Game.sea_override if Game.sea_override in Liquid.SCULPTED else "ocean"
	var ocean := Liquid.create_ocean(0.0, sea)
	a.add_child(ocean)
	var settings := MapSettings.new()
	settings.ocean = true
	settings.ocean_level = 0.0
	settings.sun_rotation_degrees = Vector3(-38, -60, 0)
	a.environment_preset("tropical", settings)
	settings.free()
	var ship := Ship.new()
	ship.name = "Ship"
	ship.ocean = ocean
	ship.world = a.world
	a.add_child(ship)
	a.carrier = ship
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_hull(ship)
	_superstructure(a, ship)
	_containers(ship, rng)
	_bow(a, ship)
	_gameplay(a, ship)
	_cargo(a, rng)


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


static func _light(ship: Ship, pos: Vector3, color: Color, range_m: float, energy := 2.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_m
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


static func _container_mat(color: Color) -> ShaderMaterial:
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
	_box(ship, Vector3(-3, 3.75, 0), Vector3(126, 8.5, 32), HULL_DARK)
	_box(ship, Vector3(-3, 0.6, 0), Vector3(126.1, 0.35, 32.1), WHITE, Basis.IDENTITY, false)
	# Deck surface (slightly proud of the hull top, green deck paint).
	_box(ship, Vector3(-3, DECK - 0.05, 0), Vector3(126, 0.1, 31.2), DECK_COL)
	# Stern: rounded transom.
	_prism(ship, PackedVector2Array([Vector2(-66, -16), Vector2(-70, -14), Vector2(-72, -9), Vector2(-72, 9), Vector2(-70, 14), Vector2(-66, 16)]), -6.0, DECK, HULL_DARK)
	# Bulwarks: low steel walls along both sides (falling overboard needs a push or a jump).
	for s in [-1, 1]:
		_box(ship, Vector3(-3, DECK + 0.55, s * 15.8), Vector3(126, 1.1, 0.4), STEEL)
		_box(ship, Vector3(-3, DECK + 1.15, s * 15.8), Vector3(126, 0.12, 0.6), WHITE, Basis.IDENTITY, false)
	_box(ship, Vector3(-71.8, DECK + 0.55, 0), Vector3(0.4, 1.1, 18), STEEL)


static func _bow(a: Arena, ship: Ship) -> void:
	var outline := PackedVector2Array([Vector2(60, -16), Vector2(68, -13), Vector2(75, -7), Vector2(78, 0), Vector2(75, 7), Vector2(68, 13), Vector2(60, 16)])
	_prism(ship, outline, -9.0, FORE, HULL_DARK)
	_box(ship, Vector3(69, FORE - 0.05, 0), Vector3(16, 0.1, 22), DECK_COL, Basis.IDENTITY, false)
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
	# The wheelhouse with bridge wings spanning the full beam.
	_box(ship, Vector3(-55, DECK + 19.5, 0), Vector3(10, 3, 32), WHITE)
	_box(ship, Vector3(-49.96, DECK + 19.8, 0), Vector3(0.1, 1.6, 30), Color(0.2, 0.35, 0.5), Basis.IDENTITY, false)
	_box(ship, Vector3(-55, DECK + 21.1, 0), Vector3(10.6, 0.2, 32.6), Color(0.25, 0.28, 0.32))
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


## Six bays of container stacks (1-3 high) between the superstructure and the bow, with
## side walkways, a centre aisle through alternate bays and 3 m gaps between bays.
static func _containers(ship: Ship, rng: RandomNumberGenerator) -> void:
	var bay_x := [-35.9, -20.7, -5.5, 9.7, 24.9, 40.1]
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
			for k in h:
				var c: Color = CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()]
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = CONT
				mi.mesh = bm
				mi.position = Vector3(bx, DECK + CONT.y * (k + 0.5), z)
				if rng.randf() < 0.5:
					mi.rotation.y = PI # doors at the other end
				mi.material_override = _container_mat(c)
				ship.add_child(mi)
			# One collision box per stack.
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(CONT.x, CONT.y * h, CONT.z)
			cs.shape = sh
			cs.position = Vector3(bx, DECK + CONT.y * h * 0.5, z)
			ship.add_child(cs)
		# Steel ramps up onto the first tier from the bay gaps, and a pad to the top.
		if b % 2 == 1:
			_ramp(ship, Vector3(bx - 6.1 - 3.0 + 0.2, DECK, 13.0), Vector3(bx - 6.1 + 0.4, DECK + CONT.y, 13.0), 2.6, STEEL)
		pads_at.append(Vector3(bx + 7.6, DECK, 6.0 * (1 if b % 2 == 0 else -1)))
	for p: Vector3 in pads_at:
		_pad(ship, p, Vector3(0.0, 14.0, -signf(p.z) * 1.2))


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
