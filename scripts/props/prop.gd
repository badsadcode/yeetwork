class_name Prop
extends RigidBody3D
## A networked physics object. Simulated on the server; clients receive snapshots and
## move a frozen kinematic copy toward them.

const DEFS := {
	"crate": {"shape": "box", "size": Vector3(1, 1, 1), "mass": 25.0, "color": Color(0.95, 0.62, 0.25), "bounce": 0.15, "label": "Crate", "fragile": 9000.0, "breaks_into": "boards"},
	"crate_big": {"shape": "box", "size": Vector3(1.7, 1.7, 1.7), "mass": 70.0, "color": Color(0.85, 0.5, 0.2), "bounce": 0.1, "label": "Big Crate", "fragile": 26000.0, "breaks_into": "boards"},
	"barrel": {"shape": "cyl", "size": Vector3(0.42, 1.15, 0.42), "mass": 40.0, "color": Color(0.2, 0.6, 1.0), "bounce": 0.2, "label": "Barrel", "fragile": 15000.0, "breaks_into": "staves"},
	"boom_barrel": {"shape": "cyl", "size": Vector3(0.42, 1.15, 0.42), "mass": 35.0, "color": Color(1.0, 0.18, 0.15), "bounce": 0.2, "label": "Boom Barrel", "explosive": true},
	"ball": {"shape": "sphere", "size": Vector3(0.36, 0.36, 0.36), "mass": 4.0, "color": Color(1.0, 0.3, 0.55), "bounce": 0.75, "label": "Dodgeball"},
	"beachball": {"shape": "sphere", "size": Vector3(0.95, 0.95, 0.95), "mass": 2.0, "color": Color(1.0, 0.92, 0.25), "bounce": 0.85, "label": "Beach Ball", "damp": 0.6},
	"anvil": {"shape": "box", "size": Vector3(0.55, 0.5, 1.0), "mass": 300.0, "color": Color(0.25, 0.27, 0.32), "bounce": 0.0, "label": "Anvil", "metal": true},
	"plank": {"shape": "box", "size": Vector3(3.2, 0.16, 0.55), "mass": 15.0, "color": Color(0.8, 0.6, 0.38), "bounce": 0.1, "label": "Plank", "fragile": 5000.0, "breaks_into": "split"},
	"couch": {"shape": "couch", "size": Vector3(2.0, 0.9, 0.95), "mass": 60.0, "color": Color(0.6, 0.35, 0.95), "bounce": 0.25, "label": "Couch"},
	"tire": {"shape": "cyl", "size": Vector3(0.6, 0.38, 0.6), "mass": 20.0, "color": Color(0.12, 0.12, 0.14), "bounce": 0.8, "label": "Tire"},
	"cone": {"shape": "cone", "size": Vector3(0.3, 0.8, 0.3), "mass": 3.0, "color": Color(1.0, 0.5, 0.1), "bounce": 0.3, "label": "Cone"},
	"debris": {"shape": "box", "size": Vector3(1, 1, 1), "mass": 30.0, "color": Color(0.7, 0.7, 0.7), "bounce": 0.05, "label": "Debris"},
	# Halloween. "fragile": impact energy (J) that breaks the prop; "outline" props shatter
	# into fragments of their own shape.
	"pumpkin": {"shape": "pumpkin", "size": Vector3(0.46, 0.4, 0.46), "mass": 8.0, "color": Color(1.0, 0.5, 0.08), "bounce": 0.25, "label": "Jack-o'-Lantern", "fragile": 1800.0},
	"pumpkin_gold": {"shape": "pumpkin", "size": Vector3(0.62, 0.52, 0.62), "mass": 14.0, "color": Color(1.0, 0.8, 0.2), "bounce": 0.25, "label": "Golden Pumpkin", "fragile": 3200.0, "metal": true},
	"gravestone": {"shape": "outline", "size": Vector3(0.8, 1.1, 0.25), "mass": 60.0, "color": Color(0.55, 0.56, 0.62), "bounce": 0.05, "label": "Gravestone", "fragile": 7000.0, "shatter": "concrete"},
	"coffin": {"shape": "outline", "size": Vector3(0.9, 1.8, 0.45), "mass": 40.0, "color": Color(0.45, 0.28, 0.2), "bounce": 0.1, "label": "Coffin", "fragile": 4500.0, "shatter": "wood"},
	"candy": {"shape": "candy", "size": Vector3(0.12, 0.12, 0.3), "mass": 0.4, "color": Color(1, 0.4, 0.7), "bounce": 0.5, "label": "Candy"},
	"shard": {"shape": "shard", "size": Vector3(1, 1, 0.5), "mass": 20.0, "color": Color(0.9, 0.85, 0.7), "bounce": 0.05, "label": "Fragment"},
	"flag": {"shape": "flag", "size": Vector3(0.12, 2.4, 0.12), "mass": 12.0, "color": Color(1, 1, 1), "bounce": 0.1, "label": "Flag"},
	# Puzzles: a big fan (placed by a PuzzleFan, which makes it blow) you can grab and aim.
	"fan": {"shape": "fan", "size": Vector3(1.5, 1.7, 0.8), "mass": 40.0, "color": Color(0.3, 0.75, 0.95), "bounce": 0.1, "label": "Fan", "metal": true},
}

## Props a player can spawn in sandbox mode, bound to number keys 1-9.
const SPAWNABLE := ["crate", "crate_big", "barrel", "boom_barrel", "ball", "beachball", "anvil", "plank", "couch"]

var prop_id := 0
var kind := "crate"
var size := Vector3.ONE
var color := Color.WHITE
var team := 0
var explosive := false
var is_server := true
var spawned_by := 0
var spawn_time := 0.0
var _flicker: OmniLight3D
var extra := {} # kind-specific data (fragment polygons, thickness, material)

# Server-side gameplay state.
var held_by := 0 # player id or 0
var last_thrower := 0
var last_thrown_time := -100.0
var live := false # dodgeball: thrown and hasn't touched the world yet
var frozen_by_player := false
var exploded := false
var home_transform := Transform3D.IDENTITY
var _prev_velocity := Vector3.ZERO
var _last_fx_time := 0.0

# Client-side interpolation.
var _target_xform := Transform3D.IDENTITY
var _target_vel := Vector3.ZERO
var _has_target := false
var _since_snapshot := 0.0

var world: Node


static func create(p_world: Node, id: int, p_kind: String, xform: Transform3D, p_size := Vector3.ZERO, p_color := Color(0, 0, 0, 0), p_team := 0, p_extra := {}) -> Prop:
	var p := Prop.new()
	p.world = p_world
	p.prop_id = id
	p.kind = p_kind if DEFS.has(p_kind) else "crate"
	p.name = "R%d" % id
	p.team = p_team
	p.extra = p_extra
	var def: Dictionary = DEFS[p.kind]
	p.size = p_size if p_size != Vector3.ZERO else def.size
	p.color = p_color if p_color.a > 0.0 else def.color
	if p.kind == "flag":
		p.color = Game.team_color(p_team)
	p.explosive = def.get("explosive", false)
	p.transform = xform
	# Where it came from, in map space (ship-local on a moving map): see Arena.xf_world().
	var arena = p_world.get("arena") if p_world else null
	p.home_transform = arena.xf_local(xform) if arena else xform
	p._target_xform = xform
	p._build(def)
	return p


## Outline polygon (local XY, thickness along Z) for "outline" props.
static func outline_for(p_kind: String) -> PackedVector2Array:
	match p_kind:
		"gravestone":
			var pts := PackedVector2Array([Vector2(-0.4, -0.55), Vector2(0.4, -0.55), Vector2(0.4, 0.2)])
			for i in range(1, 8):
				var a := i * PI / 8.0
				pts.append(Vector2(cos(a) * 0.4, 0.2 + sin(a) * 0.35))
			pts.append(Vector2(-0.4, 0.2))
			return pts
		"coffin":
			return PackedVector2Array([Vector2(-0.28, -0.9), Vector2(0.28, -0.9), Vector2(0.45, 0.35), Vector2(0.3, 0.9), Vector2(-0.3, 0.9), Vector2(-0.45, 0.35)])
	return PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])


func is_fragile() -> bool:
	return DEFS[kind].has("fragile")


func _build(def: Dictionary) -> void:
	collision_layer = Game.L_PROPS
	collision_mask = Game.L_WORLD | Game.L_PLAYERS | Game.L_PROPS
	if kind == "candy":
		# Players walk through candy to collect it.
		collision_mask = Game.L_WORLD | Game.L_PROPS
	var m: float = def.mass
	if kind == "debris":
		m = clampf(size.x * size.y * size.z * 45.0, 4.0, 120.0)
	if kind == "shard":
		_build_shard()
		return
	mass = m
	continuous_cd = mass < 10.0
	var pm := PhysicsMaterial.new()
	pm.bounce = def.bounce
	pm.friction = 0.7
	physics_material_override = pm
	linear_damp = def.get("damp", 0.05)
	angular_damp = 0.3
	# On a moving map (a ship) props must stay awake to ride along and slide.
	var arena = world.get("arena") if world else null
	can_sleep = arena == null or arena.carrier == null

	var shape_node := CollisionShape3D.new()
	var mesh := MeshInstance3D.new()
	var mat: Material = Mats.plastic(color, 0.25 if def.get("metal", false) else 0.45)
	match def.shape:
		"box":
			var s := BoxShape3D.new()
			s.size = size
			shape_node.shape = s
			var bm := BoxMesh.new()
			bm.size = size
			mesh.mesh = bm
			if kind == "debris":
				mat = Mats.world(color)
			elif kind.begins_with("crate"):
				_add_crate_trim(mesh)
		"sphere":
			var s := SphereShape3D.new()
			s.radius = size.x
			shape_node.shape = s
			var sm := SphereMesh.new()
			sm.radius = size.x
			sm.height = size.x * 2.0
			mesh.mesh = sm
			if kind == "beachball":
				_add_beachball_stripes(mesh)
		"cyl":
			var s := CylinderShape3D.new()
			s.radius = size.x
			s.height = size.y
			shape_node.shape = s
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.x
			cm.height = size.y
			mesh.mesh = cm
			if kind == "tire":
				mat = Mats.plastic(color, 0.9)
			_add_barrel_bands(mesh)
		"cone":
			var s := CylinderShape3D.new()
			s.radius = size.x
			s.height = size.y
			shape_node.shape = s
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = size.x
			cm.height = size.y
			mesh.mesh = cm
		"couch":
			var s := BoxShape3D.new()
			s.size = size
			shape_node.shape = s
			_build_couch(mesh)
		"flag":
			var s := BoxShape3D.new()
			s.size = Vector3(0.35, size.y, 0.35)
			shape_node.shape = s
			_build_flag(mesh)
		"pumpkin":
			var s := SphereShape3D.new()
			s.radius = size.x
			shape_node.shape = s
			_build_pumpkin(mesh, def)
		"outline":
			var poly := Prop.outline_for(kind)
			var s := ConvexPolygonShape3D.new()
			s.points = Fracture.prism_points(poly, size.z)
			shape_node.shape = s
			var smat: String = def.get("shatter", "concrete")
			mesh.mesh = Fracture.fragment_mesh([poly], size.z, Mats.slab(color, smat), Mats.slab(color.darkened(0.15), smat, true))
			mat = null
			if kind == "gravestone":
				_add_gravestone_text(mesh)
		"candy":
			var s := SphereShape3D.new()
			s.radius = 0.12
			shape_node.shape = s
			_build_candy(mesh)
		"fan":
			var s := BoxShape3D.new()
			s.size = size
			shape_node.shape = s
			_build_fan(mesh)
	if mesh.mesh and mat:
		mesh.material_override = mat
	add_child(shape_node)
	add_child(mesh)


func _build_pumpkin(parent: MeshInstance3D, def: Dictionary) -> void:
	var r := size.x
	var gold := kind == "pumpkin_gold"
	var skin := Mats.plastic(color, 0.25 if gold else 0.55, 0.4 if gold else 0.0)
	# Ribbed body: overlapping squashed lobes around the vertical axis.
	for i in 6:
		var lobe := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r * 0.62
		sm.height = r * 1.55
		lobe.mesh = sm
		var a := i * TAU / 6.0
		lobe.position = Vector3(cos(a), 0, sin(a)) * r * 0.36
		lobe.rotation.y = -a
		lobe.scale = Vector3(1.0, 1.0, 0.8)
		lobe.material_override = skin
		parent.add_child(lobe)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.06
	cm.bottom_radius = r * 0.12
	cm.height = r * 0.45
	stem.mesh = cm
	stem.position = Vector3(0.02, r * 0.78, 0)
	stem.rotation.z = -0.25
	stem.material_override = Mats.plastic(Color(0.35, 0.45, 0.15), 0.8)
	parent.add_child(stem)
	# Carved face glowing from inside.
	var glow := Mats.glow(Color(1.0, 0.75, 0.25), 4.0)
	var face := [
		[Vector3(-0.32, 0.18, -0.93), Vector3(0.22, 0.2, 0.08), 0.0],
		[Vector3(0.32, 0.18, -0.93), Vector3(0.22, 0.2, 0.08), 0.0],
		[Vector3(0.0, -0.02, -0.98), Vector3(0.1, 0.1, 0.06), 0.785],
		[Vector3(0.0, -0.32, -0.92), Vector3(0.6, 0.12, 0.08), 0.0],
	]
	for f in face:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = f[1] * r * 1.6
		mi.mesh = bm
		mi.position = f[0] * r
		mi.rotation.z = f[2]
		mi.material_override = glow
		parent.add_child(mi)
	for k in 3:
		var tooth := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.08, 0.1, 0.1) * r * 1.6
		tooth.mesh = tb
		tooth.position = Vector3(-0.2 + k * 0.2, -0.27, -0.95) * r
		tooth.material_override = skin
		parent.add_child(tooth)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2) if not gold else Color(1.0, 0.85, 0.4)
	light.light_energy = 1.4 if not gold else 2.5
	light.omni_range = 4.5 if not gold else 7.0
	light.position = Vector3(0, 0, -r * 0.6)
	parent.add_child(light)
	_flicker = light


func _add_gravestone_text(parent: MeshInstance3D) -> void:
	var l := Label3D.new()
	l.text = ["RIP", "YEETED", "HERE LIES\nBOB", "OOPS"][prop_id % 4]
	l.font_size = 48
	l.pixel_size = 0.004
	l.position = Vector3(0, 0.1, -size.z * 0.5 - 0.01)
	l.rotation.y = PI
	l.modulate = Color(0.25, 0.25, 0.3)
	l.outline_size = 0
	parent.add_child(l)


func _build_candy(parent: MeshInstance3D) -> void:
	var palette := [Color(1, 0.3, 0.55), Color(0.4, 0.85, 1), Color(1, 0.85, 0.2), Color(0.6, 1, 0.4), Color(0.85, 0.5, 1)]
	var c: Color = palette[prop_id % palette.size()]
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	body.mesh = sm
	body.scale = Vector3(1, 1, 1.3)
	body.material_override = Mats.plastic(c, 0.2, 0.6)
	parent.add_child(body)
	for sx in [-1, 1]:
		var wrap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.06
		cm.height = 0.09
		wrap.mesh = cm
		wrap.rotation.x = sx * PI * 0.5
		wrap.position = Vector3(0, 0, sx * 0.12)
		wrap.material_override = Mats.plastic(c.lightened(0.4), 0.2, 0.4)
		parent.add_child(wrap)


## Irregular fragment of a destructible: one or more extruded polygons.
func _build_shard() -> void:
	var polys: Array = extra.get("polys", [])
	var t: float = extra.get("t", 0.5)
	var mat_name: String = extra.get("mat", "plaster")
	var md := Fracture.mat(mat_name)
	var total := 0.0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for poly: PackedVector2Array in polys:
		total += Fracture.area(poly)
		for v in poly:
			lo = lo.min(v)
			hi = hi.max(v)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = Fracture.prism_points(poly, t)
		cs.shape = shape
		add_child(cs)
	size = Vector3(maxf(hi.x - lo.x, 0.1), maxf(hi.y - lo.y, 0.1), t)
	mass = clampf(total * t * md.density, 2.0, 500.0)
	continuous_cd = mass < 10.0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.05
	pm.friction = 0.8
	pm.rough = true
	physics_material_override = pm
	angular_damp = 0.4
	var mi := MeshInstance3D.new()
	mi.mesh = Fracture.fragment_mesh(polys, t, Mats.slab(color, mat_name), Mats.slab(color, mat_name, true))
	add_child(mi)


func _add_crate_trim(parent: MeshInstance3D) -> void:
	var trim := Mats.plastic(color.darkened(0.35), 0.6)
	for axis in 3:
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var bar := MeshInstance3D.new()
				var bm := BoxMesh.new()
				var t := size.x * 0.1
				var e := size * 1.02
				match axis:
					0:
						bm.size = Vector3(e.x, t, t)
						bar.position = Vector3(0, sx * size.y * 0.47, sy * size.z * 0.47)
					1:
						bm.size = Vector3(t, e.y, t)
						bar.position = Vector3(sx * size.x * 0.47, 0, sy * size.z * 0.47)
					2:
						bm.size = Vector3(t, t, e.z)
						bar.position = Vector3(sx * size.x * 0.47, sy * size.y * 0.47, 0)
				bar.mesh = bm
				bar.material_override = trim
				parent.add_child(bar)


func _add_barrel_bands(parent: MeshInstance3D) -> void:
	if kind == "tire":
		return
	var band_color := Color(1, 0.9, 0.2) if explosive else color.lightened(0.4)
	for y in [-0.3, 0.3]:
		var band := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 1.04
		cm.bottom_radius = size.x * 1.04
		cm.height = size.y * 0.08
		band.mesh = cm
		band.position.y = y * size.y
		band.material_override = Mats.plastic(band_color, 0.4, 1.5 if explosive else 0.0)
		parent.add_child(band)


func _add_beachball_stripes(parent: MeshInstance3D) -> void:
	var cols := [Color(1, 0.3, 0.3), Color(0.3, 0.6, 1), Color(1, 1, 1)]
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = size.x * 0.97
		tm.outer_radius = size.x * 1.03
		ring.mesh = tm
		ring.rotation = Vector3(PI * 0.5, i * PI / 3.0, 0)
		ring.material_override = Mats.plastic(cols[i], 0.3)
		parent.add_child(ring)


func _build_couch(parent: MeshInstance3D) -> void:
	var mat := Mats.plastic(color, 0.8)
	var parts := [
		[Vector3(size.x, size.y * 0.45, size.z), Vector3(0, -size.y * 0.27, 0)],
		[Vector3(size.x, size.y * 0.55, size.z * 0.25), Vector3(0, size.y * 0.22, -size.z * 0.37)],
		[Vector3(size.x * 0.12, size.y * 0.35, size.z), Vector3(-size.x * 0.44, 0.0, 0)],
		[Vector3(size.x * 0.12, size.y * 0.35, size.z), Vector3(size.x * 0.44, 0.0, 0)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		mi.material_override = mat
		parent.add_child(mi)


func _build_flag(parent: MeshInstance3D) -> void:
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = size.y
	pole.mesh = cm
	pole.material_override = Mats.plastic(Color(0.9, 0.9, 0.95), 0.2)
	parent.add_child(pole)
	var cloth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.7, 1.1)
	cloth.mesh = bm
	cloth.position = Vector3(0, size.y * 0.5 - 0.4, 0.58)
	cloth.material_override = Mats.plastic(color, 0.5, 1.2)
	parent.add_child(cloth)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position.y = size.y * 0.5
	parent.add_child(light)


var _rotor: Node3D
var _wind_fx: CPUParticles3D
var _wind_sound: AudioStreamPlayer3D
var _rotor_speed := 0.0


## The fan: a stand, a round housing facing its forward (-Z), a rotor and the wind it blows.
func _build_fan(parent: MeshInstance3D) -> void:
	var metal := Mats.plastic(color, 0.3)
	var dark := Mats.plastic(Color(0.18, 0.2, 0.26), 0.4)
	parent.add_child(PuzzleNode.box_mesh(Vector3(1.2, 0.14, 0.8), dark, Vector3(0, -size.y * 0.5 + 0.07, 0)))
	parent.add_child(PuzzleNode.box_mesh(Vector3(0.16, 0.6, 0.16), dark, Vector3(0, -size.y * 0.5 + 0.4, 0)))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position.y = 0.2
	ring.material_override = metal
	parent.add_child(ring)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 0.2, 0)
	parent.add_child(_rotor)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.12
	hm.bottom_radius = 0.14
	hm.height = 0.25
	hub.mesh = hm
	hub.rotation_degrees = Vector3(90, 0, 0)
	hub.material_override = dark
	_rotor.add_child(hub)
	for k in 3:
		var blade := PuzzleNode.box_mesh(Vector3(0.18, 0.5, 0.04), Mats.plastic(Color(0.92, 0.94, 1.0), 0.3), Vector3(0, 0.3, 0))
		var pivot := Node3D.new()
		pivot.rotation.z = k * TAU / 3.0
		blade.rotation.y = 0.5
		pivot.add_child(blade)
		_rotor.add_child(pivot)
	# Wind: streaks blowing out of the front while it runs.
	_wind_fx = CPUParticles3D.new()
	_wind_fx.emitting = false
	_wind_fx.amount = 24
	_wind_fx.lifetime = 0.7
	_wind_fx.local_coords = false
	_wind_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_wind_fx.emission_sphere_radius = 0.45
	_wind_fx.position = Vector3(0, 0.2, -0.3)
	_wind_fx.direction = Vector3(0, 0, -1)
	_wind_fx.spread = 8.0
	_wind_fx.initial_velocity_min = 10.0
	_wind_fx.initial_velocity_max = 15.0
	_wind_fx.gravity = Vector3.ZERO
	_wind_fx.particle_flag_align_y = true
	var sm := BoxMesh.new()
	sm.size = Vector3(0.02, 0.5, 0.02)
	_wind_fx.mesh = sm
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.vertex_color_use_as_albedo = true
	_wind_fx.material_override = wm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.25, Color(0.9, 0.97, 1.0, 0.5))
	_wind_fx.color_ramp = g
	parent.add_child(_wind_fx)
	_wind_sound = AudioStreamPlayer3D.new()
	_wind_sound.stream = Sfx.stream("wind")
	_wind_sound.bus = "SFX"
	_wind_sound.volume_db = -10.0
	_wind_sound.unit_size = 4.0
	parent.add_child(_wind_sound)


## The PuzzleFan this fan belongs to (or null).
func fan_piece() -> PuzzleFan:
	var idx: int = extra.get("fan_piece", -1)
	var arena = world.get("arena") if world else null
	if arena == null or idx < 0 or idx >= arena.puzzle.size():
		return null
	return arena.puzzle[idx] as PuzzleFan


func _process(delta: float) -> void:
	if _rotor:
		var piece := fan_piece()
		var on := piece != null and piece.active
		_rotor_speed = move_toward(_rotor_speed, 30.0 if on else 0.0, delta * 25.0)
		_rotor.rotate_object_local(Vector3.FORWARD, _rotor_speed * delta)
		_wind_fx.emitting = on
		_wind_fx.direction = Vector3(0, 0, -1)
		if on and not _wind_sound.playing:
			_wind_sound.play()
		elif not on and _wind_sound.playing:
			_wind_sound.stop()
		return
	if _flicker:
		var t := Time.get_ticks_msec() * 0.001 + prop_id
		_flicker.light_energy = (1.4 if kind == "pumpkin" else 2.5) * (0.8 + 0.2 * sin(t * 13.0) * sin(t * 7.3))
	else:
		set_process(false)


func _ready() -> void:
	spawn_time = Time.get_ticks_msec() / 1000.0
	if is_server:
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_body_entered)
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


func setup_role(server: bool) -> void:
	is_server = server


func _physics_process(delta: float) -> void:
	if is_server:
		_prev_velocity = linear_velocity
		if global_position.y < world.arena.kill_y - 15.0:
			world.server_prop_fell_out(self)
	elif _has_target:
		# Extrapolate along the last known velocity, then ease toward it.
		_since_snapshot += delta
		if _since_snapshot < 0.15:
			_target_xform.origin += _target_vel * delta
		var t := 1.0 - exp(-18.0 * delta)
		var xf := global_transform
		if xf.origin.distance_to(_target_xform.origin) > 8.0:
			xf.origin = _target_xform.origin
		else:
			xf.origin = xf.origin.lerp(_target_xform.origin, t)
		xf.basis = Basis(xf.basis.get_rotation_quaternion().slerp(_target_xform.basis.get_rotation_quaternion(), t))
		global_transform = xf


## How fast the prop is moving on this peer (clients only know the streamed velocity).
func motion_velocity() -> Vector3:
	return linear_velocity if is_server else _target_vel


func apply_snapshot(pos: Vector3, rot: Quaternion, vel: Vector3) -> void:
	_target_xform = Transform3D(Basis(rot), pos)
	_target_vel = vel
	_since_snapshot = 0.0
	if not _has_target:
		global_transform = _target_xform
	_has_target = true


func _on_body_entered(body: Node) -> void:
	if not is_server or world == null:
		return
	var other_vel := Vector3.ZERO
	if body is RigidBody3D:
		other_vel = (body as RigidBody3D).linear_velocity
	elif body is CharacterBody3D:
		other_vel = (body as CharacterBody3D).velocity
	var rel := _prev_velocity - other_vel
	var speed := rel.length()
	# Deferred: we are inside the physics flush, where adding/removing bodies is not allowed.
	world.call_deferred("server_prop_impact", self, body, rel, speed)


## Surface material for impact sounds and particles.
func impact_material() -> String:
	match kind:
		"crate", "crate_big", "plank":
			return "wood"
		"barrel", "boom_barrel", "anvil", "flag", "fan":
			return "metal"
		"ball", "beachball", "tire", "cone":
			return "rubber"
		"couch", "pumpkin", "pumpkin_gold", "candy":
			return "soft"
		"gravestone":
			return "stone"
		"coffin":
			return "wood"
		"shard":
			var m: String = extra.get("mat", "plaster")
			return m if m in ["wood", "metal", "glass"] else "stone"
	return "stone"


func can_sound(now: float) -> bool:
	if now - _last_fx_time < 0.12:
		return false
	_last_fx_time = now
	return true


func is_light() -> bool:
	return mass < 15.0
