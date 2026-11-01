extends SceneTree
## Makes the starter models for "Make your own versions" (docs/MAPPING.md): simple models
## with their markers already named and placed, as .glb files to open in Blender (File >
## Import > glTF) and make your own from. Writes custom/make_your_own/models/:
## - pipe.glb: a pipe out of a wall (the wall is the model's origin, the pipe comes out along
##   +Z): "Spout" at its mouth, pointing out and a little down; "Wheel" (its valve) on top.
## - drain.glb: a floor basin with a plughole off to one side: "Intake" over the hole.
## - thorns.glb: a 4 x 4 m bed of thorns for a trap spot (its origin in the middle, on the
##   ground).
## - drum.glb: an oil drum (origin in its middle) and its "Collision" mesh: a plain
##   8-sided cylinder, what it bumps with.
## - fan.glb: a big fan for a PuzzleFan (origin in its middle, blowing toward -Z): "Rotor", the
##   blades, turns about its own Z.
## - flag_stand.glb: a stone plinth for a FlagStand (origin on the floor; the flag sits 0.4 m up).
## - can.glb: an energy drink for a PickupSpawn's own pickup (origin in its middle).
## - crane.glb: a small crane (8 m to its turret, a 10 m jib) for a Crane: "Turret" slews, its
##   jib along the Turret's +X; "Hook", at the jib's end, is where the cable hangs.
## - crate_load.glb: what the crane carries (a 3 x 1.5 x 1.5 m crate, origin in its middle).
## - ladder.glb: a 4 m wooden ladder for a Ladder (origin at its foot, the wall behind at -Z).
## - bell.glb: a bell on a post for a Horn: "Lever", its handle, is pulled.
## - window.glb, door.glb, fence.glb: for a BreakableModel, each part named for what it's made
##   of ("Glass_", "Wood_", "Metal_"), the parts that never break "Fixed_": a window (a fixed
##   frame, two panes, a wooden mullion and bar), a door of planks (a fixed frame, five planks,
##   two braces, a metal knob that comes off whole), a fence (posts and rails).
## - cabinet.glb: a glass-fronted cabinet for a PropType that Breaks Into Its Parts (origin in
##   its middle): its boards ("Wood_"), a glass door ("Glass_"), a metal handle ("Metal_").
## And ../textures/bricks.png, a brick texture for a breakable wall's Custom Material.
## Usage: godot --headless --path . --script res://tools/make_templates.gd

const OUT := "res://custom/make_your_own/models/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save(_pipe(), "pipe")
	_save(_drain(), "drain")
	_save(_thorns(), "thorns")
	_save(_drum(), "drum")
	_save(_fan(), "fan")
	_save(_flag_stand(), "flag_stand")
	_save(_can(), "can")
	_save(_crane(), "crane")
	_save(_crate_load(), "crate_load")
	_save(_ladder(), "ladder")
	_save(_bell(), "bell")
	_save(_window(), "window")
	_save(_door(), "door")
	_save(_fence(), "fence")
	_save(_cabinet(), "cabinet")
	_bricks()
	quit()


func _save(root: Node3D, file: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, OUT + file + ".glb")
	print("%s.glb: %s" % [file, "ok" if err == OK else error_string(err)])
	root.free()


func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(parent: Node3D, n: String, mesh: Mesh, mat: Material, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


func _cyl(r: float, h: float, sides := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = sides
	return c


func _marker(parent: Node3D, n: String, at: Vector3, points: Vector3) -> void:
	var m := Node3D.new()
	m.name = n
	var y := points.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	m.transform = Transform3D(Basis(x, y, x.cross(y)), at)
	parent.add_child(m)


func _pipe() -> Node3D:
	var root := Node3D.new()
	root.name = "Pipe"
	var iron := _mat(Color(0.42, 0.45, 0.5), 0.4, 0.6)
	var rust := _mat(Color(0.55, 0.3, 0.18), 0.8)
	var along_z := Basis(Vector3.RIGHT, PI * 0.5) # (a cylinder's axis turned from Y to Z)
	_mesh(root, "Flange", _cyl(0.4, 0.1), rust, Transform3D(along_z, Vector3(0, 0, 0.05)))
	_mesh(root, "Pipe", _cyl(0.18, 0.8), iron, Transform3D(along_z, Vector3(0, 0, 0.5)))
	_mesh(root, "Lip", _cyl(0.24, 0.1), rust, Transform3D(along_z, Vector3(0, 0, 0.88)))
	# The valve: a stem and a wheel on top (the Wheel turns about its own Z: here, upright).
	_mesh(root, "Stem", _cyl(0.04, 0.3), iron, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0.45)))
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.46, 0.45))
	root.add_child(wheel)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.24
	var red := _mat(Color(0.85, 0.15, 0.12), 0.5)
	_mesh(wheel, "Rim", ring, red, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	for i in 2:
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.42, 0.04, 0.04)
		_mesh(wheel, "Spoke%d" % i, spoke, red, Transform3D(Basis(Vector3.BACK, PI * 0.5 * i), Vector3.ZERO))
	# Where the water comes out: the pipe's mouth, pointing out of the wall and a bit down.
	_marker(root, "Spout", Vector3(0, -0.05, 0.95), Vector3(0, -0.25, 1))
	return root


func _drain() -> Node3D:
	var root := Node3D.new()
	root.name = "Drain"
	var stone := _mat(Color(0.55, 0.55, 0.58), 0.9)
	var dark := _mat(Color(0.08, 0.08, 0.1), 0.9)
	var iron := _mat(Color(0.3, 0.32, 0.36), 0.5, 0.6)
	for s in [-1, 1]:
		var side := BoxMesh.new()
		side.size = Vector3(2.0, 0.12, 0.2)
		_mesh(root, "RimX%d" % (s + 1), side, stone, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, s * 0.9)))
		var end := BoxMesh.new()
		end.size = Vector3(0.2, 0.12, 1.6)
		_mesh(root, "RimZ%d" % (s + 1), end, stone, Transform3D(Basis.IDENTITY, Vector3(s * 0.9, 0.06, 0)))
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(1.6, 0.02, 1.6)
	_mesh(root, "Basin", floor_mesh, stone, Transform3D(Basis.IDENTITY, Vector3(0, 0.01, 0)))
	_mesh(root, "Hole", _cyl(0.22, 0.03), dark, Transform3D(Basis.IDENTITY, Vector3(0.5, 0.02, 0.5)))
	for i in 3:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.44, 0.03, 0.05)
		_mesh(root, "Bar%d" % i, bar, iron, Transform3D(Basis.IDENTITY, Vector3(0.5, 0.04, 0.38 + i * 0.12)))
	# Where the water goes in: over the plughole.
	_marker(root, "Intake", Vector3(0.5, 0.05, 0.5), Vector3.UP)
	return root


func _thorns() -> Node3D:
	var root := Node3D.new()
	root.name = "Thorns"
	var soil := _mat(Color(0.3, 0.22, 0.14), 0.95)
	var bark := _mat(Color(0.35, 0.25, 0.12), 0.8)
	var thorn := _mat(Color(0.75, 0.7, 0.55), 0.5)
	var bed := BoxMesh.new()
	bed.size = Vector3(4, 0.12, 4)
	_mesh(root, "Bed", bed, soil, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var at := Vector3(-1.4 + (i % 3) * 1.4 + rng.randf_range(-0.3, 0.3), 0.12, -1.4 + (i / 3) * 1.4 + rng.randf_range(-0.3, 0.3))
		var branch := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(1.1, 1.4))
		_mesh(root, "Branch%d" % i, _cyl(0.05, 1.2, 6), bark, Transform3D(branch, at + branch.y * 0.6))
		for k in 4:
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.035
			spike.height = 0.28
			spike.radial_segments = 4
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.9))
			_mesh(root, "Thorn%d_%d" % [i, k], spike, thorn, Transform3D(b, at + branch.y * (0.25 + k * 0.25) + b.y * 0.14))
	return root


func _drum() -> Node3D:
	var root := Node3D.new()
	root.name = "Drum"
	var paint := _mat(Color(0.15, 0.45, 0.25), 0.45, 0.3)
	var steel := _mat(Color(0.6, 0.62, 0.66), 0.35, 0.8)
	_mesh(root, "Body", _cyl(0.42, 1.15, 20), paint)
	for y in [-0.5, -0.15, 0.15, 0.5]:
		var rib := TorusMesh.new()
		rib.inner_radius = 0.41
		rib.outer_radius = 0.45
		_mesh(root, "Rib", rib, steel, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
	_mesh(root, "Cap", _cyl(0.07, 0.04), steel, Transform3D(Basis.IDENTITY, Vector3(0.22, 0.59, 0)))
	# What it bumps with (hidden in the game): keep it simple.
	_mesh(root, "Collision", _cyl(0.43, 1.15, 8), _mat(Color(1, 0, 1)))
	return root


func _fan() -> Node3D:
	var root := Node3D.new()
	root.name = "Fan"
	var wood := _mat(Color(0.55, 0.38, 0.22), 0.8)
	var brass := _mat(Color(0.85, 0.65, 0.3), 0.35, 0.8)
	var base := BoxMesh.new()
	base.size = Vector3(1.2, 0.14, 0.8)
	_mesh(root, "Base", base, wood, Transform3D(Basis.IDENTITY, Vector3(0, -0.78, 0)))
	_mesh(root, "Post", _cyl(0.07, 0.75, 8), wood, Transform3D(Basis.IDENTITY, Vector3(0, -0.35, 0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.66
	ring.outer_radius = 0.74
	_mesh(root, "Cage", ring, brass, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.2, 0)))
	# The blades: in the fan's face, turning about the Rotor's own Z (the way it blows).
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 0.2, 0)
	root.add_child(rotor)
	_mesh(rotor, "Hub", _cyl(0.1, 0.12), brass, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	for i in 4:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.18, 0.62, 0.03)
		var b := Basis(Vector3.BACK, TAU * i / 4.0) * Basis(Vector3.UP, 0.4)
		_mesh(rotor, "Blade%d" % i, blade, wood, Transform3D(b, Basis(Vector3.BACK, TAU * i / 4.0) * Vector3(0, 0.36, 0)))
	return root


func _flag_stand() -> Node3D:
	var root := Node3D.new()
	root.name = "FlagStand"
	var stone := _mat(Color(0.62, 0.6, 0.56), 0.9)
	var moss := _mat(Color(0.3, 0.45, 0.22), 0.95)
	var plinth := CylinderMesh.new()
	plinth.top_radius = 1.2
	plinth.bottom_radius = 1.45
	plinth.height = 0.4
	plinth.radial_segments = 8
	_mesh(root, "Plinth", plinth, stone, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)))
	_mesh(root, "Moss", _cyl(1.0, 0.04, 8), moss, Transform3D(Basis.IDENTITY, Vector3(0, 0.41, 0)))
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var post := BoxMesh.new()
		post.size = Vector3(0.22, 0.9, 0.22)
		_mesh(root, "Post%d" % i, post, stone, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 1.15, 0.45, sin(a) * 1.15)))
	return root


func _can() -> Node3D:
	var root := Node3D.new()
	root.name = "Can"
	var blue := _mat(Color(0.15, 0.55, 1.0), 0.3, 0.6)
	var silver := _mat(Color(0.8, 0.82, 0.86), 0.25, 0.9)
	var bolt := _mat(Color(1.0, 0.9, 0.2), 0.4)
	_mesh(root, "Body", _cyl(0.16, 0.42, 20), blue)
	_mesh(root, "Top", _cyl(0.15, 0.04, 20), silver, Transform3D(Basis.IDENTITY, Vector3(0, 0.23, 0)))
	_mesh(root, "Bottom", _cyl(0.15, 0.04, 20), silver, Transform3D(Basis.IDENTITY, Vector3(0, -0.23, 0)))
	var flash := BoxMesh.new()
	flash.size = Vector3(0.06, 0.22, 0.02)
	_mesh(root, "Bolt", flash, bolt, Transform3D(Basis(Vector3.BACK, 0.4), Vector3(0, 0, 0.16)))
	return root


## A brick texture (256 px: four courses of bricks, mortar between), for a wall's material.
func _bricks() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mortar := Color(0.78, 0.75, 0.68)
	img.fill(mortar)
	for row in 4:
		for col in 3:
			var x0 := col * 96 - (48 if row % 2 == 1 else 0)
			var tint := Color(0.62, 0.27, 0.18).lerp(Color(0.72, 0.36, 0.22), rng.randf())
			for y in range(row * 64 + 4, row * 64 + 60):
				for x in range(x0 + 4, x0 + 92):
					var n := rng.randf_range(-0.05, 0.05)
					img.set_pixel(posmod(x, 256), y, Color(tint.r + n, tint.g + n, tint.b + n))
	DirAccess.make_dir_recursive_absolute("res://custom/make_your_own/textures/")
	var err := img.save_png("res://custom/make_your_own/textures/bricks.png")
	print("bricks.png: %s" % ("ok" if err == OK else error_string(err)))


func _crane() -> Node3D:
	var root := Node3D.new()
	root.name = "Crane"
	var red := _mat(Color(0.75, 0.18, 0.12), 0.6)
	var dark := _mat(Color(0.18, 0.18, 0.2), 0.5)
	_mesh(root, "Tower", _cyl(0.7, 8.0, 8), red, Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0)))
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 8.0, 0)
	root.add_child(turret)
	var cab := BoxMesh.new()
	cab.size = Vector3(2.4, 1.6, 2.0)
	_mesh(turret, "Cab", cab, red, Transform3D(Basis.IDENTITY, Vector3(-0.6, 0.8, 0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(10.0, 0.5, 0.6)
	_mesh(turret, "Jib", arm, red, Transform3D(Basis.IDENTITY, Vector3(5.0, 1.8, 0)))
	var weight := BoxMesh.new()
	weight.size = Vector3(1.2, 1.0, 1.4)
	_mesh(turret, "Counterweight", weight, dark, Transform3D(Basis.IDENTITY, Vector3(-2.6, 1.6, 0)))
	var sheave := BoxMesh.new()
	sheave.size = Vector3(0.5, 0.5, 0.8)
	_mesh(turret, "Sheave", sheave, dark, Transform3D(Basis.IDENTITY, Vector3(9.8, 1.4, 0)))
	_marker(turret, "Hook", Vector3(9.8, 1.15, 0), Vector3.UP)
	return root


func _crate_load() -> Node3D:
	var root := Node3D.new()
	root.name = "CrateLoad"
	var wood := _mat(Color(0.75, 0.55, 0.3), 0.8)
	var band := _mat(Color(0.3, 0.3, 0.32), 0.5, 0.6)
	var body := BoxMesh.new()
	body.size = Vector3(3.0, 1.5, 1.5)
	_mesh(root, "Body", body, wood)
	for x in [-1.2, 0.0, 1.2]:
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 1.54, 1.54)
		_mesh(root, "Band", b, band, Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
	return root


func _ladder() -> Node3D:
	var root := Node3D.new()
	root.name = "WoodLadder"
	var wood := _mat(Color(0.55, 0.38, 0.2), 0.85)
	for s in [-1, 1]:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.1, 4.0, 0.08)
		_mesh(root, "Rail", rail, wood, Transform3D(Basis.IDENTITY, Vector3(s * 0.28, 2.0, 0.12)))
	for i in 11:
		var rung := BoxMesh.new()
		rung.size = Vector3(0.56, 0.06, 0.06)
		_mesh(root, "Rung", rung, wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.3 + i * 0.35, 0.12)))
	return root


func _bell() -> Node3D:
	var root := Node3D.new()
	root.name = "Bell"
	var wood := _mat(Color(0.45, 0.3, 0.18), 0.8)
	var brass := _mat(Color(0.85, 0.65, 0.25), 0.3, 0.9)
	var post := BoxMesh.new()
	post.size = Vector3(0.14, 1.6, 0.14)
	_mesh(root, "Post", post, wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.7, 0.1, 0.1)
	_mesh(root, "Arm", arm, wood, Transform3D(Basis.IDENTITY, Vector3(0.3, 1.6, 0)))
	var bell := CylinderMesh.new()
	bell.top_radius = 0.1
	bell.bottom_radius = 0.24
	bell.height = 0.32
	_mesh(root, "Bell", bell, brass, Transform3D(Basis.IDENTITY, Vector3(0.55, 1.38, 0)))
	# The handle you pull (it turns about its own Z).
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, 1.0, 0.1)
	root.add_child(lever)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.05, 0.4, 0.05)
	_mesh(lever, "Handle", handle, brass, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)))
	var knob := SphereMesh.new()
	knob.radius = 0.06
	knob.height = 0.12
	_mesh(lever, "Knob", knob, brass, Transform3D(Basis.IDENTITY, Vector3(0, 0.42, 0)))
	return root


func _box_part(parent: Node3D, n: String, size: Vector3, at: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(parent, n, b, mat, Transform3D(Basis.IDENTITY, at))


## A window standing on the ground (origin at the sill's middle, in the XY plane).
func _window() -> Node3D:
	var root := Node3D.new()
	root.name = "Window"
	var frame := _mat(Color(0.95, 0.95, 0.92), 0.6)
	var wood := _mat(Color(0.5, 0.33, 0.18), 0.8)
	var glass := _mat(Color(0.7, 0.88, 1.0, 0.35), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box_part(root, "Fixed_FrameBottom", Vector3(1.6, 0.12, 0.16), Vector3(0, 0.06, 0), frame)
	_box_part(root, "Fixed_FrameTop", Vector3(1.6, 0.12, 0.16), Vector3(0, 1.74, 0), frame)
	_box_part(root, "Fixed_FrameLeft", Vector3(0.12, 1.56, 0.16), Vector3(-0.74, 0.9, 0), frame)
	_box_part(root, "Fixed_FrameRight", Vector3(0.12, 1.56, 0.16), Vector3(0.74, 0.9, 0), frame)
	_box_part(root, "Wood_Mullion", Vector3(0.08, 1.56, 0.08), Vector3(0, 0.9, 0), wood)
	_box_part(root, "Wood_Bar", Vector3(1.36, 0.06, 0.06), Vector3(0, 1.1, 0.03), wood)
	_box_part(root, "Glass_PaneLeft", Vector3(0.6, 1.56, 0.02), Vector3(-0.35, 0.9, 0), glass)
	_box_part(root, "Glass_PaneRight", Vector3(0.6, 1.56, 0.02), Vector3(0.35, 0.9, 0), glass)
	return root


## A door of planks in its frame (origin at the threshold's middle, in the XY plane).
func _door() -> Node3D:
	var root := Node3D.new()
	root.name = "Door"
	var frame := _mat(Color(0.3, 0.22, 0.15), 0.8)
	var plank := _mat(Color(0.62, 0.42, 0.22), 0.85)
	var brace := _mat(Color(0.5, 0.33, 0.17), 0.85)
	var iron := _mat(Color(0.25, 0.25, 0.28), 0.4, 0.8)
	_box_part(root, "Fixed_PostLeft", Vector3(0.16, 2.3, 0.2), Vector3(-0.68, 1.15, 0), frame)
	_box_part(root, "Fixed_PostRight", Vector3(0.16, 2.3, 0.2), Vector3(0.68, 1.15, 0), frame)
	_box_part(root, "Fixed_Lintel", Vector3(1.52, 0.16, 0.2), Vector3(0, 2.38, 0), frame)
	for i in 5:
		_box_part(root, "Wood_Plank%d" % i, Vector3(0.235, 2.2, 0.06), Vector3(-0.48 + i * 0.24, 1.12, 0), plank)
	_box_part(root, "Wood_BraceLow", Vector3(1.18, 0.14, 0.05), Vector3(0, 0.5, 0.055), brace)
	_box_part(root, "Wood_BraceHigh", Vector3(1.18, 0.14, 0.05), Vector3(0, 1.75, 0.055), brace)
	var knob := SphereMesh.new()
	knob.radius = 0.05
	knob.height = 0.1
	_mesh(root, "Metal_Knob", knob, iron, Transform3D(Basis.IDENTITY, Vector3(0.38, 1.05, 0.1)))
	return root


## A glass-fronted cabinet, 0.8 x 1.1 x 0.45 m (origin in its middle, the glass toward +Z).
func _cabinet() -> Node3D:
	var root := Node3D.new()
	root.name = "Cabinet"
	var wood := _mat(Color(0.5, 0.32, 0.18), 0.8)
	var back := _mat(Color(0.4, 0.26, 0.15), 0.85)
	var glass := _mat(Color(0.75, 0.88, 0.95, 0.35), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var brass := _mat(Color(0.8, 0.62, 0.25), 0.3, 0.9)
	_box_part(root, "Wood_Top", Vector3(0.8, 0.05, 0.45), Vector3(0, 0.525, 0), wood)
	_box_part(root, "Wood_Bottom", Vector3(0.8, 0.05, 0.45), Vector3(0, -0.525, 0), wood)
	_box_part(root, "Wood_SideLeft", Vector3(0.05, 1.0, 0.45), Vector3(-0.375, 0, 0), wood)
	_box_part(root, "Wood_SideRight", Vector3(0.05, 1.0, 0.45), Vector3(0.375, 0, 0), wood)
	_box_part(root, "Wood_Back", Vector3(0.7, 1.0, 0.03), Vector3(0, 0, -0.21), back)
	_box_part(root, "Wood_Shelf", Vector3(0.7, 0.04, 0.38), Vector3(0, 0, -0.02), wood)
	_box_part(root, "Glass_Door", Vector3(0.68, 0.96, 0.02), Vector3(0, 0, 0.21), glass)
	_box_part(root, "Metal_Handle", Vector3(0.03, 0.16, 0.03), Vector3(0.27, 0, 0.24), brass)
	return root


## Two bays of fence (origin on the ground at its middle, along X).
func _fence() -> Node3D:
	var root := Node3D.new()
	root.name = "Fence"
	var wood := _mat(Color(0.55, 0.4, 0.25), 0.9)
	var rail := _mat(Color(0.65, 0.5, 0.32), 0.9)
	for i in 3:
		_box_part(root, "Wood_Post%d" % i, Vector3(0.14, 1.2, 0.14), Vector3(-2.0 + i * 2.0, 0.6, 0), wood)
	for bay in 2:
		for k in 2:
			_box_part(root, "Wood_Rail%d_%d" % [bay, k], Vector3(1.86, 0.12, 0.05), Vector3(-1.0 + bay * 2.0, 0.45 + k * 0.5, 0.095), rail)
	return root
