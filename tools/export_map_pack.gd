extends SceneTree
## Exports a custom map (everything in res://custom/<map>/: the map scene, its textures,
## materials, models, sounds, scripts) as a map pack: a .zip to put in the game's "maps"
## folder. The game's own pieces (the Map Kit scripts, the built-in assets) stay out: the
## game has them. Usage (or tools/export_map_pack.bat / .sh):
##   godot --headless --path <project> --script res://tools/export_map_pack.gd -- <map folder> [out.zip]
## Without out.zip it goes to build/map_packs/<map folder>.zip.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("Which map? Give the folder name in custom/, e.g.  -- my_map")
		return
	var map_dir: String = args[0].trim_prefix("custom/").trim_prefix("res://custom/").trim_suffix("/")
	var folder := "res://custom/" + map_dir
	if not DirAccess.dir_exists_absolute(folder):
		_fail("No folder %s" % folder)
		return
	var out: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://build/map_packs/%s.zip" % map_dir)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	# Every scene in the folder (sub-folders too), and with them all they use.
	var scenes := PackedStringArray()
	_collect(folder, scenes)
	if scenes.is_empty():
		_fail("No scenes in %s" % folder)
		return
	# The "Map pack" export preset takes this map's scenes.
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		_fail("No export_presets.cfg")
		return
	var section := ""
	for s in cfg.get_sections():
		if cfg.get_value(s, "name", "") == "Map pack":
			section = s
	if section == "":
		_fail("No \"Map pack\" export preset")
		return
	cfg.set_value(section, "export_files", scenes)
	cfg.save("res://export_presets.cfg")
	print("Exporting %d scene(s) of %s to %s" % [scenes.size(), folder, out])
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--export-pack", "Map pack", out], output, true)
	for line in output:
		print(line)
	# Leave the preset as it was (no change in the project after an export).
	cfg.set_value(section, "export_files", PackedStringArray())
	cfg.save("res://export_presets.cfg")
	if code != 0 or not FileAccess.file_exists(out):
		_fail("The export failed (code %d). Export templates for Godot must be installed (Editor > Manage Export Templates)." % code)
		return
	print("MAP PACK READY: %s\nPut it in the game's \"maps\" folder (next to Yeetwork.exe)." % out)
	quit(0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".tscn") or f.ends_with(".scn"):
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(d), out)


func _fail(msg: String) -> void:
	printerr("MAP PACK FAILED: " + msg)
	quit(1)
