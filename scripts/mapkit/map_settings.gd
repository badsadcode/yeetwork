@tool
class_name MapSettings
extends Node
## Map-wide settings. Put exactly one in every map scene (any depth).
## Running a map scene directly (F6) starts a local playtest with bots.

@export var map_name := "Untitled Arena"
@export var author := ""
@export_multiline var description := ""
## Lighting preset: warm sunset, bright day, moonlit night, or outer space.
@export_enum("sunset", "day", "night", "space") var sky := "sunset":
	set(v):
		sky = v
		_refresh_preview()
## Sun direction (rotation of the DirectionalLight3D, degrees).
@export var sun_rotation_degrees := Vector3(-42, 38, 0):
	set(v):
		sun_rotation_degrees = v
		_refresh_preview()
@export_range(0.0, 3.0, 0.05) var sun_energy_scale := 1.0:
	set(v):
		sun_energy_scale = v
		_refresh_preview()
@export_range(0.0, 3.0, 0.05) var ambient_scale := 1.0:
	set(v):
		ambient_scale = v
		_refresh_preview()
## Players and props below this height die / respawn.
@export var kill_height := -40.0
## Areas (XZ rectangles in world space) bots should walk around, e.g. pits.
@export var avoid_areas: Array[Rect2] = []
## Playtest settings used when you press F6 on this scene.
@export_enum("Sandbox", "Capture the Flag", "Dodgeball", "Pumpkin Smash") var playtest_mode := 0
@export_range(0, 11) var playtest_bots := 3

var _preview: Array[Node] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_preview()
		return
	# Running the map scene on its own (F6): boot the game with this map.
	var root := get_tree().current_scene
	if root != null and root.scene_file_path != "" and (root == self or root.is_ancestor_of(self)) and root.scene_file_path != "res://main.tscn":
		_playtest.call_deferred(root.scene_file_path)


func _playtest(path: String) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	game.set("map", path)
	game.set("mode", playtest_mode)
	game.set("bot_count", playtest_bots)
	game.set("autostart", true)
	get_tree().change_scene_to_file("res://main.tscn")


## In the editor, show the lighting preset unless the map brings its own environment.
func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for n in _preview:
		if is_instance_valid(n):
			n.queue_free()
	_preview.clear()
	var root := get_tree().edited_scene_root if get_tree() else null
	if root and (_has_type(root, "WorldEnvironment") or _has_type(root, "DirectionalLight3D")):
		return
	for n in MapEnvironment.build(sky, self):
		add_child(n, false, Node.INTERNAL_MODE_FRONT)
		_preview.append(n)


func _has_type(n: Node, type_name: String) -> bool:
	if n.is_class(type_name) and not _preview.has(n):
		return true
	for c in n.get_children():
		if _has_type(c, type_name):
			return true
	return false
