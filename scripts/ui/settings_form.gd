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
	_graphics_rows(g)
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
	var run := CheckBox.new()
	run.text = "Run by default (Shift walks)"
	run.button_pressed = Game.always_run
	run.toggled.connect(func(on): Game.always_run = on)
	_row(g, "Always run", run)
	var skill := OptionButton.new()
	for item in ["Easy", "Normal", "Hard"]:
		skill.add_item(item)
	skill.selected = clampi(Game.bot_skill, 0, 2)
	skill.item_selected.connect(func(i): Game.bot_skill = i)
	_row(g, "Bot skill (host)", skill)
	return g


const SCALES := [0.5, 0.6, 0.67, 0.75, 0.85, 0.9, 1.0]
const FPS_CAPS := [0, 30, 40, 60, 90, 120, 144]


## Graphics preset plus every detailed option. Picking a preset updates the details;
## changing a detail turns the preset into "Custom".
static func _graphics_rows(g: GridContainer) -> void:
	var refresh: Array[Callable] = []
	var preset := OptionButton.new()
	for item in ["Low (Steam Deck)", "Medium", "High", "Custom"]:
		preset.add_item(item)
	preset.set_item_disabled(3, true)
	_row(g, "Graphics", preset)
	var sync := func():
		preset.selected = clampi(Game.graphics, 0, 3)
		for f in refresh:
			f.call()
	preset.item_selected.connect(func(i):
		if i <= 2:
			Game.set_graphics_preset(i)
			sync.call()
			Game.settings_changed.emit())
	var head := Label.new()
	head.text = "Graphics details"
	head.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	g.add_child(head)
	g.add_child(Control.new())
	var opt := func(title: String, key: String, items: Array, values: Array) -> void:
		var o := OptionButton.new()
		for item in items:
			o.add_item(item)
		_row(g, title, o)
		var show := func():
			var i := values.find(Game.gfx.get(key))
			if i < 0: # e.g. a resolution typed into the settings file: pick the closest
				i = 0
				for j in values.size():
					if absf(float(values[j]) - float(Game.gfx.get(key, 0))) < absf(float(values[i]) - float(Game.gfx.get(key, 0))):
						i = j
			o.selected = i
		show.call()
		refresh.append(show)
		o.item_selected.connect(func(i):
			Game.set_gfx(key, values[i])
			sync.call()
			Game.settings_changed.emit())
	var check := func(title: String, key: String, text: String) -> void:
		var c := CheckBox.new()
		c.text = text
		_row(g, title, c)
		var show := func(): c.set_pressed_no_signal(bool(Game.gfx.get(key)))
		show.call()
		refresh.append(show)
		c.toggled.connect(func(on):
			Game.set_gfx(key, on)
			sync.call()
			Game.settings_changed.emit())
	var pct := []
	for v in SCALES:
		pct.append("%d%%" % roundi(v * 100.0))
	opt.call("Resolution", "scale", pct, SCALES)
	opt.call("Upscaler", "upscaler", ["Bilinear", "AMD FSR 1", "AMD FSR 2"], [0, 1, 2])
	opt.call("Anti-aliasing", "aa", ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"], [0, 1, 2, 3, 4])
	opt.call("Shadows", "shadows", ["Off", "Low", "High"], [0, 1, 2])
	opt.call("Lighting", "gi", ["Basic", "Bounce light (SSIL)", "Full GI (SDFGI + SSIL)"], [0, 1, 2])
	check.call("Ambient occlusion", "ssao", "Soft contact shadows (SSAO)")
	check.call("Volumetric fog", "fog", "Light shafts in the air")
	check.call("Bloom", "glow", "Glow around bright lights")
	opt.call("Water", "water", ["Low", "Medium", "High"], [0, 1, 2])
	opt.call("Glass", "glass", ["Simple", "Refraction", "Refraction + reflections"], [0, 1, 2])
	opt.call("Explosions", "explosions", ["Simple", "Volumetric", "Volumetric high"], [0, 1, 2])
	opt.call("Clouds", "clouds", ["Off", "Few", "Many"], [0, 1, 2])
	check.call("VSync", "vsync", "Sync to the display (no tearing)")
	var caps := ["Unlimited"]
	for v in FPS_CAPS.slice(1):
		caps.append("%d FPS" % v)
	opt.call("Frame rate cap", "max_fps", caps, FPS_CAPS)
	var note := Label.new()
	note.text = "Water detail, glass and clouds apply from the next match."
	note.add_theme_font_size_override("font_size", 14)
	g.add_child(Control.new())
	g.add_child(note)
	sync.call()


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
