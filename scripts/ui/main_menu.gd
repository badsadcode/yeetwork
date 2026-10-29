class_name MainMenu
extends Control
## Title screen: name, match setup, host/join and settings.

signal host_pressed
signal join_pressed
signal quit_pressed

var _status: Label
var _title: Label
var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _mode: OptionButton
var _map: OptionButton
var _spooky: OptionButton
var _bots: SpinBox
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.08, 0.3))
	g.set_color(1, Color(0.95, 0.45, 0.55))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0.3, 1)
	var tr := TextureRect.new()
	tr.texture = grad
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	var compact := get_viewport_rect().size.y < 880.0 # Steam Deck is 1280x800
	col.add_theme_constant_override("separation", 6 if compact else 14)
	center.add_child(col)

	_title = Label.new()
	_title.text = "YEETWORK"
	var ls := LabelSettings.new()
	ls.font_size = 72 if compact else 110
	ls.font_color = Color(1, 0.86, 0.3)
	ls.outline_size = 22
	ls.outline_color = Color(0.25, 0.05, 0.3)
	ls.shadow_size = 8
	ls.shadow_offset = Vector2(6, 8)
	ls.shadow_color = Color(0, 0, 0, 0.4)
	_title.label_settings = ls
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var sub := Label.new()
	sub.text = "a physics playground of spectacularly unfortunate accidents"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	col.add_child(sub)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.18, 0.88)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16 if compact else 24)
	sb.border_color = Color(1, 0.55, 0.85)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 36)
	panel.add_child(h)

	# Left: match.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 380
	h.add_child(left)
	_header(left, "Play")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	_name = LineEdit.new()
	_name.text = Game.player_name
	_name.max_length = 20
	_field(grid, "Name", _name)
	_mode = OptionButton.new()
	for m in Game.MODE_NAMES:
		_mode.add_item(m)
	_mode.selected = Game.mode
	_field(grid, "Mode", _mode)
	_map = OptionButton.new()
	var maps := Game.list_maps()
	for i in maps.size():
		_map.add_item(maps[i].name)
		_map.set_item_metadata(i, maps[i].key)
		if maps[i].key == Game.map:
			_map.selected = i
	_field(grid, "Map", _map)
	_bots = SpinBox.new()
	_bots.min_value = 0
	_bots.max_value = 11
	_bots.value = Game.bot_count
	_field(grid, "Bots", _bots)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Game.port
	_field(grid, "Port", _port)
	_spooky = OptionButton.new()
	for item in ["Off", "Auto (Halloween season)", "Always"]:
		_spooky.add_item(item)
	_spooky.selected = Game.halloween
	_field(grid, "Spooky mode", _spooky)
	var host := _button(left, "HOST / PLAY")
	host.ready.connect(host.grab_focus, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	host.pressed.connect(func():
		_store()
		host_pressed.emit())
	_header(left, "Join a friend")
	_address = LineEdit.new()
	_address.text = Game.join_address
	_address.placeholder_text = "IP address"
	left.add_child(_address)
	var join := _button(left, "JOIN")
	join.pressed.connect(func():
		_store()
		join_pressed.emit())

	# Right: settings + controls.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size.x = 420
	h.add_child(right)
	_header(right, "Settings")
	right.add_child(SettingsForm.build_settings_controls())
	_header(right, "Controls")
	var help := Label.new()
	help.text = "WASD move · Space jump (hold = bhop) · Ctrl/Shift slide\nRun along walls to wall-run; jump off to wall-jump\nLMB hold: grab / pull / catch (players too!)\nRMB: throw held thing, or punt; punt a wall to gravity-jump\nF freeze prop · Q spawn prop (1-9) · V camera · Tab scores\nPad: LT grab · RT throw · A jump · B slide · Y spawn · RB freeze · D-pad view/props"
	help.add_theme_font_size_override("font_size", 15)
	right.add_child(help)
	var quit := _button(right, "Quit")
	quit.pressed.connect(func(): quit_pressed.emit())

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	_status.add_theme_font_size_override("font_size", 20)
	col.add_child(_status)


func _header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 0.75, 0.9))
	parent.add_child(l)


func _field(grid: GridContainer, text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 50
	b.add_theme_font_size_override("font_size", 22)
	parent.add_child(b)
	return b


func _store() -> void:
	Game.player_name = _name.text.strip_edges() if not _name.text.strip_edges().is_empty() else "Yeeter"
	Game.mode = _mode.selected
	Game.halloween = _spooky.selected
	Game.map = _map.get_item_metadata(_map.selected) if _map.selected >= 0 else "facing"
	Game.bot_count = int(_bots.value)
	Game.port = int(_port.value)
	Game.join_address = _address.text.strip_edges()
	Game.save_settings()


func set_status(text: String) -> void:
	_status.text = text


func _process(delta: float) -> void:
	_time += delta
	_title.rotation = sin(_time * 1.3) * 0.03
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * (1.0 + sin(_time * 2.6) * 0.02)
