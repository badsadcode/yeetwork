class_name CharacterModel
extends Node3D
## Goofy toy-like character in the spirit of Kenney's characters: big head, googly eyes,
## stubby limbs and a silly hat. Animated procedurally from movement state.
## Faces -Z. Parts are siblings under `body` so the death ragdoll can copy them.

const SKINS := [Color(1.0, 0.85, 0.7), Color(0.93, 0.72, 0.55), Color(0.75, 0.55, 0.4), Color(0.5, 0.36, 0.26), Color(1.0, 0.8, 0.55)]
const SKIN_NAMES := ["Peach", "Tan", "Caramel", "Cocoa", "Honey"]
const HAT_NAMES := ["Hair tuft", "Party cone", "Top hat", "Propeller beanie", "Antenna", "Horns", "Bucket", "Pumpkin head", "Witch hat", "Baseball cap", "Crown", "Chef hat", "Viking helmet"]
const HAT_COUNT := 13
const SPOOKY_HATS := [7, 8] # Halloween costumes
## Head attachments, worn together with any hat (except the pumpkin head, which covers the face).
const FACE_NAMES := ["Nothing", "Round glasses", "Shades", "Mustache", "Clown nose", "Headphones", "Bow", "Monocle", "Eyepatch"]

## Collision specs used by the ragdoll: part -> [shape, radius, height, offset].
const PART_SPECS := {
	"torso": ["capsule", 0.34, 0.95, Vector3.ZERO],
	"head": ["sphere", 0.36, 0.0, Vector3.ZERO],
	"arm_l": ["capsule", 0.1, 0.6, Vector3(0, -0.27, 0)],
	"arm_r": ["capsule", 0.1, 0.6, Vector3(0, -0.27, 0)],
	"leg_l": ["capsule", 0.12, 0.62, Vector3(0, -0.27, 0)],
	"leg_r": ["capsule", 0.12, 0.62, Vector3(0, -0.27, 0)],
}

var body: Node3D
var parts := {}
var gun_socket: Node3D
## The meshes of the hat and of the head extra (children of the head), e.g. for exporting.
var hat_nodes: Array[Node3D] = []
var face_nodes: Array[Node3D] = []
var _pupils: Array[MeshInstance3D] = []
var _propeller: Node3D
var _phase := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _tumble := Basis.IDENTITY
var _pupil_off := Vector2.ZERO
var _pupil_v := Vector2.ZERO
var _last_vel := Vector3.ZERO
var _yaw := 0.0
var _time := 0.0
var _first_person := false


## A random everyday hat (or, in spooky mode, mostly Halloween costumes).
static func random_hat(rng: RandomNumberGenerator, spooky: bool) -> int:
	if spooky and rng.randf() < 0.75:
		return SPOOKY_HATS[rng.randi() % SPOOKY_HATS.size()]
	var hat := rng.randi() % HAT_COUNT
	while hat in SPOOKY_HATS:
		hat = rng.randi() % HAT_COUNT
	return hat


## skin_index < 0 picks a skin tone from the seed. face: index into FACE_NAMES.
func setup(shirt: Color, hat: int, seed_value: int, face := 0, skin_index := -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	if skin_index >= 0:
		skin = SKINS[skin_index % SKINS.size()]
	var pants := Color(0.2, 0.22, 0.35).lerp(shirt.darkened(0.6), 0.3)
	var shoe := Color(0.95, 0.95, 0.95)

	body = Node3D.new()
	body.position.y = 0.9
	add_child(body)

	var torso := _part("torso", Vector3(0, 0.05, 0))
	_capsule(torso, 0.34, 0.95, shirt, Vector3.ZERO)
	# Belly patch + belt for a clear silhouette.
	_sphere(torso, 0.27, shirt.lightened(0.35), Vector3(0, -0.05, -0.12), Vector3(1, 1.1, 0.6))
	_cyl(torso, 0.345, 0.08, pants.darkened(0.2), Vector3(0, -0.28, 0))

	var head := _part("head", Vector3(0, 0.65, 0))
	_sphere(head, 0.36, skin, Vector3.ZERO, Vector3.ONE).material_override = Mats.skin(skin)
	for sx in [-1, 1]:
		_sphere(head, 0.125, Color.WHITE, Vector3(sx * 0.13, 0.07, -0.29), Vector3.ONE)
		var pupil := _sphere(head, 0.06, Color(0.05, 0.05, 0.08), Vector3(sx * 0.13, 0.07, -0.4), Vector3(1, 1, 0.5))
		_pupils.append(pupil)
		_sphere(head, 0.07, Color(1.0, 0.5, 0.55), Vector3(sx * 0.22, -0.08, -0.26), Vector3(1, 0.6, 0.4))
	_sphere(head, 0.08, Color(0.35, 0.1, 0.12), Vector3(0, -0.15, -0.31), Vector3(1.4, 0.55, 0.5))
	var n := head.get_child_count()
	_build_hat(head, hat, shirt, rng)
	for i in range(n, head.get_child_count()):
		hat_nodes.append(head.get_child(i))
	n = head.get_child_count()
	if hat % HAT_COUNT != 7:
		_build_face(head, face, shirt)
	for i in range(n, head.get_child_count()):
		face_nodes.append(head.get_child(i))

	for sx in [-1, 1]:
		var arm := _part("arm_l" if sx < 0 else "arm_r", Vector3(sx * 0.43, 0.38, 0))
		_capsule(arm, 0.1, 0.6, shirt, Vector3(0, -0.22, 0))
		_sphere(arm, 0.12, skin, Vector3(0, -0.52, 0), Vector3.ONE).material_override = Mats.skin(skin)
		if sx > 0:
			gun_socket = Node3D.new()
			gun_socket.position = Vector3(0, -0.55, -0.05)
			arm.add_child(gun_socket)
		var leg := _part("leg_l" if sx < 0 else "leg_r", Vector3(sx * 0.16, -0.35, 0))
		_capsule(leg, 0.12, 0.62, pants, Vector3(0, -0.25, 0))
		_box(leg, Vector3(0.22, 0.14, 0.34), shoe, Vector3(0, -0.5, -0.06))


func _part(part_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = part_name
	n.position = pos
	body.add_child(n)
	parts[part_name] = n
	return n


func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.material_override = Mats.plastic(color, 0.4)
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, color: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return _mesh(parent, m, color, pos, scl)


func _capsule(parent: Node3D, r: float, h: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return _mesh(parent, m, color, pos)


func _cyl(parent: Node3D, r: float, h: float, color: Color, pos: Vector3, top := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r if top < 0.0 else top
	m.bottom_radius = r
	m.height = h
	return _mesh(parent, m, color, pos)


func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, m, color, pos)


func _build_hat(head: Node3D, hat: int, shirt: Color, rng: RandomNumberGenerator) -> void:
	var accent := Color.from_hsv(rng.randf(), 0.7, 1.0)
	match hat % HAT_COUNT:
		1: # Party cone.
			var cone := _cyl(head, 0.2, 0.5, accent, Vector3(0.05, 0.5, 0), 0.0)
			cone.rotation.z = -0.2
			_sphere(head, 0.07, Color.WHITE, Vector3(0.1, 0.76, 0), Vector3.ONE)
		2: # Top hat.
			_cyl(head, 0.38, 0.04, Color(0.1, 0.1, 0.12), Vector3(0, 0.3, 0))
			_cyl(head, 0.24, 0.42, Color(0.1, 0.1, 0.12), Vector3(0, 0.5, 0))
			_cyl(head, 0.245, 0.07, shirt, Vector3(0, 0.34, 0))
		3: # Propeller beanie.
			_sphere(head, 0.33, accent, Vector3(0, 0.12, 0), Vector3(1, 0.75, 1))
			_cyl(head, 0.025, 0.2, Color(0.8, 0.8, 0.8), Vector3(0, 0.43, 0))
			_propeller = Node3D.new()
			_propeller.position = Vector3(0, 0.53, 0)
			head.add_child(_propeller)
			_box(_propeller, Vector3(0.6, 0.02, 0.1), Color(1, 0.85, 0.2), Vector3.ZERO)
			_box(_propeller, Vector3(0.1, 0.02, 0.6), Color(0.3, 0.7, 1.0), Vector3.ZERO)
		4: # Antenna.
			_cyl(head, 0.02, 0.35, Color(0.2, 0.2, 0.2), Vector3(0, 0.5, 0))
			_sphere(head, 0.09, accent, Vector3(0, 0.7, 0), Vector3.ONE)
		5: # Horns.
			for sx in [-1, 1]:
				var horn := _cyl(head, 0.08, 0.35, Color(0.98, 0.95, 0.85), Vector3(sx * 0.3, 0.3, 0), 0.0)
				horn.rotation.z = -sx * 0.7
		6: # Bucket.
			_cyl(head, 0.3, 0.32, accent, Vector3(0, 0.36, 0), 0.34)
		7: # Pumpkin head: a jack-o'-lantern over the whole head.
			var orange := Color(1.0, 0.5, 0.08)
			for i in 6:
				var a := i * TAU / 6.0
				var lobe := _sphere(head, 0.27, orange, Vector3(cos(a), 0, sin(a)) * 0.17 + Vector3(0, 0.04, 0), Vector3(1.0, 1.25, 0.8))
				lobe.rotation.y = -a
			_cyl(head, 0.03, 0.18, Color(0.35, 0.45, 0.15), Vector3(0, 0.45, 0))
			for sx in [-1, 1]:
				var eye := _box(head, Vector3(0.12, 0.1, 0.05), Color(1, 0.75, 0.25), Vector3(sx * 0.13, 0.1, -0.42))
				eye.material_override = Mats.glow(Color(1, 0.75, 0.25), 4.0)
				eye.rotation.z = sx * 0.4
			var mouth := _box(head, Vector3(0.3, 0.07, 0.05), Color(1, 0.75, 0.25), Vector3(0, -0.12, -0.42))
			mouth.material_override = Mats.glow(Color(1, 0.75, 0.25), 4.0)
			_pupils.clear() # googly eyes are inside the pumpkin
		8: # Witch hat.
			var black := Color(0.12, 0.08, 0.16)
			_cyl(head, 0.5, 0.04, black, Vector3(0, 0.27, 0))
			var cone := _cyl(head, 0.26, 0.6, black, Vector3(0.04, 0.58, 0.02), 0.0)
			cone.rotation.z = -0.25
			_cyl(head, 0.265, 0.07, Color(0.6, 0.25, 0.9), Vector3(0, 0.33, 0))
		9: # Baseball cap, peak forward.
			_sphere(head, 0.35, accent, Vector3(0, 0.1, 0.01), Vector3(1.02, 0.72, 1.02))
			var peak := _cyl(head, 0.22, 0.03, accent.darkened(0.25), Vector3(0, 0.2, -0.3))
			peak.scale = Vector3(1.0, 1.0, 0.75)
			_sphere(head, 0.045, Color.WHITE, Vector3(0, 0.36, 0), Vector3.ONE)
		10: # Crown.
			var gold := Color(1.0, 0.8, 0.2)
			var band := _cyl(head, 0.26, 0.14, gold, Vector3(0, 0.36, 0))
			band.material_override = Mats.plastic(gold, 0.2)
			for i in 5:
				var a := i * TAU / 5.0
				var spike := _cyl(head, 0.06, 0.16, gold, Vector3(sin(a) * 0.22, 0.5, cos(a) * 0.22), 0.0)
				spike.material_override = Mats.plastic(gold, 0.2)
				_sphere(head, 0.035, [Color(1, 0.2, 0.3), Color(0.2, 0.6, 1)][i % 2], Vector3(sin(a) * 0.24, 0.37, cos(a) * 0.24), Vector3.ONE)
		11: # Chef hat.
			_cyl(head, 0.26, 0.2, Color.WHITE, Vector3(0, 0.38, 0))
			for i in 5:
				var a := i * TAU / 5.0
				_sphere(head, 0.16, Color.WHITE, Vector3(sin(a) * 0.12, 0.56, cos(a) * 0.12), Vector3.ONE)
			_sphere(head, 0.17, Color.WHITE, Vector3(0, 0.62, 0), Vector3.ONE)
		12: # Viking helmet.
			var steel := Color(0.72, 0.75, 0.8)
			_sphere(head, 0.36, steel, Vector3(0, 0.17, 0), Vector3(1.03, 0.72, 1.03)).material_override = Mats.plastic(steel, 0.3)
			_cyl(head, 0.36, 0.06, Color(0.55, 0.35, 0.2), Vector3(0, 0.24, 0))
			for sx in [-1, 1]:
				var horn := _cyl(head, 0.07, 0.34, Color(0.98, 0.94, 0.82), Vector3(sx * 0.4, 0.33, 0), 0.0)
				horn.rotation.z = -sx * 0.9
		_:
			# Tuft of hair.
			_sphere(head, 0.14, shirt.darkened(0.4), Vector3(0.05, 0.33, 0.02), Vector3(1.2, 0.7, 1))


func _build_face(head: Node3D, face: int, shirt: Color) -> void:
	var black := Color(0.07, 0.07, 0.09)
	match face % FACE_NAMES.size():
		1: # Round glasses.
			for sx in [-1, 1]:
				_ring(head, 0.14, 0.022, black, Vector3(sx * 0.13, 0.07, -0.39))
				var arm := _box(head, Vector3(0.02, 0.02, 0.3), black, Vector3(sx * 0.31, 0.08, -0.2))
				arm.rotation.y = sx * 0.35
			_box(head, Vector3(0.06, 0.02, 0.02), black, Vector3(0, 0.09, -0.42))
		2: # Shades: dark glossy lenses over the googly eyes.
			for sx in [-1, 1]:
				var lens := _sphere(head, 0.14, black, Vector3(sx * 0.14, 0.07, -0.38), Vector3(1.15, 0.8, 0.35))
				lens.material_override = Mats.plastic(black, 0.08)
				var arm := _box(head, Vector3(0.025, 0.025, 0.3), black, Vector3(sx * 0.31, 0.09, -0.2))
				arm.rotation.y = sx * 0.35
			_box(head, Vector3(0.08, 0.03, 0.03), black, Vector3(0, 0.1, -0.43))
		3: # Mustache.
			var brown := shirt.darkened(0.65).lerp(Color(0.3, 0.18, 0.1), 0.6)
			for sx in [-1, 1]:
				var m := _sphere(head, 0.09, brown, Vector3(sx * 0.075, -0.07, -0.34), Vector3(1.3, 0.5, 0.6))
				m.rotation.z = sx * 0.3
		4: # Clown nose.
			_sphere(head, 0.075, Color(1.0, 0.12, 0.15), Vector3(0, -0.03, -0.38), Vector3.ONE).material_override = Mats.plastic(Color(1.0, 0.12, 0.15), 0.15)
		5: # Headphones.
			var dark := Color(0.15, 0.15, 0.2)
			for i in 7:
				var a := -PI * 0.5 + i * PI / 6.0
				var seg := _box(head, Vector3(0.09, 0.05, 0.1), dark, Vector3(sin(a) * 0.39, cos(a) * 0.39, 0.0))
				seg.rotation.z = -a
			for sx in [-1, 1]:
				var cup := _cyl(head, 0.13, 0.09, shirt.lightened(0.2), Vector3(sx * 0.37, 0.0, 0.0))
				cup.rotation.z = PI * 0.5
		6: # Bow on the side of the head.
			var pink := Color(1.0, 0.4, 0.65)
			for sx in [-1, 1]:
				var loop := _sphere(head, 0.1, pink, Vector3(0.2 + sx * 0.1, 0.3, -0.05), Vector3(1.2, 0.8, 0.5))
				loop.rotation.z = sx * 0.4
			_sphere(head, 0.05, pink.darkened(0.2), Vector3(0.2, 0.3, -0.06), Vector3.ONE)
		7: # Monocle on the right eye.
			var gold := Color(1.0, 0.8, 0.25)
			_ring(head, 0.15, 0.02, gold, Vector3(0.13, 0.07, -0.4)).material_override = Mats.plastic(gold, 0.2)
			_box(head, Vector3(0.012, 0.25, 0.012), gold, Vector3(0.24, -0.1, -0.36))
		8: # Pirate eyepatch over the left eye, strap around the head.
			_sphere(head, 0.13, black, Vector3(-0.13, 0.07, -0.37), Vector3(1.0, 0.9, 0.35))
			var strap := _ring(head, 0.37, 0.018, black, Vector3(0, 0.1, 0))
			strap.rotation = Vector3(0, 0, -0.35)


## A thin ring facing forward (-Z): glasses rims, monocle, straps.
func _ring(parent: Node3D, r: float, thickness: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = r - thickness
	m.outer_radius = r
	m.rings = 24
	m.ring_segments = 8
	var mi := _mesh(parent, m, color, pos)
	mi.rotation.x = PI * 0.5
	return mi


func set_first_person(fp: bool) -> void:
	if fp == _first_person:
		return
	_first_person = fp
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if fp else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_set_shadow_mode(body, mode)


func _set_shadow_mode(n: Node, mode: int) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = mode
		_set_shadow_mode(c, mode)


func squash(amount: float) -> void:
	_squash_v += amount * 8.0


func hand_position() -> Vector3:
	return gun_socket.global_position if gun_socket else global_position + Vector3.UP


func animate(delta: float, vel: Vector3, flags: int, yaw: float, flailing: bool) -> void:
	_time += delta
	_yaw = lerp_angle(_yaw, yaw, 1.0 - exp(-14.0 * delta))
	rotation.y = _yaw
	var hv := Vector3(vel.x, 0, vel.z)
	var hspeed := hv.length()
	var grounded := (flags & Player.F_GROUNDED) != 0
	var ragdoll := (flags & (Player.F_RAGDOLL | Player.F_HELD)) != 0 or flailing
	var sliding := (flags & Player.F_SLIDING) != 0
	var crouched := (flags & Player.F_CROUCHED) != 0
	var wallrun := (flags & Player.F_WALLRUN) != 0
	var k := 1.0 - exp(-14.0 * delta)

	# Squash & stretch spring.
	_squash_v += (-_squash * 120.0 - _squash_v * 10.0) * delta
	_squash += _squash_v * delta
	var s := clampf(_squash, -0.35, 0.35)
	body.scale = Vector3(1.0 + s * 0.5, 1.0 - s, 1.0 + s * 0.5)

	var legs := [0.0, 0.0]
	var arms := [0.0, 0.0]
	var arm_spread := [0.15, 0.15]
	var lean := 0.0
	var body_y := 0.9

	if ragdoll:
		# Tumble around the axis perpendicular to travel; flail everything.
		var spd := vel.length()
		if spd > 1.0:
			var axis := Vector3.UP.cross(vel.normalized())
			if axis.length() < 0.1:
				axis = Vector3.RIGHT
			var local_axis := (global_transform.basis.inverse() * axis.normalized()).normalized()
			_tumble = (Basis(local_axis, minf(spd, 25.0) * 0.6 * delta) * _tumble).orthonormalized()
		var f := _time * 22.0
		legs = [sin(f) * 1.2, sin(f + 2.0) * 1.2]
		arms = [sin(f * 1.3) * 1.6 + 1.0, cos(f * 1.1) * 1.6 + 1.0]
		arm_spread = [1.4 + sin(f) * 0.5, 1.4 + cos(f) * 0.5]
		body.basis = _tumble.orthonormalized().scaled(body.scale)
	else:
		_tumble = Basis(_tumble.orthonormalized().get_rotation_quaternion().slerp(Quaternion.IDENTITY, 1.0 - exp(-10.0 * delta)))
		if grounded and not sliding:
			var amp := clampf(hspeed / 9.0, 0.0, 1.0)
			_phase += hspeed * delta * 1.7
			legs = [sin(_phase) * 0.9 * amp, -sin(_phase) * 0.9 * amp]
			arms = [-sin(_phase) * 0.8 * amp, sin(_phase) * 0.8 * amp]
			body_y = 0.9 + absf(sin(_phase)) * 0.06 * amp
			lean = -0.12 * amp
			if crouched:
				body_y -= 0.35
				legs = [legs[0] + 0.9, legs[1] + 0.9]
		elif sliding:
			legs = [1.3, 1.1]
			arms = [0.5, 0.4]
			arm_spread = [0.9, 0.9]
			lean = 0.5
			body_y = 0.55
		elif wallrun:
			_phase += hspeed * delta * 2.0
			legs = [sin(_phase) * 1.1, -sin(_phase) * 1.1]
			arms = [1.2, 0.4]
			arm_spread = [1.2, 0.3]
		else:
			# Airborne: tuck legs and wave arms comically when falling fast.
			var fall := clampf(-vel.y / 20.0, 0.0, 1.0)
			legs = [-0.6 + sin(_time * 14.0) * 0.5 * fall, 0.3 - sin(_time * 14.0) * 0.5 * fall]
			arms = [2.4 * fall + sin(_time * 18.0) * 0.4 * fall, 2.4 * fall - sin(_time * 18.0) * 0.4 * fall]
			arm_spread = [0.5 + fall, 0.5 + fall]
		var target := Basis.from_euler(Vector3(lean, 0, 0))
		body.basis = (target * _tumble).orthonormalized().scaled(body.scale)
	body.position.y = lerpf(body.position.y, body_y, k)

	var leg_l: Node3D = parts.leg_l
	var leg_r: Node3D = parts.leg_r
	var arm_l: Node3D = parts.arm_l
	var arm_r: Node3D = parts.arm_r
	leg_l.rotation.x = lerp_angle(leg_l.rotation.x, legs[0], k)
	leg_r.rotation.x = lerp_angle(leg_r.rotation.x, legs[1], k)
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, arms[0], k)
	arm_l.rotation.z = lerp_angle(arm_l.rotation.z, -arm_spread[0], k)
	if ragdoll:
		arm_r.rotation.x = lerp_angle(arm_r.rotation.x, arms[1], k)
		arm_r.rotation.z = lerp_angle(arm_r.rotation.z, arm_spread[1], k)
	else:
		# The gun arm points where the player is going.
		arm_r.rotation.x = lerp_angle(arm_r.rotation.x, 1.45, k)
		arm_r.rotation.z = lerp_angle(arm_r.rotation.z, 0.1, k)

	# Googly eyes: pupils lag behind acceleration.
	var accel := (vel - _last_vel) / maxf(delta, 0.001)
	_last_vel = vel
	var local_acc := global_transform.basis.inverse() * accel
	_pupil_v += (Vector2(local_acc.x, -local_acc.y) * -0.0006 - _pupil_off * 160.0 - _pupil_v * 6.0) * delta
	_pupil_off += _pupil_v * delta
	if _pupil_off.length() > 0.055:
		_pupil_off = _pupil_off.normalized() * 0.055
		_pupil_v *= -0.4
	for i in _pupils.size():
		var sx := -1.0 if i == 0 else 1.0
		_pupils[i].position = Vector3(sx * 0.13 + _pupil_off.x, 0.07 + _pupil_off.y, -0.4)
	if _propeller:
		_propeller.rotate_y(delta * (6.0 + hspeed * 2.0 + maxf(-vel.y, 0.0) * 3.0))
