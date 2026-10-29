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

enum Mode { SANDBOX, CTF, DODGEBALL }
const MODE_NAMES := ["Sandbox", "Capture the Flag", "Dodgeball"]
const MAP_NAMES := ["Yeetwork Prime", "Facing Yeets"]

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
var third_person := false
var master_volume := 0.8

# Session config (set by the menu before a match starts).
var mode: int = Mode.SANDBOX
var map := 1
var bot_count := 3
var join_address := "127.0.0.1"
var port := DEFAULT_PORT
var is_hosting := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "sensitivity", mouse_sensitivity)
	cfg.set_value("player", "fov", fov)
	cfg.set_value("player", "gore", gore_level)
	cfg.set_value("player", "auto_bhop", auto_bhop)
	cfg.set_value("player", "third_person", third_person)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("net", "address", join_address)
	cfg.set_value("net", "port", port)
	cfg.set_value("match", "mode", mode)
	cfg.set_value("match", "bots", bot_count)
	cfg.set_value("match", "map", map)
	cfg.save(SETTINGS_PATH)
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
	third_person = cfg.get_value("player", "third_person", third_person)
	master_volume = cfg.get_value("audio", "volume", master_volume)
	join_address = cfg.get_value("net", "address", join_address)
	port = cfg.get_value("net", "port", port)
	mode = cfg.get_value("match", "mode", mode)
	bot_count = cfg.get_value("match", "bots", bot_count)
	map = clampi(cfg.get_value("match", "map", map), 0, MAP_NAMES.size() - 1)
	apply_audio()


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))


func is_team_mode() -> bool:
	return mode != Mode.SANDBOX


func team_color(team: int) -> Color:
	return TEAM_COLORS.get(team, TEAM_COLORS[0])


# --- Input --------------------------------------------------------------------

func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("crouch", [KEY_CTRL, KEY_C, KEY_SHIFT])
	_key("freeze_prop", [KEY_F])
	_key("spawn_prop", [KEY_Q])
	_key("toggle_view", [KEY_V])
	_key("scoreboard", [KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("suicide", [KEY_K])
	_key("respawn_props", [KEY_F5])
	for i in range(1, 10):
		_key("slot_%d" % i, [KEY_0 + i])
	_mouse("gun_grab", MOUSE_BUTTON_LEFT)
	_mouse("gun_throw", MOUSE_BUTTON_RIGHT)
	_mouse("next_slot", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("prev_slot", MOUSE_BUTTON_WHEEL_UP)
	_pad("jump", JOY_BUTTON_A)
	_pad("crouch", JOY_BUTTON_B)
	_pad("spawn_prop", JOY_BUTTON_Y)
	_pad("freeze_prop", JOY_BUTTON_X)
	_pad("pause", JOY_BUTTON_START)
	_pad("scoreboard", JOY_BUTTON_BACK)
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
