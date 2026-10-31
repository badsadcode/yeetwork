class_name CharacterParts
## Character models dropped into folders (no code needed): every .glb / .gltf / .tscn / .scn
## file in
##   assets/characters/hats/      a hat (picked in the menu after the built-in ones)
##   assets/characters/extras/    a head extra (glasses, a mask...)
##   assets/characters/outfits/   an outfit over the torso
##   assets/characters/parts/     replaces a body part's built-in shape: head, torso, arm_l,
##                                arm_r, leg_l or leg_r (the face stays on a new head)
## Model it where it sits on a standing Yeet (art/characters/characters.blend has the body and
## every built-in part in place): the game works out where it attaches. Materials named
## "Shirt" (or "Team") take the player's shirt / team colour, "Skin" their skin tone.
## Names in the menu come from the file names (pirate_hat.glb: "Pirate hat"). They ship with
## the game, so they work online (everyone needs the same build).
## See docs/CHARACTERS.md.

const ROOT := "res://assets/characters/"
const KINDS := ["hats", "extras", "outfits", "parts"]
const BODY_PARTS := ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
const EXTENSIONS := ["glb", "gltf", "tscn", "scn"]

static var _found := {} # kind -> [[name, path], ...] sorted by file name
static var _scenes := {} # path -> PackedScene


## The custom models of a kind ("hats", "extras", "outfits", "parts"): [[name, path], ...].
static func list(kind: String) -> Array:
	if not _found.has(kind):
		_found[kind] = _scan(kind)
	return _found[kind]


static func names(kind: String) -> Array:
	return list(kind).map(func(e): return e[0])


## The model replacing a body part, or "" (parts/head.glb for "head").
static func part_path(part: String) -> String:
	for e in list("parts"):
		if (e[1] as String).get_file().get_basename() == part:
			return e[1]
	return ""


## A new instance of the model at `path` (null if it can't be loaded).
static func instantiate(path: String) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene
	var ps: PackedScene = _scenes[path]
	if ps == null:
		push_warning("Character part %s didn't load" % path)
		return null
	return ps.instantiate() as Node3D


## Forget what was found (the files changed: e.g. a new model while the game runs).
static func rescan() -> void:
	_found.clear()
	_scenes.clear()


static func _scan(kind: String) -> Array:
	var out := []
	var dir := ROOT + kind
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var seen := {}
	for f in DirAccess.get_files_at(dir):
		# (in an exported game the files are listed as name.glb.import / name.tscn.remap)
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension().to_lower() not in EXTENSIONS or seen.has(file):
			continue
		seen[file] = true
		var stem := file.get_basename()
		var pretty := stem.replace("_", " ").replace("-", " ").strip_edges()
		pretty = pretty.substr(0, 1).to_upper() + pretty.substr(1)
		out.append([pretty, dir + "/" + file])
	out.sort_custom(func(a, b): return (a[1] as String).naturalnocasecmp_to(b[1]) < 0)
	return out


## Shirt / team and skin colours onto a custom model's materials (by material name).
static func tint(root: Node, shirt: Color, skin_mat: Material) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m == null:
				continue
			var nm := m.resource_name.to_lower()
			if nm.contains("shirt") or nm.contains("team"):
				var tm := (m.duplicate() if m is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
				tm.albedo_color = shirt
				mi.set_surface_override_material(i, tm)
			elif nm.contains("skin"):
				mi.set_surface_override_material(i, skin_mat)
