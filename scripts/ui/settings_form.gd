class_name SettingsForm
extends RefCounted
## Builds the player settings controls shared by the main menu and the pause menu.


static func build_settings_controls() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 8)

	_row(g, "Mouse sensitivity", _slider(0.0005, 0.006, 0.0001, Game.mouse_sensitivity, func(v): Game.mouse_sensitivity = v))
	_row(g, "Field of view", _slider(70.0, 120.0, 1.0, Game.fov, func(v): Game.fov = v))
	_row(g, "Volume", _slider(0.0, 1.0, 0.01, Game.master_volume, func(v):
		Game.master_volume = v
		Game.apply_audio()))
	_row(g, "Stick sensitivity", _slider(0.3, 3.0, 0.05, Game.stick_sensitivity, func(v): Game.stick_sensitivity = v))
	var inv := CheckBox.new()
	inv.text = "Invert stick Y"
	inv.button_pressed = Game.invert_y
	inv.toggled.connect(func(on): Game.invert_y = on)
	_row(g, "Invert Y", inv)
	var gfx := OptionButton.new()
	for item in ["Low (Steam Deck)", "Medium", "High"]:
		gfx.add_item(item)
	gfx.selected = clampi(Game.graphics, 0, 2)
	gfx.item_selected.connect(func(i):
		Game.graphics = i
		Game.apply_graphics()
		Game.settings_changed.emit())
	_row(g, "Graphics", gfx)
	var gore := OptionButton.new()
	for item in ["Off (confetti)", "Silly", "EXTREME"]:
		gore.add_item(item)
	gore.selected = Game.gore_level
	gore.item_selected.connect(func(i): Game.gore_level = i)
	_row(g, "Blood & gore", gore)
	var bhop := CheckBox.new()
	bhop.text = "Hold jump to bunny hop"
	bhop.button_pressed = Game.auto_bhop
	bhop.toggled.connect(func(on): Game.auto_bhop = on)
	_row(g, "Auto hop", bhop)
	return g


static func _row(g: GridContainer, text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	g.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = 220
	g.add_child(control)


static func _slider(min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.value_changed.connect(on_change)
	return s
