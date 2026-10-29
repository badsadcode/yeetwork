class_name Prop
extends RigidBody3D
## A networked physics object. Simulated on the server; clients receive snapshots and
## move a frozen kinematic copy toward them.

const DEFS := {
	"crate": {"shape": "box", "size": Vector3(1, 1, 1), "mass": 25.0, "color": Color(0.95, 0.62, 0.25), "bounce": 0.15, "label": "Crate"},
	"crate_big": {"shape": "box", "size": Vector3(1.7, 1.7, 1.7), "mass": 70.0, "color": Color(0.85, 0.5, 0.2), "bounce": 0.1, "label": "Big Crate"},
	"barrel": {"shape": "cyl", "size": Vector3(0.42, 1.15, 0.42), "mass": 40.0, "color": Color(0.2, 0.6, 1.0), "bounce": 0.2, "label": "Barrel"},
	"boom_barrel": {"shape": "cyl", "size": Vector3(0.42, 1.15, 0.42), "mass": 35.0, "color": Color(1.0, 0.18, 0.15), "bounce": 0.2, "label": "Boom Barrel", "explosive": true},
	"ball": {"shape": "sphere", "size": Vector3(0.36, 0.36, 0.36), "mass": 4.0, "color": Color(1.0, 0.3, 0.55), "bounce": 0.75, "label": "Dodgeball"},
	"beachball": {"shape": "sphere", "size": Vector3(0.95, 0.95, 0.95), "mass": 2.0, "color": Color(1.0, 0.92, 0.25), "bounce": 0.85, "label": "Beach Ball", "damp": 0.6},
	"anvil": {"shape": "box", "size": Vector3(0.55, 0.5, 1.0), "mass": 300.0, "color": Color(0.25, 0.27, 0.32), "bounce": 0.0, "label": "Anvil", "metal": true},
	"plank": {"shape": "box", "size": Vector3(3.2, 0.16, 0.55), "mass": 15.0, "color": Color(0.8, 0.6, 0.38), "bounce": 0.1, "label": "Plank"},
	"couch": {"shape": "couch", "size": Vector3(2.0, 0.9, 0.95), "mass": 60.0, "color": Color(0.6, 0.35, 0.95), "bounce": 0.25, "label": "Couch"},
	"tire": {"shape": "cyl", "size": Vector3(0.6, 0.38, 0.6), "mass": 20.0, "color": Color(0.12, 0.12, 0.14), "bounce": 0.8, "label": "Tire"},
	"cone": {"shape": "cone", "size": Vector3(0.3, 0.8, 0.3), "mass": 3.0, "color": Color(1.0, 0.5, 0.1), "bounce": 0.3, "label": "Cone"},
	"debris": {"shape": "box", "size": Vector3(1, 1, 1), "mass": 30.0, "color": Color(0.7, 0.7, 0.7), "bounce": 0.05, "label": "Debris"},
	"flag": {"shape": "flag", "size": Vector3(0.12, 2.4, 0.12), "mass": 12.0, "color": Color(1, 1, 1), "bounce": 0.1, "label": "Flag"},
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


static func create(p_world: Node, id: int, p_kind: String, xform: Transform3D, p_size := Vector3.ZERO, p_color := Color(0, 0, 0, 0), p_team := 0) -> Prop:
	var p := Prop.new()
	p.world = p_world
	p.prop_id = id
	p.kind = p_kind if DEFS.has(p_kind) else "crate"
	p.name = "R%d" % id
	p.team = p_team
	var def: Dictionary = DEFS[p.kind]
	p.size = p_size if p_size != Vector3.ZERO else def.size
	p.color = p_color if p_color.a > 0.0 else def.color
	if p.kind == "flag":
		p.color = Game.team_color(p_team)
	p.explosive = def.get("explosive", false)
	p.transform = xform
	p.home_transform = xform
	p._target_xform = xform
	p._build(def)
	return p


func _build(def: Dictionary) -> void:
	collision_layer = Game.L_PROPS
	collision_mask = Game.L_WORLD | Game.L_PLAYERS | Game.L_PROPS
	var m: float = def.mass
	if kind == "debris":
		m = clampf(size.x * size.y * size.z * 45.0, 4.0, 120.0)
	mass = m
	continuous_cd = mass < 10.0
	var pm := PhysicsMaterial.new()
	pm.bounce = def.bounce
	pm.friction = 0.7
	physics_material_override = pm
	linear_damp = def.get("damp", 0.05)
	angular_damp = 0.3
	can_sleep = true

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
	if mesh.mesh:
		mesh.material_override = mat
	add_child(shape_node)
	add_child(mesh)


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


func can_sound(now: float) -> bool:
	if now - _last_fx_time < 0.12:
		return false
	_last_fx_time = now
	return true


func is_light() -> bool:
	return mass < 15.0
