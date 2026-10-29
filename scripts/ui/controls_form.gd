class_name ControlsForm
extends VBoxContainer
## Rebinding UI (Options page and pause menu): every action with a keyboard/mouse button and
## a gamepad button. Click one, then press the new key, mouse button, pad button or trigger
## (Esc cancels). "Swap mouse buttons" trades grab and throw; "Reset" restores the defaults.

var _rows := {} # action -> [kb Button, pad Button]
var _listening: Button
var _listen_action := ""
var _listen_pad := false
var _status: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	add_child(tools)
	var swap := Button.new()
	swap.text = "Swap mouse buttons"
	swap.tooltip_text = "Grab on the right button, throw on the left (or back)"
	swap.pressed.connect(func():
		Controls.swap_mouse_buttons()
		_after_change("Mouse buttons swapped: grab %s, throw %s" % [Controls.key_of("gun_grab"), Controls.key_of("gun_throw")]))
	tools.add_child(swap)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(func():
		Controls.reset_all()
		_after_change("Controls reset to the defaults"))
	tools.add_child(reset)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Click a binding, then press the new key or button (Esc cancels)."
	add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	var section := ""
	for a in Controls.ACTIONS:
		if a[2] != section:
			section = a[2]
			var h := Label.new()
			h.text = section
			h.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
			grid.add_child(h)
			var kb_h := Label.new()
			kb_h.text = "Keyboard / mouse" if section == "Movement" else ""
			kb_h.add_theme_font_size_override("font_size", 14)
			grid.add_child(kb_h)
			var pad_h := Label.new()
			pad_h.text = "Gamepad" if section == "Movement" else ""
			pad_h.add_theme_font_size_override("font_size", 14)
			grid.add_child(pad_h)
		var l := Label.new()
		l.text = a[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var kb := _bind_button(a[0], false)
		var pad := _bind_button(a[0], true)
		grid.add_child(kb)
		grid.add_child(pad)
		_rows[a[0]] = [kb, pad]
	_refresh()


func _bind_button(action: String, pad: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 38)
	b.clip_text = true
	b.pressed.connect(func():
		if _listening:
			_listening.button_pressed = false
		_listening = b
		_listen_action = action
		_listen_pad = pad
		b.text = "Press a %s..." % ("button" if pad else "key")
		_status.text = "Rebinding '%s': press the new %s (Esc cancels)." % [_label_of(action), "gamepad button or trigger" if pad else "key or mouse button"])
	return b


func _input(event: InputEvent) -> void:
	if _listening == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_stop("Cancelled.")
		get_viewport().set_input_as_handled()
		return
	var ev: InputEvent = null
	if not _listen_pad:
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var k := InputEventKey.new()
			k.physical_keycode = (event as InputEventKey).physical_keycode
			ev = k
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var m := InputEventMouseButton.new()
			m.button_index = (event as InputEventMouseButton).button_index
			ev = m
	else:
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			var j := InputEventJoypadButton.new()
			j.button_index = (event as InputEventJoypadButton).button_index
			ev = j
		elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
			var a := InputEventJoypadMotion.new()
			a.axis = (event as InputEventJoypadMotion).axis
			a.axis_value = signf((event as InputEventJoypadMotion).axis_value)
			ev = a
	if ev == null:
		return
	get_viewport().set_input_as_handled()
	var action := _listen_action
	Controls.rebind(action, ev)
	var also := Controls.conflicts(action, ev)
	_listening = null
	_after_change("%s: %s%s" % [_label_of(action), Controls.event_name(ev), ("  (also used by: %s)" % ", ".join(also)) if not also.is_empty() else ""])


func _stop(msg: String) -> void:
	_listening = null
	_status.text = msg
	_refresh()


func _after_change(msg: String) -> void:
	Game.save_settings()
	_status.text = msg
	_refresh()


func _refresh() -> void:
	for action in _rows:
		_rows[action][0].text = Controls.key_of(action)
		_rows[action][1].text = Controls.pad_of(action)


func _label_of(action: String) -> String:
	for a in Controls.ACTIONS:
		if a[0] == action:
			return a[1]
	return action
