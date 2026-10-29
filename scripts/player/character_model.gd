class_name CharacterModel
extends Node3D
## Goofy toy-like character in the spirit of Kenney's characters: big head, googly eyes,
## stubby limbs and a silly hat. Animated procedurally from movement state.
## Faces -Z. Parts are siblings under `body` so the death ragdoll can copy them.

const SKINS := [Color(1.0, 0.85, 0.7), Color(0.93, 0.72, 0.55), Color(0.75, 0.55, 0.4), Color(0.5, 0.36, 0.26), Color(1.0, 0.8, 0.55)]
const SKIN_NAMES := ["Peach", "Tan", "Caramel", "Cocoa", "Honey"]
const HAT_NAMES := ["Hair tuft", "Party cone", "Top hat", "Propeller beanie", "Antenna", "Horns", "Bucket", "Pumpkin head", "Witch hat", "Baseball cap", "Crown", "Chef hat", "Viking helmet", "Captain's dome", "Aviator cap"]
const HAT_COUNT := 15
## Hats players can pick (and random hats); the ones after are reserved for special bots.
const PLAYER_HATS := 13
const HAT_CAPTAIN := 13
const HAT_AVIATOR := 14 # Noor's

## Characters: the classic Yeet (hats, extras, skins, shirts) or Noor Yeet (designed by Noor:
## golden, floppy-eared, aviator cap and goggles, harness, utility belt and smiley badge).
const CHARACTER_NAMES := ["Classic Yeet", "Noor Yeet"]
const NOOR := 1
const NOOR_GOLD := Color(0.95, 0.66, 0.28)
const LEATHER := Color(0.4, 0.24, 0.13)
const LEATHER_DARK := Color(0.22, 0.13, 0.08)
const SPOOKY_HATS := [7, 8] # Halloween costumes
## Head attachments, worn together with any hat (except the pumpkin head, which covers the face).
const FACE_NAMES := ["Nothing", "Round glasses", "Shades", "Mustache", "Clown nose", "Headphones", "Bow", "Monocle", "Eyepatch"]
## Outfits over the torso (special bots only). The shirt colour (team colour in team modes)
## always shows.
const OUTFIT_NAMES := ["Shirt", "Captain's tunic"]

## Expressive faces: eye openness, pupil size, brow height and tilt (+ = angry, - = worried),
## mouth scale and drop, cheek puff. "Classic" faces (expressive = false) never change.
const MOODS := {
	"neutral": {"eye": 1.0, "pupil": 1.0, "brow_y": 0.0, "brow_tilt": 0.0, "mouth": Vector3(1.4, 0.55, 0.5), "mouth_y": 0.0, "cheek": 1.0},
	"happy": {"eye": 1.0, "pupil": 1.15, "brow_y": 0.03, "brow_tilt": -0.1, "mouth": Vector3(2.1, 0.55, 0.5), "mouth_y": -0.01, "cheek": 1.3},
	"grin": {"eye": 0.85, "pupil": 1.2, "brow_y": 0.05, "brow_tilt": -0.15, "mouth": Vector3(2.5, 1.0, 0.55), "mouth_y": -0.025, "cheek": 1.45},
	"angry": {"eye": 0.55, "pupil": 0.9, "brow_y": -0.035, "brow_tilt": 0.5, "mouth": Vector3(1.5, 0.2, 0.5), "mouth_y": 0.0, "cheek": 0.8},
	"focused": {"eye": 0.75, "pupil": 0.9, "brow_y": -0.015, "brow_tilt": 0.2, "mouth": Vector3(1.1, 0.35, 0.5), "mouth_y": 0.0, "cheek": 1.0},
	"scared": {"eye": 1.3, "pupil": 0.6, "brow_y": 0.07, "brow_tilt": -0.45, "mouth": Vector3(0.9, 1.2, 0.55), "mouth_y": -0.02, "cheek": 0.9},
	"dizzy": {"eye": 1.1, "pupil": 0.8, "brow_y": 0.03, "brow_tilt": -0.3, "mouth": Vector3(1.2, 0.8, 0.5), "mouth_y": -0.01, "cheek": 1.0},
	"ouch": {"eye": 0.1, "pupil": 1.0, "brow_y": -0.02, "brow_tilt": 0.4, "mouth": Vector3(1.3, 1.0, 0.55), "mouth_y": -0.02, "cheek": 1.1},
	"gasp": {"eye": 0.85, "pupil": 0.8, "brow_y": 0.04, "brow_tilt": -0.2, "mouth": Vector3(0.6, 0.6, 0.6), "mouth_y": 0.0, "cheek": 1.7},
	"dead": {"eye": 0.0, "pupil": 1.0, "brow_y": 0.0, "brow_tilt": -0.2, "mouth": Vector3(1.2, 0.3, 0.5), "mouth_y": 0.0, "cheek": 0.7},
}

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
## Colours of this character (first-person hands use them).
var skin_color := Color(1.0, 0.85, 0.7)
var arm_color := Color.WHITE
## Which character (CHARACTER_NAMES) this model is.
var character := 0
## The face it relaxes into (Noor's is a happy grin).
var idle_mood := "neutral"
## The meshes of the hat and of the head extra (children of the head), e.g. for exporting.
var hat_nodes: Array[Node3D] = []
var face_nodes: Array[Node3D] = []
var outfit_nodes: Array[Node3D] = []
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
## Expressive faces (blinks, moods, eyes that look at things). Set before setup().
var expressive := true
## Mood the owner holds while something lasts (charging a throw, holding, underwater).
var base_mood := ""
## World point the eyes look at (INF: just ahead).
var look_target := Vector3.INF
var _eyes: Array[MeshInstance3D] = []
var _brows: Array[MeshInstance3D] = []
var _x_eyes: Array[Node3D] = []
var _cheeks: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _mood := "neutral"
var _mood_until := 0.0
var _face := {}
var _blink := 0.0
var _next_blink := 2.0
var _look_off := Vector2.ZERO


## A random everyday hat (or, in spooky mode, mostly Halloween costumes).
static func random_hat(rng: RandomNumberGenerator, spooky: bool) -> int:
	if spooky and rng.randf() < 0.75:
		return SPOOKY_HATS[rng.randi() % SPOOKY_HATS.size()]
	var hat := rng.randi() % PLAYER_HATS
	while hat in SPOOKY_HATS:
		hat = rng.randi() % PLAYER_HATS
	return hat


## skin_index < 0 picks a skin tone from the seed. face: index into FACE_NAMES,
## outfit: index into OUTFIT_NAMES, p_character: index into CHARACTER_NAMES. Noor keeps her
## own look (body, cap, gear); the shirt colour becomes her scarf, so teams stay readable.
func setup(shirt: Color, hat: int, seed_value: int, face := 0, skin_index := -1, outfit := 0, p_character := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	if skin_index >= 0:
		skin = SKINS[skin_index % SKINS.size()]
	character = p_character
	var scarf := shirt
	var noor := character == NOOR
	if noor:
		skin = NOOR_GOLD
		shirt = NOOR_GOLD # her body is golden all over
		hat = HAT_AVIATOR
		outfit = 0
		idle_mood = "happy"
	skin_color = skin
	arm_color = shirt
	var pants := Color(0.2, 0.22, 0.35).lerp(shirt.darkened(0.6), 0.3) if not noor else NOOR_GOLD.darkened(0.06)
	var shoe := Color(0.95, 0.95, 0.95) if not noor else LEATHER_DARK

	body = Node3D.new()
	body.position.y = 0.9
	add_child(body)

	var torso := _part("torso", Vector3(0, 0.05, 0))
	_capsule(torso, 0.34, 0.95, shirt, Vector3.ZERO)
	# Belly patch + belt for a clear silhouette.
	_sphere(torso, 0.27, shirt.lightened(0.35 if not noor else 0.15), Vector3(0, -0.05, -0.12), Vector3(1, 1.1, 0.6))
	if not noor:
		_cyl(torso, 0.345, 0.08, pants.darkened(0.2), Vector3(0, -0.28, 0))
	var n_torso := torso.get_child_count()
	if noor:
		_noor_gear(torso, scarf)
	if outfit == 1:
		# Captain's tunic: dark shoulders and collar over the shirt colour, a gold badge.
		var dark := Color(0.12, 0.12, 0.15)
		_sphere(torso, 0.355, dark, Vector3(0, 0.2, 0), Vector3(1.0, 0.55, 1.0))
		_cyl(torso, 0.2, 0.06, dark, Vector3(0, 0.44, 0))
		var badge := _box(torso, Vector3(0.09, 0.11, 0.03), Color(1.0, 0.8, 0.25), Vector3(-0.15, 0.13, -0.33))
		badge.material_override = Mats.plastic(Color(1.0, 0.8, 0.25), 0.15)
		badge.rotation.z = 0.785
	for i in range(n_torso, torso.get_child_count()):
		outfit_nodes.append(torso.get_child(i))

	var head := _part("head", Vector3(0, 0.65, 0))
	_sphere(head, 0.36, skin, Vector3.ZERO, Vector3.ONE).material_override = Mats.skin(skin)
	if noor:
		# Long floppy ears hanging from under the cap.
		for sx in [-1, 1]:
			var ear := _sphere(head, 0.14, skin, Vector3(sx * 0.42, -0.14, 0.02), Vector3(0.6, 2.2, 1.0))
			ear.material_override = Mats.skin(skin)
			ear.rotation.z = sx * 0.6 # flaring out
			ear.rotation.x = -0.2
	for sx in [-1, 1]:
		# (Noor's eyes are bigger and closer; their fronts stay where the pupils sit.)
		var er := 0.143 if noor else 0.125
		_eyes.append(_sphere(head, er, Color.WHITE, Vector3(sx * 0.13, 0.07, -0.415 + er), Vector3.ONE))
		var pupil := _sphere(head, 0.06, Color(0.05, 0.05, 0.08), Vector3(sx * 0.13, 0.07, -0.4), Vector3(1, 1, 0.5))
		_pupils.append(pupil)
		_cheeks.append(_sphere(head, 0.07, Color(1.0, 0.5, 0.55), Vector3(sx * 0.22, -0.08, -0.26), Vector3(1, 0.6, 0.4)))
	_mouth = _sphere(head, 0.08, Color(0.35, 0.1, 0.12), Vector3(0, -0.15, -0.31), Vector3(1.4, 0.55, 0.5))
	if expressive and hat % HAT_COUNT != 7:
		_build_expression_parts(head, skin)
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
		if noor: # leather wrist cuffs
			_cyl(arm, 0.112, 0.09, LEATHER, Vector3(0, -0.42, 0))
		var leg := _part("leg_l" if sx < 0 else "leg_r", Vector3(sx * 0.16, -0.35, 0))
		_capsule(leg, 0.12, 0.62, pants, Vector3(0, -0.25, 0))
		if noor: # chunky boots with a cuff
			_box(leg, Vector3(0.27, 0.18, 0.4), shoe, Vector3(0, -0.5, -0.07))
			_cyl(leg, 0.14, 0.12, LEATHER, Vector3(0, -0.4, 0))
		else:
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
		13: # Captain's dome: bald on top, a short grey fringe around the back and sides.
			var grey := Color(0.72, 0.72, 0.74)
			for i in 9:
				var a := deg_to_rad(-110.0 + i * 27.5) # from one ear, round the back, to the other
				var tuft := _sphere(head, 0.075, grey, Vector3(sin(a) * 0.33, -0.01, cos(a) * 0.33), Vector3(1.0, 0.75, 0.7))
				tuft.rotation.y = a
		14: # Aviator cap (Noor): a leather cap tilted back, goggles up on the forehead.
			var cap := SphereMesh.new()
			cap.radius = 0.385
			cap.height = 0.385
			cap.is_hemisphere = true
			var dome := _mesh(head, cap, LEATHER, Vector3(0, 0.04, 0.0), Vector3(1.0, 0.95, 1.0))
			dome.rotation.x = 0.4
			dome.material_override = Mats.plastic(LEATHER, 0.65)
			var rim := TorusMesh.new()
			rim.inner_radius = 0.36
			rim.outer_radius = 0.4
			var r := _mesh(head, rim, LEATHER_DARK, Vector3(0, 0.04, 0.0))
			r.rotation.x = 0.4
			# The goggles' strap hugs the cap (same tilt, where the dome is 0.34 across).
			var strap := TorusMesh.new()
			strap.inner_radius = 0.338
			strap.outer_radius = 0.37
			var s := _mesh(head, strap, LEATHER_DARK, Vector3(0, 0.206, 0.07))
			s.rotation.x = 0.4
			for sx in [-1, 1]:
				var frame := _cyl(head, 0.1, 0.08, Color(0.55, 0.42, 0.25), Vector3(sx * 0.12, 0.33, -0.235))
				frame.rotation.x = PI * 0.5 - 0.7
				frame.material_override = Mats.plastic(Color(0.55, 0.42, 0.25), 0.3)
				var lens := _cyl(head, 0.077, 0.085, Color(0.55, 0.85, 0.95), Vector3(sx * 0.12, 0.33, -0.235))
				lens.rotation.x = PI * 0.5 - 0.7
				lens.material_override = Mats.plastic(Color(0.55, 0.85, 0.95), 0.05, 0.25)
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


## Noor's gear on the torso: scarf (team colour), crossed harness straps, utility belt with
## buckle and pouches, and her signature smiley badge.
func _noor_gear(torso: Node3D, scarf: Color) -> void:
	var neck := TorusMesh.new()
	neck.inner_radius = 0.15
	neck.outer_radius = 0.25
	_mesh(torso, neck, scarf, Vector3(0, 0.43, 0), Vector3(1, 1.3, 1))
	_sphere(torso, 0.07, scarf.darkened(0.15), Vector3(0.1, 0.38, -0.25), Vector3(1, 0.8, 0.8))
	for side in [-1.0, 1.0]: # front and back
		for sx in [-1, 1]:
			var strap := _box(torso, Vector3(0.065, 0.78, 0.035), LEATHER, Vector3(0, 0.07, side * 0.33))
			strap.rotation.z = sx * 0.5
	_cyl(torso, 0.352, 0.1, LEATHER_DARK, Vector3(0, -0.28, 0))
	var buckle := _box(torso, Vector3(0.13, 0.11, 0.03), Color(0.85, 0.65, 0.3), Vector3(0, -0.28, -0.355))
	buckle.material_override = Mats.plastic(Color(0.85, 0.65, 0.3), 0.2)
	for p in [Vector3(-0.24, -0.3, -0.27), Vector3(0.25, -0.3, -0.26), Vector3(0.35, -0.3, 0.02), Vector3(-0.35, -0.3, 0.05)]:
		var pouch := _box(torso, Vector3(0.13, 0.14, 0.09), LEATHER, p)
		pouch.rotation.y = -atan2(p.x, -p.z)
	var badge := _cyl(torso, 0.08, 0.025, Color(1.0, 0.82, 0.15), Vector3(-0.13, 0.18, -0.325))
	badge.rotation.x = PI * 0.5
	badge.material_override = Mats.plastic(Color(1.0, 0.82, 0.15), 0.2, 0.15)
	for sx in [-1, 1]:
		_sphere(torso, 0.012, Color(0.1, 0.07, 0.04), Vector3(-0.13 + sx * 0.025, 0.2, -0.34), Vector3(1, 1.4, 0.6))
	for k in 5: # a curved smile of little dots
		var a := (k - 2) * 0.35
		_sphere(torso, 0.009, Color(0.1, 0.07, 0.04), Vector3(-0.13 + sin(a) * 0.04, 0.175 - cos(a) * 0.035, -0.34), Vector3(1, 1, 0.6))


## Brows and the knocked-out X eyes (expressive faces only).
func _build_expression_parts(head: Node3D, skin: Color) -> void:
	var brow_col := skin.darkened(0.62)
	for sx in [-1, 1]:
		var brow := _capsule(head, 0.022, 0.13, brow_col, Vector3(sx * 0.13, 0.225, -0.305))
		brow.rotation.z = PI * 0.5
		_brows.append(brow)
		var x := Node3D.new()
		x.position = Vector3(sx * 0.13, 0.07, -0.4)
		x.visible = false
		head.add_child(x)
		for a in [0.78, -0.78]:
			var bar := _box(x, Vector3(0.16, 0.03, 0.02), Color(0.08, 0.06, 0.08), Vector3.ZERO)
			bar.rotation.z = a
		_x_eyes.append(x)
	_face = MOODS[idle_mood].duplicate()
	_next_blink = randf_range(1.0, 4.0)


## Back to a normal face (respawn).
func reset_mood() -> void:
	_mood = "neutral"
	_mood_until = 0.0


## A short reaction (grin after a kill, ouch when hit); returns to normal after duration.
func react(mood: String, duration: float) -> void:
	if not expressive or not MOODS.has(mood):
		return
	_mood = mood
	_mood_until = _time + duration


## Jumps straight to a mood with no easing (the corpse copies the face as it is).
func snap_mood(mood: String) -> void:
	if not expressive or _face.is_empty() or not MOODS.has(mood):
		return
	react(mood, 1000.0)
	_face = MOODS[mood].duplicate()
	_blink = 0.0
	_apply_face(Vector2.ZERO)


func _update_face(delta: float, ragdoll: bool, falling: float, sliding: bool) -> void:
	if _face.is_empty():
		return
	# Who wins: a reaction, then being thrown about, then what the owner is doing.
	var mood := idle_mood
	if _time < _mood_until:
		mood = _mood
	elif ragdoll:
		mood = "dizzy"
	elif falling > 0.6:
		mood = "scared"
	elif base_mood != "":
		mood = base_mood
	elif sliding:
		mood = "happy"
	var target: Dictionary = MOODS[mood]
	var k := 1.0 - exp(-14.0 * delta)
	for key in target:
		_face[key] = lerp(_face[key], target[key], k)
	# Blinks every few seconds (not while squeezing the eyes shut anyway).
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.13
		_next_blink = randf_range(2.0, 5.0) if randf() > 0.15 else 0.25 # sometimes a double blink
	_blink = maxf(_blink - delta, 0.0)
	# Pupils glance toward what the character looks at; dizzy ones spin.
	var want := Vector2.ZERO
	if look_target != Vector3.INF and parts.has("head"):
		var local := (parts.head as Node3D).global_transform.affine_inverse() * look_target
		if local.z < 0.0:
			want = Vector2(local.x, local.y).limit_length(-local.z) / maxf(-local.z, 0.5) * 0.045
	if mood == "dizzy":
		want = Vector2(cos(_time * 9.0), sin(_time * 9.0)) * 0.035
	_look_off = _look_off.lerp(want.limit_length(0.05), 1.0 - exp(-10.0 * delta))
	_apply_face(_look_off)


func _apply_face(look: Vector2) -> void:
	var open: float = _face.eye * (0.08 if _blink > 0.0 else 1.0)
	var dead := _mood == "dead" and _time < _mood_until
	for i in _eyes.size():
		var sx := -1.0 if i == 0 else 1.0
		_eyes[i].scale = Vector3(1.0 + (_face.eye - 1.0) * 0.3, maxf(open, 0.06), 1.0)
		_eyes[i].visible = not dead
		if i < _x_eyes.size():
			_x_eyes[i].visible = dead
		if i < _pupils.size():
			var pupil := _pupils[i]
			var ps: float = _face.pupil
			pupil.scale = Vector3(ps, ps * clampf(open, 0.0, 1.0), 0.5)
			pupil.visible = open > 0.15 and not dead
			pupil.position = Vector3(sx * 0.13 + _pupil_off.x + look.x, 0.07 + (_pupil_off.y + look.y) * clampf(open, 0.0, 1.0), -0.4)
		if i < _brows.size():
			var brow := _brows[i]
			brow.position = Vector3(sx * 0.13, 0.225 + _face.brow_y + (open - 1.0) * 0.03, -0.305)
			brow.rotation.x = 0.0
			brow.rotation.z = PI * 0.5 + sx * _face.brow_tilt
		if i < _cheeks.size():
			_cheeks[i].scale = Vector3(1, 0.6, 0.4) * _face.cheek
	if _mouth:
		_mouth.scale = _face.mouth
		_mouth.position = Vector3(0, -0.15 + _face.mouth_y, -0.31)


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
	if _face.is_empty():
		for i in _pupils.size():
			var sx := -1.0 if i == 0 else 1.0
			_pupils[i].position = Vector3(sx * 0.13 + _pupil_off.x, 0.07 + _pupil_off.y, -0.4)
	else:
		_update_face(delta, ragdoll, clampf(-vel.y / 20.0, 0.0, 1.0) if not grounded else 0.0, sliding)
	if _propeller:
		_propeller.rotate_y(delta * (6.0 + hspeed * 2.0 + maxf(-vel.y, 0.0) * 3.0))
