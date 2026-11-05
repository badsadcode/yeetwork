extends SceneTree
## Writes the piece pages, docs/pieces/: a page for every Map Kit piece and type file (what it
## is, its settings with their defaults, ranges and choices, the markers your model can have,
## the starter models to begin from, the maps that use it) and an index, README.md. All of it
## comes from the pieces' scripts: their doc comments (## above the class and each setting,
## the same text the Inspector shows as tooltips) and their settings. So to change a page,
## change the script's comments and run this again. It also fills in the tables of the
## walkthroughs (WALKTHROUGHS) from the maps they rebuild: between
## <!-- nodes res://maps/x.tscn under Geometry --> (or "named MapSettings", or
## "script res://scripts/mapkit/pickup_spawn.gd") and <!-- /nodes -->.
## Usage: godot --headless --path . --script res://tools/make_guide.gd
##        ... -- --check: changes nothing; exits 1 if a page is out of date or a setting has no
##        doc comment (CI runs this).

const OUT := "res://docs/pieces/"
const WALKTHROUGHS := ["res://docs/REBUILD_A_MAP.md", "res://docs/MAKE_A_NEW_MAP.md"]
const MAPS := ["res://maps/", "res://custom/make_your_own/", "res://custom/example_garden/", "res://custom/lighthouse_point/"]

## [class, script, group]: the pages, in the index's order.
const PIECES := [
	["MapSettings", "res://scripts/mapkit/map_settings.gd", "The map"],
	["SpawnPoint", "res://scripts/mapkit/spawn_point.gd", "The map"],
	["MapLight", "res://scripts/mapkit/map_light.gd", "The map"],
	["MapTheme", "res://scripts/mapkit/map_theme.gd", "The map"],
	["ArenaBlock", "res://scripts/mapkit/arena_block.gd", "Building"],
	["BreakableSlab", "res://scripts/mapkit/breakable_slab.gd", "Building"],
	["BreakableModel", "res://scripts/mapkit/breakable_model.gd", "Building"],
	["JumpPadNode", "res://scripts/mapkit/jump_pad.gd", "Building"],
	["LiftPlatform", "res://scripts/mapkit/lift_platform.gd", "Building"],
	["Ladder", "res://scripts/mapkit/ladder.gd", "Building"],
	["GrapplePoint", "res://scripts/mapkit/grapple_point.gd", "Building"],
	["HazardVolume", "res://scripts/mapkit/hazard_volume.gd", "Building"],
	["Spinner", "res://scripts/mapkit/spinner.gd", "Building"],
	["AnimatedModel", "res://scripts/mapkit/animated_model.gd", "Building"],
	["PropSpawn", "res://scripts/mapkit/prop_spawn.gd", "Things in it"],
	["PropType", "res://scripts/props/prop_type.gd", "Things in it"],
	["PickupSpawn", "res://scripts/mapkit/pickup_spawn.gd", "Things in it"],
	["PickupType", "res://scripts/world/pickup_type.gd", "Things in it"],
	["Fixture", "res://scripts/mapkit/fixture.gd", "Things in it"],
	["Crane", "res://scripts/mapkit/crane.gd", "Things in it"],
	["Horn", "res://scripts/mapkit/horn.gd", "Things in it"],
	["CargoContainer", "res://scripts/mapkit/cargo_container.gd", "Things in it"],
	["FloodZone", "res://scripts/mapkit/flood_zone.gd", "Water and ships"],
	["FloodValve", "res://scripts/mapkit/flood_valve.gd", "Water and ships"],
	["FloodDrain", "res://scripts/mapkit/flood_drain.gd", "Water and ships"],
	["FloatSwitch", "res://scripts/mapkit/float_switch.gd", "Water and ships"],
	["Vessel", "res://scripts/mapkit/vessel.gd", "Water and ships"],
	["ShipHold", "res://scripts/mapkit/ship_hold.gd", "Water and ships"],
	["FlagStand", "res://scripts/mapkit/flag_stand.gd", "Modes"],
	["BallSpot", "res://scripts/mapkit/ball_spot.gd", "Modes"],
	["GoalZone", "res://scripts/mapkit/goal_zone.gd", "Modes"],
	["Hoop", "res://scripts/mapkit/hoop.gd", "Modes"],
	["VolleyNet", "res://scripts/mapkit/volley_net.gd", "Modes"],
	["FortressHeart", "res://scripts/mapkit/fortress_heart.gd", "MegaYeet"],
	["Adventure", "res://scripts/mapkit/adventure.gd", "Adventure"],
	["AdventureChapter", "res://scripts/mapkit/adventure_chapter.gd", "Adventure"],
	["StoryNote", "res://scripts/mapkit/story_note.gd", "Adventure"],
	["StoryLine", "res://scripts/mapkit/story_line.gd", "Adventure"],
	["StoryZone", "res://scripts/mapkit/story_zone.gd", "Adventure"],
	["StoryFlag", "res://scripts/mapkit/story_flag.gd", "Adventure"],
	["TalkingYeet", "res://scripts/mapkit/talking_yeet.gd", "Adventure"],
	["Encounter", "res://scripts/mapkit/encounter.gd", "Adventure"],
	["EncounterWave", "res://scripts/mapkit/encounter_wave.gd", "Adventure"],
	["MonsterSpawn", "res://scripts/mapkit/monster_spawn.gd", "MegaYeet"],
	["MonsterType", "res://scripts/horde/monster_type.gd", "MegaYeet"],
	["DefenseZone", "res://scripts/mapkit/defense_zone.gd", "MegaYeet"],
	["TrapSpot", "res://scripts/mapkit/trap_spot.gd", "MegaYeet"],
	["PuzzleNode", "res://scripts/mapkit/puzzle_node.gd", "Puzzles"],
	["PuzzleButton", "res://scripts/mapkit/puzzle_button.gd", "Puzzles"],
	["PressurePlate", "res://scripts/mapkit/pressure_plate.gd", "Puzzles"],
	["PuzzleDoor", "res://scripts/mapkit/puzzle_door.gd", "Puzzles"],
	["PuzzleLogic", "res://scripts/mapkit/puzzle_logic.gd", "Puzzles"],
	["PuzzleTarget", "res://scripts/mapkit/puzzle_target.gd", "Puzzles"],
	["BreakSensor", "res://scripts/mapkit/break_sensor.gd", "Puzzles"],
	["Receptacle", "res://scripts/mapkit/receptacle.gd", "Puzzles"],
	["PuzzleExit", "res://scripts/mapkit/puzzle_exit.gd", "Puzzles"],
	["Checkpoint", "res://scripts/mapkit/checkpoint.gd", "Puzzles"],
	["PuzzleReset", "res://scripts/mapkit/puzzle_reset.gd", "Puzzles"],
	["Seesaw", "res://scripts/mapkit/seesaw.gd", "Puzzles"],
	["Turntable", "res://scripts/mapkit/turntable.gd", "Puzzles"],
	["PuzzleFan", "res://scripts/mapkit/puzzle_fan.gd", "Puzzles"],
	["RopeAnchor", "res://scripts/mapkit/rope_anchor.gd", "Puzzles"],
	["Pulley", "res://scripts/mapkit/pulley.gd", "Puzzles"],
	["Magnet", "res://scripts/mapkit/magnet.gd", "Puzzles"],
	["Beacon", "res://scripts/mapkit/beacon.gd", "Puzzles"],
	["FuseLine", "res://scripts/mapkit/fuse_line.gd", "Puzzles"],
	["Wire", "res://scripts/mapkit/wire.gd", "Puzzles"],
	["Contacts", "res://scripts/mapkit/contacts.gd", "Puzzles"],
]

## What each group of pieces is for (the index).
const GROUPS := {
	"The map": "One MapSettings per map; where players start; lights; a look for the whole map.",
	"Building": "What the map is made of, and what moves you round it.",
	"Things in it": "Props, pickups and machines; your own kinds of prop and pickup are files (a type).",
	"Water and ships": "Water that floods and drains, and ships riding the sea.",
	"Modes": "What Capture the Flag and the sports need.",
	"MegaYeet": "The fortress, the monsters' rifts, its zones and traps.",
	"Adventure": "The Adventure mode: a few maps linked by a story (files, no code), the pieces that tell it (they work on any map), and its fights.",
	"Puzzles": "Pieces that switch on and off and wire up (every one has PuzzleNode's settings).",
}

## Named parts and places in your model a piece uses: [name, what it does there].
const MARKERS := {
	"FloodValve": [["Spout", "where the water comes out, pointing the way it pours (its Y axis: the arrow of a Blender \"Single Arrow\" empty)"], ["Wheel", "turns while it pours"]],
	"FloodDrain": [["Intake", "where the water goes in"]],
	"Fixture": [["Spin", "turns while it runs (about Spin Axis)"], ["Emitter", "where steam, smoke, sparks and drips come from"], ["Light", "where its glow is"]],
	"MapLight": [["Light", "where the light shines from"]],
	"PuzzleButton": [["Cap", "moves in when it's pressed"]],
	"PuzzleReset": [["Cap", "moves in when it's pressed"]],
	"PressurePlate": [["Plate", "sinks when it's weighed down"]],
	"FloatSwitch": [["Float", "rides up and down on the water"]],
	"Seesaw": [["Plank", "tips (the rest of the model stays put)"]],
	"VolleyNet": [["Net", "rises with the net"]],
	"PuzzleFan": [["Rotor", "spins while it blows"]],
	"Crane": [["Turret", "slews (its jib along its +X)"], ["Hook", "where the cable hangs (an empty at the jib's end)"]],
	"Horn": [["Lever", "is pulled when it sounds"]],
	"PropType": [["Collision", "a mesh that is its shape (made convex, hidden in the game)"]],
	"MonsterType": [["Torso", "the body (its origin: the hips)", "anything not in another part is the torso anyway"], ["Leg_L, Leg_R", "swing from their origins (the hips) as it walks", "no stride (and the map check notes it)"], ["Arm_L, Arm_R", "reach and flail from their origins (the shoulders)", "no reaching (and the map check notes it)"], ["Head", "lolls (its origin: the neck)", "no lolling (and the map check notes it)"], ["Glow", "in a part's or a material's name (or an emissive material): it glows", "nothing glows"]],
	"AnimatedModel": [["Collision...", "any part whose name starts so is solid, moving with the animation and carrying what stands on it (made convex, hidden in the game)"]],
}

## Files to start from: [path, what it is].
const STARTERS := {
	"FloodValve": [["custom/make_your_own/my_pipe.tscn", "a pipe of your own, saved as its own piece"], ["custom/make_your_own/models/pipe.glb", "its model, Spout and Wheel in place"]],
	"FloodDrain": [["custom/make_your_own/my_drain.tscn", "a drain of your own"], ["custom/make_your_own/models/drain.glb", "its model, Intake in place"]],
	"TrapSpot": [["custom/make_your_own/thorn_trap.tscn", "a trap of your own (a thorn bed)"], ["custom/make_your_own/models/thorns.glb", "its model"]],
	"PropType": [["custom/make_your_own/oil_drum.tres", "an oil drum (with a Collision mesh)"], ["custom/make_your_own/models/drum.glb", "its model"], ["custom/make_your_own/glass_cabinet.tres", "a glass cabinet that breaks into its parts"], ["custom/make_your_own/models/cabinet.glb", "its model, parts named for their material"]],
	"PropSpawn": [["custom/make_your_own/oil_drum.tres", "a prop of your own for its Type slot (see PropType)"]],
	"PickupType": [["custom/make_your_own/energy_drink.tres", "an energy drink"], ["custom/make_your_own/models/can.glb", "its model"]],
	"PickupSpawn": [["custom/make_your_own/energy_drink.tres", "a pickup of your own for its Type slot (see PickupType)"]],
	"PuzzleFan": [["custom/make_your_own/models/fan.glb", "a fan, its Rotor named"]],
	"FlagStand": [["custom/make_your_own/models/flag_stand.glb", "a stone plinth"]],
	"Crane": [["custom/make_your_own/models/crane.glb", "a crane, Turret and Hook named"], ["custom/make_your_own/models/crate_load.glb", "a load for it"]],
	"Ladder": [["custom/make_your_own/models/ladder.glb", "a wooden ladder"]],
	"Horn": [["custom/make_your_own/models/bell.glb", "a bell on a post, its Lever named"]],
	"BreakableModel": [["custom/make_your_own/models/door.glb", "a door of planks in a Fixed frame"], ["custom/make_your_own/models/window.glb", "a window: a Fixed frame, glass, a wooden mullion"], ["custom/make_your_own/models/fence.glb", "a fence: posts and rails"]],
	"BreakableSlab": [["custom/make_your_own/bricks.tres", "a brick material for Custom Material"]],
	"Vessel": [["custom/make_your_own/boat.tscn", "Make Your Own Boat: a boat beside an island"]],
	"Adventure": [["adventures/two_small_rooms.adventure.tres", "the smallest adventure there is: two chapters"]],
	"AdventureChapter": [["adventures/two_small_rooms/room1.tscn", "a chapter's map: Puzzle on, and a PuzzleExit"]],
	"Encounter": [["adventures/the_cellar/cellar.tscn", "two fights: one hunting you through two waves, then a boss let out of a cage, heading for a Goal"]],
	"EncounterWave": [["adventures/the_cellar/cellar.tscn", "the waves are in the Encounters' Waves: built-in kinds, a boss, monsters of your own"]],
	"MonsterType": [["custom/make_your_own/scarecrow.tres", "a scarecrow come alive (behaves like a shambler; straw burns)"], ["custom/make_your_own/models/scarecrow.glb", "its model, its parts named, each origin at its joint"]],
	"FortressHeart": [["custom/make_your_own/scarecrow.tres", "a monster of your own for Monster Types (see MonsterType)"]],
	"AnimatedModel": [["custom/make_your_own/models/windmill.glb", "a windmill, its sails turning (loop)"], ["custom/make_your_own/models/sign.glb", "an inn sign swinging (ping pong)"], ["custom/make_your_own/models/platform.glb", "a platform sliding 6 m and back, carrying riders (ping pong)"], ["custom/make_your_own/models/drawbridge.glb", "a drawbridge lowering (once: wire it to a button)"]],
}

var _check := false
var _problems: Array[String] = []
var _used := {} # script path -> [[map name, file, count]]
var _parsed := {} # script path -> _parse()


func _init() -> void:
	_check = OS.get_cmdline_user_args().has("--check")
	_scan_maps()
	var pages := {}
	var index_rows := {}
	for p: Array in PIECES:
		var info := _parse(p[1])
		pages[p[0] + ".md"] = _page(p, info)
		if not index_rows.has(p[2]):
			index_rows[p[2]] = []
		index_rows[p[2]].append("| [%s](%s.md) | %s |" % [p[0], p[0], _cell(_first_sentence(info.doc))])
	pages["README.md"] = _index(index_rows)
	var out := {}
	for file: String in pages:
		out[OUT + file] = pages[file]
	for path: String in WALKTHROUGHS:
		out[path] = _fill(FileAccess.get_file_as_string(path), path)
	var changed := 0
	for path: String in out:
		var old := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if old == out[path]:
			continue
		changed += 1
		if _check:
			_problems.append("%s is out of date" % path)
		else:
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(out[path])
	for file in DirAccess.get_files_at(OUT) if DirAccess.dir_exists_absolute(OUT) else PackedStringArray():
		if file.ends_with(".md") and not pages.has(file):
			_problems.append("%s%s: no such piece any more (delete it)" % [OUT, file])
	for s in _problems:
		print("GUIDE: " + s)
	if _check:
		print("GUIDE CHECK ", "OK" if _problems.is_empty() else "FAILED (%d): run godot --headless --path . --script res://tools/make_guide.gd" % _problems.size())
	else:
		print("pages: %d written, %d up to date" % [changed, out.size() - changed])
	quit(0 if _problems.is_empty() else 1)


# --- Reading a script -------------------------------------------------------------------------

## A script's class doc, what it extends, and its settings: {name, label, annotation, args,
## default, doc, group}.
func _parse(path: String) -> Dictionary:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var out := {"doc": PackedStringArray(), "extends": "", "settings": []}
	var group := ""
	var in_class_doc := false
	var class_doc_done := false
	for i in lines.size():
		var l := lines[i]
		if l.begins_with("extends "):
			out.extends = l.substr(8).strip_edges()
			in_class_doc = true
			continue
		if in_class_doc and not class_doc_done:
			if l.begins_with("##"):
				out.doc.append(l.substr(2).substr(1) if l.length() > 2 else "")
				continue
			class_doc_done = true
		if l.begins_with("@export_group("):
			group = _args(l.substr(14, l.rfind(")") - 14))[0].trim_prefix("\"").trim_suffix("\"")
			continue
		if not l.begins_with("@export"):
			continue
		var at := l.find(" var ")
		var ann := l.substr(0, at)
		var rest := l.substr(at + 5).strip_edges().trim_suffix(":")
		var name := rest.get_slice(" ", 0).get_slice(":", 0)
		var default := ""
		if rest.contains(":="):
			default = rest.substr(rest.find(":=") + 2).strip_edges()
		elif rest.contains(" = "):
			default = rest.substr(rest.find(" = ") + 3).strip_edges()
		var args := []
		if ann.contains("("):
			args = _args(ann.substr(ann.find("(") + 1, ann.rfind(")") - ann.find("(") - 1))
		var doc := PackedStringArray()
		var j := i - 1
		while j >= 0 and lines[j].begins_with("##"):
			doc.insert(0, lines[j].substr(3))
			j -= 1
		if doc.is_empty() and not path.ends_with("map_theme.gd"):
			_problems.append("%s: setting \"%s\" has no doc comment (## above it)" % [path, name])
		out.settings.append({"name": name, "label": name.capitalize(), "annotation": ann.get_slice("(", 0), "args": args, "default": default, "doc": " ".join(doc), "group": group})
	return out


## An annotation's arguments, split at the commas outside quotes.
func _args(s: String) -> Array:
	var out := []
	var cur := ""
	var quoted := false
	for ch in s:
		if ch == "\"":
			quoted = not quoted
		if ch == "," and not quoted:
			out.append(cur.strip_edges())
			cur = ""
		else:
			cur += ch
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


# --- Writing a page ---------------------------------------------------------------------------

func _page(p: Array, info: Dictionary) -> String:
	var cls: String = p[0]
	var path: String = p[1]
	var md := PackedStringArray()
	md.append("<!-- Made by tools/make_guide.gd from %s: change the comments there and run it again, not this page. -->" % path.trim_prefix("res://"))
	md.append("# %s" % cls)
	md.append("")
	var kind := "a type file (Create New > Resource > %s)" % cls if info.extends == "Resource" else "a Map Kit piece (Add Child Node > %s)" % cls
	md.append("*%s: %s. Script: `%s`.* [All the pieces](README.md)" % [p[2], kind, path.trim_prefix("res://")])
	md.append("")
	md.append_array(_prose(info.doc))
	var base := _piece_of(info.extends)
	if base != "":
		md.append("")
		md.append("It has every [%s](%s.md) setting too (they're listed there)." % [base, base])
	if not info.settings.is_empty():
		md.append("")
		md.append("## Settings")
		var group := ""
		var opened := false
		for s: Dictionary in info.settings:
			if s.group != group or not opened:
				if s.group != group:
					group = s.group
					md.append("")
					md.append("### %s" % group)
				md.append("")
				md.append("| Setting | Default | What it does |")
				md.append("|---|---|---|")
				opened = true
			md.append("| **%s** | %s | %s |" % [s.label, _default(s), _cell(_what(s))])
	var markers: Array = MARKERS.get(cls, [])
	if not markers.is_empty():
		var wants := {}
		for w: Array in Looks.WANTS.get(cls, []):
			wants[w[0]] = w[1]
		md.append("")
		md.append("## Your model's markers")
		md.append("")
		md.append("Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like \"spout\".")
		md.append("")
		md.append("| Name | What it does | Without it |")
		md.append("|---|---|---|")
		for m: Array in markers:
			md.append("| `%s` | %s | %s |" % [m[0], _cell(m[1]), _cell(m[2] if m.size() > 2 else wants.get(m[0], "nothing is missed"))])
	var starters: Array = STARTERS.get(cls, [])
	if not starters.is_empty():
		md.append("")
		md.append("## Start from")
		md.append("")
		for s: Array in starters:
			if not FileAccess.file_exists("res://" + s[0]):
				_problems.append("%s: starter %s isn't there" % [cls, s[0]])
			md.append("- [`%s`](../../%s): %s" % [s[0], s[0], s[1]])
	var used: Array = _used.get(path, [])
	if not used.is_empty():
		md.append("")
		md.append("## Used in")
		md.append("")
		var parts := PackedStringArray()
		for u: Array in used:
			parts.append("[%s](../../%s)%s" % [u[0], u[1], " (%d)" % u[2] if u[2] > 1 else ""])
		md.append(", ".join(parts))
	md.append("")
	return "\n".join(md)


func _index(rows: Dictionary) -> String:
	var md := PackedStringArray()
	md.append("<!-- Made by tools/make_guide.gd from the pieces' scripts: run it again, don't edit this page. -->")
	md.append("# Map Kit pieces")
	md.append("")
	md.append("A page for every piece you can put in a map, and every type file (your own props and pickups, a theme): what it does, its settings, the markers your model can have, the starter models to begin from and the maps that use it. Building your first map: [CUSTOM_MAPS_GUIDE.md](../CUSTOM_MAPS_GUIDE.md). A real map rebuilt piece by piece: [REBUILD_A_MAP.md](../REBUILD_A_MAP.md). A new map from an idea: [MAKE_A_NEW_MAP.md](../MAKE_A_NEW_MAP.md). The whole kit at a glance: [MAPPING.md](../MAPPING.md).")
	md.append("")
	md.append("The same descriptions are the tooltips in Godot's Inspector: hover over a setting.")
	for g: String in rows:
		md.append("")
		md.append("## %s" % g)
		md.append("")
		md.append(GROUPS[g])
		md.append("")
		md.append("| Piece | What it is |")
		md.append("|---|---|")
		md.append_array(rows[g])
	md.append("")
	return "\n".join(md)


## A doc comment as Markdown: paragraphs, and "- " lines as a list (indented lines go on).
func _prose(doc: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var bullet := false
	for l in doc:
		if l.strip_edges() == "":
			if cur != "":
				out.append(cur)
				cur = ""
			continue
		if l.begins_with("- "):
			if cur != "":
				out.append(cur)
			if not bullet and not out.is_empty() and not out[out.size() - 1].begins_with("- "):
				out.append("")
			cur = l
			bullet = true
		elif l.begins_with("  ") and bullet:
			cur += " " + l.strip_edges()
		else:
			if bullet:
				out.append(cur)
				out.append("")
				cur = l
				bullet = false
			else:
				cur = l if cur == "" else cur + " " + l
	if cur != "":
		out.append(cur)
	return out


func _what(s: Dictionary) -> String:
	var t: String = s.doc
	if s.annotation == "@export_range":
		var a: Array = s.args
		var r := "%s to %s" % [_num(a[0]), _num(a[1])]
		if a.has("\"or_greater\""):
			r += ", or more"
		if a.has("\"or_less\""):
			r += ", or less"
		t += " *(%s)*" % r
	elif s.annotation == "@export_enum":
		var names := PackedStringArray()
		for o: String in s.args:
			names.append("`%s`" % o.trim_prefix("\"").trim_suffix("\"").get_slice(":", 0))
		t += " Choices: %s." % ", ".join(names)
	return t.strip_edges()


func _default(s: Dictionary) -> String:
	var d: String = s.default
	if d == "":
		return "(none)"
	if s.annotation == "@export_enum":
		if d.begins_with("\""):
			return "`%s`" % d.trim_prefix("\"").trim_suffix("\"")
		for k in s.args.size():
			var o: String = s.args[k].trim_prefix("\"").trim_suffix("\"")
			var v: int = int(o.get_slice(":", 1)) if o.contains(":") else k
			if str(v) == d:
				return "`%s`" % o.get_slice(":", 0)
	match d:
		"true":
			return "on"
		"false":
			return "off"
		"\"\"":
			return "(empty)"
		"[]":
			return "(none)"
	if d.begins_with("\""):
		return "`%s`" % d.trim_prefix("\"").trim_suffix("\"")
	if d.is_valid_float():
		return "`%s`" % _num(d)
	var m := RegEx.create_from_string("^Vector[23]\\((.*)\\)$").search(d)
	if m:
		var parts := PackedStringArray()
		for v in m.get_string(1).split(","):
			parts.append(_num(v.strip_edges()))
		return "`(%s)`" % ", ".join(parts)
	if d in ["Vector3.ZERO", "Vector2.ZERO"]:
		return "`(0, 0%s)`" % (", 0" if d.begins_with("Vector3") else "")
	var e := RegEx.create_from_string("^[A-Z]\\w*\\.([A-Z_]+)$").search(d)
	if e:
		return "`%s`" % e.get_string(1)
	return "`%s`" % d


func _num(s: String) -> String:
	if s.is_valid_float() and s.ends_with(".0"):
		s = s.trim_suffix(".0")
	return "0" if s == "-0" else s


func _cell(s: String) -> String:
	return s.replace("|", "\\|")


func _first_sentence(doc: PackedStringArray) -> String:
	var t := " ".join(doc).strip_edges()
	var cut := t.find(". ")
	while cut > 0 and (t.substr(cut - 3, 3) == "e.g" or t.substr(cut - 3, 3) == "i.e"):
		cut = t.find(". ", cut + 2)
	if cut > 0:
		t = t.substr(0, cut + 1)
	return t


func _piece_of(cls: String) -> String:
	for p: Array in PIECES:
		if p[0] == cls:
			return cls
	return ""


# --- A walkthrough's tables, from its map -----------------------------------------------------

## The walkthrough with every <!-- nodes ... --> table filled in again from its map.
func _fill(text: String, doc: String) -> String:
	var re := RegEx.create_from_string("(<!-- nodes (\\S+) (under|named|script) (\\S+) -->\\n)[\\s\\S]*?(<!-- /nodes -->)")
	var out := ""
	var at := 0
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at) + m.get_string(1)
		var nodes := _scene_nodes(m.get_string(2))
		if nodes.is_empty():
			_problems.append("%s: can't read %s" % [doc, m.get_string(2)])
		var pick := nodes.filter(func(n): return n.get(m.get_string(3)) == m.get_string(4))
		if pick.is_empty():
			_problems.append("%s: nothing %s %s in %s" % [doc, m.get_string(3), m.get_string(4), m.get_string(2)])
		out += _node_table(pick, m.get_string(3) == "named") + m.get_string(5)
		at = m.get_end()
	return out + text.substr(at)


## A scene's nodes as written in it: {named, under (its parent's name), script (its path),
## type, props: [[key, value as written]]}.
func _scene_nodes(path: String) -> Array:
	var out := []
	if not FileAccess.file_exists(path):
		return out
	var ids := {}
	var cur: Dictionary = {}
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.begins_with("[ext_resource"):
			var p := RegEx.create_from_string("path=\"([^\"]+)\"").search(l)
			var i := RegEx.create_from_string("id=\"([^\"]+)\"").search(l)
			if p and i:
				ids[i.get_string(1)] = p.get_string(1)
		elif l.begins_with("[node"):
			var n := RegEx.create_from_string("name=\"([^\"]+)\"").search(l)
			var t := RegEx.create_from_string("type=\"([^\"]+)\"").search(l)
			var par := RegEx.create_from_string("parent=\"([^\"]+)\"").search(l)
			cur = {"named": n.get_string(1), "type": t.get_string(1) if t else "", "under": par.get_string(1).get_file() if par else "", "script": "", "props": []}
			out.append(cur)
		elif l.begins_with("["):
			cur = {}
		elif not cur.is_empty() and l.contains(" = "):
			var key := l.get_slice(" = ", 0)
			var val := l.substr(key.length() + 3)
			var res: String = ids.get(val.trim_prefix("ExtResource(\"").trim_suffix("\")"), "")
			if key == "script":
				cur.script = res
			elif val.begins_with("ExtResource("):
				cur.props.append([key, var_to_str(res.get_file())]) # (a model, a type file: its file)
			else:
				cur.props.append([key, val])
	return out


## The nodes as a table: what to add, where, and the settings that aren't the default. One
## node (named): its settings, a row each.
func _node_table(nodes: Array, one: bool) -> String:
	var rows := PackedStringArray()
	if one and nodes.size() == 1:
		rows.append("| Setting | Set it to |")
		rows.append("|---|---|")
		for kv: Array in nodes[0].props:
			if _is_default(nodes[0].script, kv):
				continue
			rows.append("| **%s** | %s |" % [kv[0].capitalize(), _cell(_value(kv[0], kv[1], nodes[0].script))])
		return "\n".join(rows) + "\n"
	rows.append("| Name | Add | Position | Rotation | Settings |")
	rows.append("|---|---|---|---|---|")
	for n: Dictionary in nodes:
		var pos := ""
		var rot := ""
		var sets := PackedStringArray()
		for kv: Array in n.props:
			match kv[0]:
				"position":
					pos = _value("", kv[1], "")
				"rotation":
					var r: Vector3 = str_to_var(kv[1])
					rot = _vec(Vector3(rad_to_deg(r.x), rad_to_deg(r.y), rad_to_deg(r.z)), 1)
				"transform":
					var x: Transform3D = str_to_var(kv[1])
					pos = _vec(x.origin, 3)
					var e := x.basis.get_euler()
					if not e.is_zero_approx():
						rot = _vec(Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)), 1)
				_:
					if not _is_default(n.script, kv):
						sets.append("%s: %s" % [kv[0].capitalize(), _value(kv[0], kv[1], n.script)])
		var add: String = n.type
		for p: Array in PIECES:
			if p[1] == n.script:
				add = "[%s](pieces/%s.md)" % [p[0], p[0]]
		rows.append("| %s | %s | %s | %s | %s |" % [n.named, add, pos, rot, _cell("; ".join(sets)) if not sets.is_empty() else "(as it comes)"])
	return "\n".join(rows) + "\n"


## A setting the scene sets to what it would be anyway (nothing to change).
func _is_default(script: String, kv: Array) -> bool:
	if script == "":
		return false
	if not _parsed.has(script):
		_parsed[script] = _parse(script)
	for s: Dictionary in _parsed[script].settings:
		if s.name == kv[0] and s.default != "":
			var e := Expression.new()
			var d = e.execute([], null, false) if e.parse(s.default) == OK else null # (Color(r, g, b), Vector3.ZERO...)
			var v = str_to_var(kv[1])
			if d is float or d is int:
				return (v is float or v is int) and is_equal_approx(float(d), float(v))
			return d != null and typeof(d) == typeof(v) and d == v
	return false


## A value as you'd set it in the Inspector: a choice by its name, a colour as its hex code.
func _value(key: String, text: String, script: String) -> String:
	if script != "" and key != "":
		var src := FileAccess.get_file_as_string(script)
		var ex := RegEx.create_from_string("@export_enum\\((.*)\\) var " + key + "\\b").search(src)
		if ex:
			var opts := _args(ex.get_string(1))
			for k in opts.size():
				var o: String = opts[k].trim_prefix("\"").trim_suffix("\"")
				var v: String = o.get_slice(":", 1) if o.contains(":") else str(k)
				if v == text or "\"%s\"" % o == text:
					return o.get_slice(":", 0)
		var typed := RegEx.create_from_string("@export var " + key + ": (\\w+)").search(src)
		if typed and text.is_valid_int():
			var en := RegEx.create_from_string("enum " + typed.get_string(1) + " \\{([^}]*)\\}").search(src)
			if en:
				var names := en.get_string(1).split(",")
				if int(text) < names.size():
					return names[int(text)].strip_edges()
	var v = str_to_var(text)
	if v is bool:
		return "on" if v else "off"
	if v is String:
		return v
	if v is float or v is int:
		return _num(str(snappedf(float(v), 0.001)))
	if v is Vector3 or v is Vector2:
		return _vec(v, 3)
	if v is Color:
		return "#" + (v as Color).to_html(false)
	if v is Rect2:
		return "(%s, %s, %s, %s)" % [_num(str(v.position.x)), _num(str(v.position.y)), _num(str(v.size.x)), _num(str(v.size.y))]
	if v is Array:
		var parts := PackedStringArray()
		for e in v:
			parts.append(_value("", var_to_str(e), ""))
		return ", ".join(parts)
	return text


func _vec(v, digits: int) -> String:
	var parts := PackedStringArray()
	var n := 3 if v is Vector3 else 2
	for k in n:
		parts.append(_num(str(snappedf(v[k], pow(10.0, -digits)))))
	return "(%s)" % ", ".join(parts)


# --- The maps that use them -------------------------------------------------------------------

func _scan_maps() -> void:
	var files: Array[String] = []
	for dir: String in MAPS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tscn") or f.ends_with(".tres"):
				files.append(dir + f)
	files.sort()
	var ext := RegEx.create_from_string("\\[ext_resource type=\"Script\"[^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"([^\"]+)\"")
	var named := RegEx.create_from_string("\\nmap_name = \"([^\"]*)\"")
	for file in files:
		var text := FileAccess.get_file_as_string(file)
		var title := file.get_file().get_basename().capitalize()
		var n := named.search(text)
		if n:
			title = n.get_string(1)
		for m in ext.search_all(text):
			var script := m.get_string(1)
			var count := text.count("ExtResource(\"%s\")" % m.get_string(2))
			if count == 0:
				continue
			if not _used.has(script):
				_used[script] = []
			_used[script].append([title, file.trim_prefix("res://"), count])
