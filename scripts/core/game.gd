extends Node
## Global singleton: settings, input map, session config and shared constants.

signal settings_changed

const VERSION := "0.1.0"
const DEFAULT_PORT := 24642
const MAX_PLAYERS := 16

# Physics layers (bit values).
const L_WORLD := 1
const L_PLAYERS := 2
const L_PROPS := 4
const L_LIMBS := 8
const L_TRIGGERS := 16

enum Mode { SANDBOX, CTF, DODGEBALL, PUMPKIN }
const MODE_NAMES := ["Sandbox", "Capture the Flag", "Dodgeball", "Pumpkin Smash"]
const BUILTIN_MAPS := [
	{"key": "facing", "name": "Facing Yeets"},
	{"key": "prime", "name": "Yeetwork Prime"},
]
const MAPS_DIR := "res://maps"

const TEAM_NONE := 0
const TEAM_RED := 1
const TEAM_BLUE := 2
const TEAM_COLORS := {
	0: Color(1.0, 0.78, 0.2),
	1: Color(1.0, 0.27, 0.33),
	2: Color(0.25, 0.55, 1.0),
}
const TEAM_NAMES := {0: "Free", 1: "Red", 2: "Blue"}

## Bright palette used for free-for-all player colors.
const FFA_COLORS := [
	Color(1.0, 0.78, 0.2), Color(0.45, 0.9, 0.35), Color(0.95, 0.45, 0.85),
	Color(0.3, 0.85, 0.95), Color(1.0, 0.55, 0.25), Color(0.7, 0.5, 1.0),
	Color(0.95, 0.95, 0.95), Color(0.4, 0.95, 0.7),
]

const SETTINGS_PATH := "user://settings.cfg"

# Player settings (persisted).
var player_name := "Yeeter"
var mouse_sensitivity := 0.0022
var fov := 100.0
var gore_level := 1 # 0 = off, 1 = silly, 2 = extreme
var auto_bhop := true
var always_run := false
var bot_skill := 1 # 0 = easy, 1 = normal, 2 = hard
var graphics := -1 # 0 = low, 1 = medium, 2 = high; -1 = pick automatically
var stick_sensitivity := 1.0
var invert_y := false
var halloween := 1 # 0 = off, 1 = auto (mid October - early November), 2 = always
var third_person := false
var master_volume := 0.8

# Session config (set by the menu before a match starts).
var mode: int = Mode.SANDBOX
var map := "facing" # built-in key or a map scene path under res://maps
var autostart := false
var spooky := false # Halloween theme active for the current match (decided by the server) # set by a map scene run with F6 (playtest)
var _map_cache: Array = []
var bot_count := 3
var join_address := "127.0.0.1"
var port := DEFAULT_PORT
var is_hosting := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	if graphics < 0:
		graphics = 0 if is_steam_deck() else 2
	apply_graphics()


## Steam sets SteamDeck=1 for games launched on the Deck; SteamOS sets SteamOS=1.
func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1" or OS.get_environment("SteamOS") == "1"


## Viewport-level quality (resolution scale, AA, shadow atlas). The environment side is
## handled by MapEnvironment and re-applied on settings_changed.
func apply_graphics() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match graphics:
		0:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.75
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		1:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.9
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(4096, true)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "sensitivity", mouse_sensitivity)
	cfg.set_value("player", "fov", fov)
	cfg.set_value("player", "gore", gore_level)
	cfg.set_value("player", "auto_bhop", auto_bhop)
	cfg.set_value("player", "always_run", always_run)
	cfg.set_value("match", "bot_skill", bot_skill)
	cfg.set_value("match", "halloween", halloween)
	cfg.set_value("video", "graphics", graphics)
	cfg.set_value("player", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("player", "invert_y", invert_y)
	cfg.set_value("player", "third_person", third_person)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("net", "address", join_address)
	cfg.set_value("net", "port", port)
	cfg.set_value("match", "mode", mode)
	cfg.set_value("match", "bots", bot_count)
	cfg.set_value("match", "map", map)
	cfg.save(SETTINGS_PATH)
	apply_graphics()
	settings_changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	player_name = cfg.get_value("player", "name", player_name)
	mouse_sensitivity = cfg.get_value("player", "sensitivity", mouse_sensitivity)
	fov = cfg.get_value("player", "fov", fov)
	gore_level = cfg.get_value("player", "gore", gore_level)
	auto_bhop = cfg.get_value("player", "auto_bhop", auto_bhop)
	always_run = cfg.get_value("player", "always_run", always_run)
	bot_skill = cfg.get_value("match", "bot_skill", bot_skill)
	halloween = cfg.get_value("match", "halloween", halloween)
	graphics = cfg.get_value("video", "graphics", graphics)
	stick_sensitivity = cfg.get_value("player", "stick_sensitivity", stick_sensitivity)
	invert_y = cfg.get_value("player", "invert_y", invert_y)
	third_person = cfg.get_value("player", "third_person", third_person)
	master_volume = cfg.get_value("audio", "volume", master_volume)
	join_address = cfg.get_value("net", "address", join_address)
	port = cfg.get_value("net", "port", port)
	mode = cfg.get_value("match", "mode", mode)
	bot_count = cfg.get_value("match", "bots", bot_count)
	var m = cfg.get_value("match", "map", map)
	map = m if m is String else "facing"
	apply_audio()


## Built-in maps plus every scene in res://maps (made with the Map Kit).
func list_maps() -> Array:
	if not _map_cache.is_empty():
		return _map_cache
	var out := BUILTIN_MAPS.duplicate(true)
	var dir := DirAccess.open(MAPS_DIR)
	if dir:
		var files := []
		for f in dir.get_files():
			f = f.trim_suffix(".remap")
			if f.ends_with(".tscn") or f.ends_with(".scn"):
				files.append(f)
		files.sort()
		for f in files:
			var path: String = MAPS_DIR + "/" + f
			out.append({"key": path, "name": _scene_map_name(path)})
	_map_cache = out
	return out


func map_display_name(key: String) -> String:
	for m in list_maps():
		if m.key == key:
			return m.name
	return key.get_file().get_basename().capitalize()


func _scene_map_name(path: String) -> String:
	var packed := load(path) as PackedScene
	if packed:
		var root := packed.instantiate()
		var n := _find_map_name(root)
		root.free()
		if n != "":
			return n
	return path.get_file().get_basename().capitalize()


func _find_map_name(n: Node) -> String:
	if n.get_script() and n.get("map_name") != null:
		return n.get("map_name")
	for c in n.get_children():
		var r := _find_map_name(c)
		if r != "":
			return r
	return ""


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))


## Should the Halloween theme be used for a match hosted now?
func halloween_active() -> bool:
	if halloween == 2 or mode == Mode.PUMPKIN:
		return true
	if halloween == 0:
		return false
	var d := Time.get_date_dict_from_system()
	return (d.month == 10 and d.day >= 15) or (d.month == 11 and d.day <= 3)


func is_team_mode() -> bool:
	return mode == Mode.CTF or mode == Mode.DODGEBALL


func team_color(team: int) -> Color:
	return TEAM_COLORS.get(team, TEAM_COLORS[0])


# --- Input --------------------------------------------------------------------

func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("crouch", [KEY_CTRL, KEY_C])
	_key("run", [KEY_SHIFT])
	_key("freeze_prop", [KEY_F])
	_key("spawn_prop", [KEY_Q])
	_key("toggle_view", [KEY_V])
	_key("scoreboard", [KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("suicide", [KEY_K])
	_key("respawn_props", [KEY_F5])
	_key("rotate_held", [KEY_E])
	for i in range(1, 10):
		_key("slot_%d" % i, [KEY_0 + i])
	_mouse("gun_grab", MOUSE_BUTTON_LEFT)
	_mouse("gun_throw", MOUSE_BUTTON_RIGHT)
	# The mouse wheel is read as raw events in Player (prop slots, or push/pull when
	# holding something); on gamepads the D-pad does the same through these actions.
	_ensure("next_slot")
	_ensure("prev_slot")
	_pad("hold_farther", JOY_BUTTON_DPAD_UP)
	_pad("hold_closer", JOY_BUTTON_DPAD_DOWN)
	_pad("rotate_held", JOY_BUTTON_LEFT_SHOULDER)
	_pad("jump", JOY_BUTTON_A)
	_pad("crouch", JOY_BUTTON_B)
	_pad("spawn_prop", JOY_BUTTON_Y)
	_pad("freeze_prop", JOY_BUTTON_X)
	_pad("pause", JOY_BUTTON_START)
	_pad("scoreboard", JOY_BUTTON_BACK)
	_pad("toggle_view", JOY_BUTTON_DPAD_UP)
	_pad("suicide", JOY_BUTTON_DPAD_DOWN)
	_pad("prev_slot", JOY_BUTTON_DPAD_LEFT)
	_pad("next_slot", JOY_BUTTON_DPAD_RIGHT)
	_pad("run_toggle", JOY_BUTTON_LEFT_STICK)
	_pad("freeze_prop", JOY_BUTTON_RIGHT_SHOULDER)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis("gun_grab", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis("gun_throw", JOY_AXIS_TRIGGER_RIGHT, 1.0)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _key(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _pad(action: String, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
