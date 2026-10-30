class_name Controls
extends RefCounted
## Rebindable controls. Game._setup_input() builds the default InputMap; Controls remembers
## those defaults, applies the player's saved bindings over them (settings.cfg [controls]),
## and gives the UI names for actions and events. Every action has one keyboard-or-mouse
## binding and one gamepad binding that the player can change; the defaults' extra keys
## (arrow keys, C for crouch) stay until that binding is changed.

## Rebindable actions in menu order: [action, label, section].
const ACTIONS := [
	["move_forward", "Move forward", "Movement"],
	["move_back", "Move back", "Movement"],
	["move_left", "Move left", "Movement"],
	["move_right", "Move right", "Movement"],
	["jump", "Jump / swim up", "Movement"],
	["crouch", "Crouch / slide / dive", "Movement"],
	["run", "Run (hold)", "Movement"],
	["run_toggle", "Run (toggle)", "Movement"],
	["gun_grab", "Grab / pull / catch", "Gravity gun"],
	["gun_throw", "Throw (hold to charge) / punt", "Gravity gun"],
	["rotate_held", "Rotate held object", "Gravity gun"],
	["hold_farther", "Push held object", "Gravity gun"],
	["hold_closer", "Pull held object", "Gravity gun"],
	["freeze_prop", "Freeze held prop", "Gravity gun"],
	["spawn_prop", "Spawn prop (sandbox)", "Sandbox"],
	["next_slot", "Next prop", "Sandbox"],
	["prev_slot", "Previous prop", "Sandbox"],
	["use", "Use / interact (empty hands)", "Other"],
	["toggle_view", "Third-person camera", "Other"],
	["scoreboard", "Scoreboard", "Other"],
	["suicide", "Respawn", "Other"],
	["pause", "Menu", "Other"],
]

static var _defaults := {} # action -> Array[InputEvent]


## Call once after the default InputMap is built, then apply saved bindings.
static func init(cfg: ConfigFile) -> void:
	_defaults.clear()
	for a in ACTIONS:
		var list: Array = []
		for ev in InputMap.action_get_events(a[0]):
			list.append(ev.duplicate())
		_defaults[a[0]] = list
	if cfg == null or not cfg.has_section("controls"):
		return
	for a in ACTIONS:
		if cfg.has_section_key("controls", a[0]):
			_apply(a[0], cfg.get_value("controls", a[0]))


static func save(cfg: ConfigFile) -> void:
	for a in ACTIONS:
		var list: Array = []
		for ev in InputMap.action_get_events(a[0]):
			var d := encode(ev)
			if not d.is_empty():
				list.append(d)
		cfg.set_value("controls", a[0], list)


## True for gamepad events, false for keyboard and mouse.
static func is_pad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


## The binding of one kind (gamepad or not) for an action: its first event, or null.
static func binding(action: String, pad: bool) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if is_pad(ev) == pad:
			return ev
	return null


## Replaces an action's keyboard/mouse (or gamepad) events with ev.
static func rebind(action: String, ev: InputEvent) -> void:
	var pad := is_pad(ev)
	for old in InputMap.action_get_events(action):
		if is_pad(old) == pad:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)


## Other actions already using this event (a warning, not an error: some share on purpose).
## Actions that may share a key: one needs empty hands, the others something held.
const SHARED := [["use", "rotate_held"], ["use", "freeze_prop"]]


static func conflicts(action: String, ev: InputEvent) -> Array[String]:
	var out: Array[String] = []
	for a in ACTIONS:
		if a[0] == action or SHARED.has([action, a[0]]) or SHARED.has([a[0], action]):
			continue
		for other in InputMap.action_get_events(a[0]):
			if _same(other, ev):
				out.append(a[1])
	return out


static func reset_all() -> void:
	for a in ACTIONS:
		InputMap.action_erase_events(a[0])
		for ev in _defaults.get(a[0], []):
			InputMap.action_add_event(a[0], ev.duplicate())


## The quick option: left and right mouse buttons trade places on the gravity gun.
static func swap_mouse_buttons() -> void:
	var g := binding("gun_grab", false)
	var t := binding("gun_throw", false)
	if g and t:
		rebind("gun_grab", t.duplicate())
		rebind("gun_throw", g.duplicate())


## Short human name of an event ("Space", "LMB", "LT", "Left stick up"...).
static func event_name(ev: InputEvent) -> String:
	if ev == null:
		return "-"
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		# The key's name on this keyboard layout (headless runs can't ask the OS: US names).
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
			MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
			MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}.get((ev as InputEventMouseButton).button_index, "Mouse %d" % (ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton:
		return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "View",
			JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
			JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
			JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_GUIDE: "Guide"}.get((ev as InputEventJoypadButton).button_index, "Button %d" % (ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		var neg := m.axis_value < 0.0
		match m.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X:
				return "LS " + ("left" if neg else "right")
			JOY_AXIS_LEFT_Y:
				return "LS " + ("up" if neg else "down")
			JOY_AXIS_RIGHT_X:
				return "RS " + ("left" if neg else "right")
			JOY_AXIS_RIGHT_Y:
				return "RS " + ("up" if neg else "down")
		return "Axis %d %s" % [m.axis, "-" if neg else "+"]
	return ev.as_text()


## The keyboard/mouse name of an action's binding, for hints ("LMB", "F").
static func key_of(action: String) -> String:
	return event_name(binding(action, false))


static func pad_of(action: String) -> String:
	return event_name(binding(action, true))


static func encode(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		return ["key", (ev as InputEventKey).physical_keycode]
	if ev is InputEventMouseButton:
		return ["mouse", (ev as InputEventMouseButton).button_index]
	if ev is InputEventJoypadButton:
		return ["joy", (ev as InputEventJoypadButton).button_index]
	if ev is InputEventJoypadMotion:
		return ["axis", (ev as InputEventJoypadMotion).axis, signf((ev as InputEventJoypadMotion).axis_value)]
	return []


static func decode(d: Array) -> InputEvent:
	if d.is_empty():
		return null
	match d[0]:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d[1])
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d[1])
			return m
		"joy":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d[1])
			return j
		"axis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(d[1])
			a.axis_value = float(d[2])
			return a
	return null


static func _apply(action: String, list: Array) -> void:
	InputMap.action_erase_events(action)
	for d in list:
		var ev := decode(d)
		if ev:
			InputMap.action_add_event(action, ev)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	var ea := encode(a)
	var eb := encode(b)
	return not ea.is_empty() and ea == eb
