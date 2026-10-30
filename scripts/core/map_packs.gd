class_name MapPacks
extends RefCounted
## Custom maps from map packs: .zip files (exported from the Map Kit project, see
## custom/README.md) in a "maps" folder next to the game, or in the user data folder
## (user://maps). Each pack holds maps under res://custom/<map name>/ with their own
## textures, materials, models and sounds. Packs are mounted at start; they can't replace
## the game's own files.
##
## Safety: before mounting, the zip's contents are checked. A pack with scripts of its own
## (script files that aren't the game's, or scripts embedded in its scenes) runs code on
## your computer: it isn't mounted until you allow it (Play page; remembered per pack).
## Native code (.dll, .so, .gdextension...) is never loaded.

const CUSTOM_DIR := "res://custom"
const SCRIPT_EXT := ["gd", "gdc", "gde", "cs"]
const NATIVE_EXT := ["dll", "so", "dylib", "gdextension", "framework", "exe"]
const SCENE_EXT := ["tscn", "scn", "tres", "res"]

## Every pack found: {path, name, size, scripts, native, mounted, error}
static var packs: Array[Dictionary] = []


## Where packs are looked for (plus --map-packs <dir> for tests).
static func folders() -> PackedStringArray:
	var out := PackedStringArray()
	if not OS.has_feature("editor"):
		out.append(OS.get_executable_path().get_base_dir().path_join("maps"))
	out.append(ProjectSettings.globalize_path("user://maps"))
	var args := OS.get_cmdline_user_args()
	var i := args.find("--map-packs")
	if i >= 0 and i + 1 < args.size():
		out.append(args[i + 1])
	return out


## Finds the packs, checks them, mounts the safe ones and the trusted ones.
static func scan_and_mount(trusted: Dictionary) -> void:
	packs.clear()
	# --allow-pack-scripts: this run allows every pack's scripts (servers, tests; not saved).
	var allow_all := "--allow-pack-scripts" in OS.get_cmdline_user_args()
	for dir_path in folders():
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.get_extension().to_lower() != "zip":
				continue
			var info := inspect(dir_path.path_join(f))
			if info.error == "" and not info.native and (not info.scripts or allow_all or trusted.has(key(info))):
				info.mounted = ProjectSettings.load_resource_pack(info.path, false)
				if not info.mounted:
					info.error = "could not be loaded"
			packs.append(info)
			print("Map pack %s: %s" % [info.name, "loaded" if info.mounted else (info.error if info.error != "" else ("native code: refused" if info.native else "has scripts: waiting to be allowed"))])


## What's in a pack (without loading it).
static func inspect(path: String) -> Dictionary:
	var info := {"path": path, "name": path.get_file().get_basename(), "size": 0, "scripts": false, "native": false, "mounted": false, "error": "", "maps": PackedStringArray()}
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa:
		info.size = fa.get_length()
		fa.close()
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		info.error = "not a valid zip"
		return info
	var maps := PackedStringArray() # (packed arrays are values: filled here, stored at the end)
	for f: String in zip.get_files():
		var ext := f.get_extension().to_lower()
		var res := "res://" + f.trim_prefix("res://")
		if ext in NATIVE_EXT:
			info.native = true
		elif ext in SCRIPT_EXT and not ResourceLoader.exists(res.trim_suffix(".remap")) and not FileAccess.file_exists(res):
			info.scripts = true # a script the game doesn't have
		elif ext in SCENE_EXT: # (exported scenes live in .godot/exported/, remapped from custom/)
			var data := zip.read_file(f)
			# Scripts written into the scene itself (text or binary, the type name is there).
			if _contains(data, "GDScript".to_utf8_buffer()) or _contains(data, "CSharpScript".to_utf8_buffer()):
				info.scripts = true
		if f.begins_with("custom/") and (f.ends_with(".tscn") or f.ends_with(".scn") or f.ends_with(".tscn.remap") or f.ends_with(".scn.remap")):
			maps.append("res://" + f.trim_suffix(".remap"))
	zip.close()
	info.maps = maps
	return info


static func _contains(data: PackedByteArray, needle: PackedByteArray) -> bool:
	var n := needle.size()
	if n == 0 or data.size() < n:
		return false
	var first := needle[0]
	var i := data.find(first)
	while i >= 0 and i + n <= data.size():
		if data.slice(i, i + n) == needle:
			return true
		i = data.find(first, i + 1)
	return false


## How a pack is remembered when allowed: its file name and size (a changed pack asks again).
static func key(info: Dictionary) -> String:
	return "%s:%d" % [info.path.get_file(), info.size]


## Packs with scripts that haven't been allowed yet.
static func waiting() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in packs:
		if p.scripts and not p.native and not p.mounted and p.error == "":
			out.append(p)
	return out


## Allows a pack with scripts and loads it now.
static func allow(info: Dictionary) -> bool:
	info.mounted = ProjectSettings.load_resource_pack(info.path, false)
	return info.mounted


## Custom maps available now: every scene in res://custom/<map>/ (packs mounted, and the
## Map Kit project's own work in progress when run from the editor).
static func custom_maps() -> PackedStringArray:
	var out := PackedStringArray()
	var root := DirAccess.open(CUSTOM_DIR)
	if root == null:
		return out
	for sub in root.get_directories():
		var dir := DirAccess.open(CUSTOM_DIR.path_join(sub))
		if dir == null:
			continue
		for f in dir.get_files():
			f = f.trim_suffix(".remap")
			if (f.ends_with(".tscn") or f.ends_with(".scn")) and not out.has(CUSTOM_DIR.path_join(sub).path_join(f)):
				out.append(CUSTOM_DIR.path_join(sub).path_join(f))
	out.sort()
	return out


## The pack a custom map comes from (its folder name), for messages.
static func pack_of(map_path: String) -> String:
	return map_path.trim_prefix(CUSTOM_DIR + "/").get_slice("/", 0)
