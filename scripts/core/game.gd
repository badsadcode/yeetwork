extends Node
## Global singleton: settings, input map, session config and shared constants.

signal settings_changed

const VERSION := "0.2.0"
const DEFAULT_PORT := 24642
const MAX_PLAYERS := 16

# Physics layers (bit values).
const L_WORLD := 1
const L_PLAYERS := 2
const L_PROPS := 4
const L_LIMBS := 8
const L_TRIGGERS := 16

enum Mode { SANDBOX, CTF, DODGEBALL, PUMPKIN, PUZZLE, YEETBALL }
const MODE_NAMES := ["Sandbox", "Capture the Flag", "Dodgeball", "Pumpkin Smash", "Puzzle (co-op)", "Yeetball"]
const BUILTIN_MAPS := [
	{"key": "facing", "name": "Facing Yeets"},
	{"key": "prime", "name": "Yeetwork Prime"},
	{"key": "highseas", "name": "High Seas"},
	{"key": "highseas_dusk", "name": "High Seas: Golden Hour"},
	{"key": "highseas_storm", "name": "High Seas: Storm"},
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

## What each graphics preset sets. Keys:
##   scale: 3D resolution (0.5-1)   upscaler: 0 bilinear, 1 FSR 1, 2 FSR 2
##   aa: 0 off, 1 FXAA, 2 MSAA 2x, 3 MSAA 4x, 4 TAA   shadows: 0 off, 1 low, 2 high
##   gi: 0 off, 1 SSIL, 2 SSIL + SDFGI   ssao, fog (volumetric), glow: on/off
##   water: 0 low, 1 medium, 2 high   glass: 0 simple, 1 refraction, 2 + reflections
##   explosions: 0 simple (billboard puffs), 1 volumetric, 2 volumetric high
##   clouds: 0 off, 1 few, 2 many
##   vsync: on/off   max_fps: 0 = unlimited
const GFX_PRESETS := [
	{"scale": 0.75, "upscaler": 1, "aa": 1, "shadows": 1, "gi": 0, "ssao": true, "fog": false, "glow": true, "water": 0, "glass": 1, "explosions": 0, "clouds": 1, "vsync": true, "max_fps": 0},
	{"scale": 0.9, "upscaler": 1, "aa": 1, "shadows": 2, "gi": 1, "ssao": true, "fog": true, "glow": true, "water": 1, "glass": 2, "explosions": 1, "clouds": 2, "vsync": true, "max_fps": 0},
	{"scale": 1.0, "upscaler": 0, "aa": 2, "shadows": 2, "gi": 2, "ssao": true, "fog": true, "glow": true, "water": 2, "glass": 2, "explosions": 2, "clouds": 2, "vsync": true, "max_fps": 0},
]

# Player settings (persisted).
var player_name := "Yeeter"
var mouse_sensitivity := 0.0022
var fov := 100.0
var gore_level := 1 # 0 = off, 1 = silly, 2 = extreme
var auto_bhop := true
var always_run := false
var bot_skill := 1 # 0 = easy, 1 = normal, 2 = hard
var graphics := -1 # preset: 0 = low, 1 = medium, 2 = high, 3 = custom; -1 = pick automatically
## Detailed graphics options (see GFX_PRESETS); a preset fills them in, players can tweak each.
var gfx := {}
var stick_sensitivity := 1.0
var invert_y := false
var halloween := 1 # 0 = off, 1 = auto (mid October - early November), 2 = always
var third_person := false
var master_volume := 0.8
# Character look (-1 = random). The shirt colour applies in free-for-all modes only.
var look_hat := -1
var look_face := 0
var look_skin := -1
var look_color := -1
var look_character := 0
## Faces that blink and react (false: the classic, unchanging faces). Only changes what you see.
var expressive_faces := true
# Display (persisted). Window mode: 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
# (-1 = pick automatically: fullscreen on the Steam Deck, a window elsewhere).
var window_mode := -1
var window_size := 1 # index into WINDOW_SIZES (windowed only)
var monitor := -1 # -1 = the one the game opened on
var brightness := 1.0
var camera_shake := 1.0
var show_fps := false
## Map packs with scripts the player allowed ("file name:size" -> true; see MapPacks).
var trusted_packs := {}
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

# Session config (set by the menu before a match starts).
var mode: int = Mode.SANDBOX
var map := "facing" # built-in key or a map scene path under res://maps
var autostart := false
var spooky := false # Halloween theme active for the current match (decided by the server) # set by a map scene run with F6 (playtest)
var _map_cache: Array = []
var bot_count := 3
## Water look the host picks: "classic" or "sculpted" (see Liquid.style).
var water_style := "classic"
## Session override of every ocean's sea state (--sea calm|lake|ocean|stormy), not saved.
var sea_override := ""
## The host's environment pick for every map ("" = the map's own MapSettings.sky).
var sky_override := ""
## Build Prime and Facing from code instead of their Map Kit scenes (dev: --map-source code).
var code_maps := false
var join_address := "127.0.0.1"
var port := DEFAULT_PORT
var is_hosting := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	var cfg := ConfigFile.new()
	Controls.init(cfg if cfg.load(SETTINGS_PATH) == OK else null)
	if graphics < 0:
		graphics = 0 if is_steam_deck() else 2
	if window_mode < 0:
		window_mode = 1 if is_steam_deck() else 0
	apply_display()
	MapPacks.scan_and_mount(trusted_packs)
	if graphics <= 2 or gfx.is_empty():
		var saved := gfx
		gfx = GFX_PRESETS[clampi(graphics, 0, 2)].duplicate()
		if graphics == 3:
			gfx.merge(saved, true)
	apply_graphics()


## Window mode, size and monitor (not when headless: dev checks and servers).
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screens := DisplayServer.get_screen_count()
	var screen := DisplayServer.window_get_current_screen() if monitor < 0 else clampi(monitor, 0, screens - 1)
	if DisplayServer.window_get_current_screen() != screen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_current_screen(screen)
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var usable := DisplayServer.screen_get_usable_rect(screen)
			var size: Vector2i = WINDOW_SIZES[clampi(window_size, 0, WINDOW_SIZES.size() - 1)]
			size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


## F11 / Alt+Enter: fullscreen on and off (borderless; back to a window).
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		window_mode = 0 if window_mode != 0 else 1
		apply_display()
		save_settings()
		get_viewport().set_input_as_handled()


## The character choices sent to the server when joining.
func look() -> Dictionary:
	return {"hat": look_hat, "face": look_face, "skin": look_skin, "color": look_color, "character": look_character}


## Steam sets SteamDeck=1 for games launched on the Deck; SteamOS sets SteamOS=1.
func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1" or OS.get_environment("SteamOS") == "1"


## Switches to a graphics preset (0 low, 1 medium, 2 high): all detailed options follow.
func set_graphics_preset(preset: int) -> void:
	graphics = clampi(preset, 0, 2)
	gfx = GFX_PRESETS[graphics].duplicate()
	apply_graphics()


## Changes one detailed graphics option; the preset becomes "custom".
func set_gfx(key: String, value: Variant) -> void:
	gfx[key] = value
	graphics = 3
	for i in GFX_PRESETS.size():
		if GFX_PRESETS[i] == gfx:
			graphics = i
	apply_graphics()


## Viewport-level quality (resolution, upscaler, AA, shadow atlas, frame pacing). The
## environment and lights are handled by MapEnvironment and re-applied on settings_changed;
## water and glass read gfx when they are built.
func apply_graphics() -> void:
	var vp := get_viewport()
	if vp == null or gfx.is_empty():
		return
	var aa: int = gfx.aa
	var scale: float = gfx.scale
	vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2][clampi(gfx.upscaler, 0, 2)]
	if scale >= 0.999 and gfx.upscaler == 1:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR # FSR 1 at 100% only blurs
	vp.scaling_3d_scale = scale
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][clampi(aa, 0, 4)]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa in [1, 2, 3] else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa == 4 and gfx.upscaler != 2 # FSR 2 brings its own temporal pass
	RenderingServer.directional_shadow_atlas_set_size(4096 if gfx.shadows >= 2 else 2048, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if gfx.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(gfx.max_fps)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "sensitivity", mouse_sensitivity)
	cfg.set_value("player", "fov", fov)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "window_size", window_size)
	cfg.set_value("display", "monitor", monitor)
	cfg.set_value("display", "brightness", brightness)
	cfg.set_value("display", "camera_shake", camera_shake)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("maps", "trusted_packs", trusted_packs)
	cfg.set_value("player", "gore", gore_level)
	cfg.set_value("player", "auto_bhop", auto_bhop)
	cfg.set_value("player", "always_run", always_run)
	cfg.set_value("match", "bot_skill", bot_skill)
	cfg.set_value("match", "halloween", halloween)
	cfg.set_value("video", "graphics", graphics)
	for k in gfx:
		cfg.set_value("video_detail", k, gfx[k])
	cfg.set_value("player", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("player", "invert_y", invert_y)
	cfg.set_value("player", "third_person", third_person)
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("look", "hat", look_hat)
	cfg.set_value("look", "face", look_face)
	cfg.set_value("look", "skin", look_skin)
	cfg.set_value("look", "color", look_color)
	cfg.set_value("look", "character", look_character)
	cfg.set_value("look", "expressive", expressive_faces)
	cfg.set_value("net", "address", join_address)
	cfg.set_value("net", "port", port)
	cfg.set_value("match", "mode", mode)
	cfg.set_value("match", "bots", bot_count)
	cfg.set_value("match", "water_style", water_style)
	cfg.set_value("match", "sky", sky_override)
	cfg.set_value("match", "map", map)
	Controls.save(cfg)
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
	window_mode = cfg.get_value("display", "window_mode", window_mode)
	window_size = cfg.get_value("display", "window_size", window_size)
	monitor = cfg.get_value("display", "monitor", monitor)
	brightness = cfg.get_value("display", "brightness", brightness)
	camera_shake = cfg.get_value("display", "camera_shake", camera_shake)
	show_fps = cfg.get_value("display", "show_fps", show_fps)
	trusted_packs = cfg.get_value("maps", "trusted_packs", trusted_packs)
	gore_level = cfg.get_value("player", "gore", gore_level)
	auto_bhop = cfg.get_value("player", "auto_bhop", auto_bhop)
	always_run = cfg.get_value("player", "always_run", always_run)
	bot_skill = cfg.get_value("match", "bot_skill", bot_skill)
	halloween = cfg.get_value("match", "halloween", halloween)
	graphics = cfg.get_value("video", "graphics", graphics)
	if cfg.has_section("video_detail"):
		gfx = GFX_PRESETS[2].duplicate()
		for k in cfg.get_section_keys("video_detail"):
			if gfx.has(k):
				gfx[k] = cfg.get_value("video_detail", k)
	stick_sensitivity = cfg.get_value("player", "stick_sensitivity", stick_sensitivity)
	invert_y = cfg.get_value("player", "invert_y", invert_y)
	third_person = cfg.get_value("player", "third_person", third_person)
	master_volume = cfg.get_value("audio", "volume", master_volume)
	look_hat = cfg.get_value("look", "hat", look_hat)
	look_face = cfg.get_value("look", "face", look_face)
	look_skin = cfg.get_value("look", "skin", look_skin)
	look_color = cfg.get_value("look", "color", look_color)
	look_character = cfg.get_value("look", "character", look_character)
	expressive_faces = cfg.get_value("look", "expressive", expressive_faces)
	join_address = cfg.get_value("net", "address", join_address)
	port = cfg.get_value("net", "port", port)
	mode = cfg.get_value("match", "mode", mode)
	bot_count = cfg.get_value("match", "bots", bot_count)
	water_style = cfg.get_value("match", "water_style", water_style)
	sky_override = cfg.get_value("match", "sky", sky_override)
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
			if Arena.MAPKIT_SCENES.values().has(path):
				continue # a built-in map (listed above)
			out.append({"key": path, "name": _scene_map_name(path)})
	# Custom maps (map packs, and the Map Kit's work in progress): scenes with MapSettings.
	for path in MapPacks.custom_maps():
		var n := _scene_map_name(path, true)
		if n != "":
			out.append({"key": path, "name": n + "  (custom)", "custom": true})
	_map_cache = out
	return out


## Allows a map pack with scripts (the player said yes), loads it and lists its maps.
func allow_pack(info: Dictionary) -> bool:
	trusted_packs[MapPacks.key(info)] = true
	var ok := MapPacks.allow(info)
	_map_cache.clear()
	save_settings()
	return ok


func map_display_name(key: String) -> String:
	for m in list_maps():
		if m.key == key:
			return m.name
	return key.get_file().get_basename().capitalize()


## The map's name from its MapSettings (or the file name). only_maps: "" when it has none
## (a model scene in a custom map's folder is not a map).
func _scene_map_name(path: String, only_maps := false) -> String:
	var packed := load(path) as PackedScene
	if packed:
		var root := packed.instantiate()
		var n := _find_map_name(root)
		root.free()
		if n != "":
			return n
	return "" if only_maps else path.get_file().get_basename().capitalize()


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
	_key("use", [KEY_E]) # (shares E: rotating needs something held, using needs empty hands)
	for i in range(1, 10):
		_key("slot_%d" % i, [KEY_0 + i])
	_mouse("gun_grab", MOUSE_BUTTON_LEFT)
	_mouse("gun_throw", MOUSE_BUTTON_RIGHT)
	_key("grapple", [KEY_G])
	_mouse("grapple", MOUSE_BUTTON_MIDDLE)
	_pad("grapple", JOY_BUTTON_RIGHT_STICK)
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
	_pad("use", JOY_BUTTON_X)
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
