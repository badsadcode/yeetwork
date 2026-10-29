class_name MainMenu
extends Control
## Title screen over the key art: logo, a column of big buttons (Play, Join, Character,
## Options) and a framed panel showing the chosen page.

signal host_pressed
signal join_pressed
signal quit_pressed

var _status: Label
var _logo: TextureRect
var _bg: TextureRect
var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _mode: OptionButton
var _map: OptionButton
var _spooky: OptionButton
var _water: OptionButton
var _sky: OptionButton
var _bots: SpinBox
var _pages := {}
var _page_title: Label
var _preview: CharacterPreview
var _pickers := {}
var _compact := false
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_compact = get_viewport_rect().size.y < 880.0 # Steam Deck is 1280x800

	_bg = TextureRect.new()
	_bg.texture = preload("res://assets/ui/menu_bg.png")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	# Darken the left side a little so the buttons read on the busy art.
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.03, 0.12, 0.55))
	g.set_color(1, Color(0.05, 0.03, 0.12, 0.0))
	grad.gradient = g
	grad.fill_to = Vector2(1, 0)
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.45
	add_child(shade)

	_logo = TextureRect.new()
	_logo.texture = preload("res://assets/ui/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_anchor(_logo, 0.27, 0.0, 0.73, 0.3)
	add_child(_logo)

	# Left: the big buttons.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10 if _compact else 16)
	_anchor(col, 0.03, 0.36, 0.3, 0.97)
	add_child(col)
	var play := _big_button(col, "PLAY", "YellowButton")
	var join := _big_button(col, "JOIN", "BlueButton")
	var chara := _big_button(col, "CHARACTER", "RedButton")
	var opts := _big_button(col, "OPTIONS", "GreyButton")
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(150, 44 if _compact else 52)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit.pressed.connect(func(): quit_pressed.emit())
	col.add_child(quit)

	# Right: the framed page panel.
	var panel := PanelContainer.new()
	_anchor(panel, 0.34, 0.31, 0.97, 0.94)
	add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8 if _compact else 12)
	panel.add_child(pv)
	_page_title = Label.new()
	_page_title.add_theme_font_size_override("font_size", 30 if _compact else 40)
	_page_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	_page_title.add_theme_constant_override("outline_size", 8)
	pv.add_child(_page_title)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(stack)
	_pages.play = _page_play(stack)
	_pages.join = _page_join(stack)
	_pages.character = _page_character(stack)
	_pages.options = _page_options(stack)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_status.add_theme_font_size_override("font_size", 22)
	_anchor(_status, 0.34, 0.94, 0.97, 1.0)
	add_child(_status)

	play.pressed.connect(_show_page.bind("play", true))
	join.pressed.connect(_show_page.bind("join", true))
	chara.pressed.connect(_show_page.bind("character", true))
	opts.pressed.connect(_show_page.bind("options", true))
	for b in [play, join, chara, opts]:
		b.focus_entered.connect(func(): _show_page(_page_of(b), false))
	play.ready.connect(play.grab_focus, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	# --menu-page <name> opens a page directly (screenshots, testing).
	var args := OS.get_cmdline_user_args()
	var i := args.find("--menu-page")
	_show_page(args[i + 1] if i >= 0 and i + 1 < args.size() and _pages.has(args[i + 1]) else "play", false)


func _page_of(b: Button) -> String:
	return {"PLAY": "play", "JOIN": "join", "CHARACTER": "character", "OPTIONS": "options"}[b.text]


## Shows a page; with focus_it the first control of the page takes the focus (gamepads).
func _show_page(page: String, focus_it: bool) -> void:
	for k in _pages:
		_pages[k].visible = k == page
	_page_title.text = {"play": "Start a match", "join": "Join a friend", "character": "Your character", "options": "Options"}[page]
	if focus_it:
		var first := _first_focusable(_pages[page])
		if first:
			first.grab_focus()


func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).visible and not (c is Label):
			return c
		var f := _first_focusable(c)
		if f:
			return f
	return null


func _page_play(stack: Control) -> Control:
	var v := _page(stack)
	var grid := _grid(v)
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
	_spooky = OptionButton.new()
	for item in ["Off", "Auto (Halloween season)", "Always"]:
		_spooky.add_item(item)
	_spooky.selected = Game.halloween
	_field(grid, "Spooky mode", _spooky)
	_water = OptionButton.new()
	for item in ["Classic", "Sculpted (new)"]:
		_water.add_item(item)
	_water.selected = 1 if Game.water_style == "sculpted" else 0
	_field(grid, "Water style", _water)
	_sky = OptionButton.new()
	_sky.add_item("Map's own")
	for i in MapEnvironment.PRESETS.size():
		_sky.add_item(String(MapEnvironment.PRESETS[i]).capitalize())
		if MapEnvironment.PRESETS[i] == Game.sky_override:
			_sky.selected = i + 1
	if Game.sky_override == "":
		_sky.selected = 0
	_field(grid, "Environment", _sky)
	_spacer(v)
	var host := _action_button(v, "START MATCH", "YellowButton")
	host.pressed.connect(func():
		_store()
		host_pressed.emit())
	var hint := Label.new()
	hint.text = "Friends on your network join you with the address shown in the pause menu."
	hint.add_theme_font_size_override("font_size", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v


func _page_join(stack: Control) -> Control:
	var v := _page(stack)
	var grid := _grid(v)
	_address = LineEdit.new()
	_address.text = Game.join_address
	_address.placeholder_text = "IP address"
	_field(grid, "Address", _address)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Game.port
	_field(grid, "Port (host & join)", _port)
	_spacer(v)
	var join := _action_button(v, "JOIN", "BlueButton")
	join.pressed.connect(func():
		_store()
		join_pressed.emit())
	var hint := Label.new()
	hint.text = "Over the internet: forward UDP port %d on the host's router, or use Tailscale / ZeroTier." % Game.DEFAULT_PORT
	hint.add_theme_font_size_override("font_size", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v


func _page_character(stack: Control) -> Control:
	var page := _page(stack)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	page.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	h.add_child(left)
	_preview = CharacterPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6 if _compact else 10)
	h.add_child(v)
	_name = LineEdit.new()
	_name.text = Game.player_name
	_name.max_length = 20
	_name.placeholder_text = "Your name"
	var grid := _grid(v)
	_field(grid, "Name", _name)
	var hats := ["Random"] + CharacterModel.HAT_NAMES.slice(0, CharacterModel.PLAYER_HATS)
	var skins := ["Random"] + CharacterModel.SKIN_NAMES
	var colors := ["Auto"]
	for i in Game.FFA_COLORS.size():
		colors.append("Colour %d" % (i + 1))
	_picker(grid, "hat", "Hat", hats, Game.look_hat + 1)
	_picker(grid, "face", "Head extra", CharacterModel.FACE_NAMES, Game.look_face)
	_picker(grid, "skin", "Skin", skins, Game.look_skin + 1)
	_picker(grid, "color", "Shirt", colors, Game.look_color + 1)
	_picker(grid, "faces", "Faces", ["Expressive", "Classic"], 0 if Game.expressive_faces else 1)
	var note := Label.new()
	note.text = "Shirt: free-for-all only (teams wear team colours). Faces: only on your screen."
	note.add_theme_font_size_override("font_size", 15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	_spacer(v)
	var rnd := _action_button(left, "SURPRISE ME", "GreenButton")
	rnd.custom_minimum_size.x = 0
	rnd.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rnd.pressed.connect(func():
		_set_pick("hat", randi() % (CharacterModel.PLAYER_HATS + 1))
		_set_pick("face", randi() % CharacterModel.FACE_NAMES.size())
		_set_pick("skin", randi() % (CharacterModel.SKINS.size() + 1))
		_set_pick("color", randi() % (Game.FFA_COLORS.size() + 1)))
	_update_preview.call_deferred()
	return page


func _page_options(stack: Control) -> Control:
	var page := _page(stack)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	v.add_child(SettingsForm.build_settings_controls())
	var help := Label.new()
	help.text = "WASD move · Shift run · Ctrl/C crouch (slide while running) · Space jump / swim up\nLMB grab / pull / catch · RMB throw (hold to charge) or punt\nWheel push/pull held · E + mouse rotate · F freeze · Q spawn · V camera\nPad: LT grab · RT throw · A jump · B crouch/slide · L3 run · LB rotate"
	help.add_theme_font_size_override("font_size", 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_label("Controls"))
	v.add_child(help)
	return page


# --- Character pickers ------------------------------------------------------------

## "< value >" row: arrows step through the choices (gamepad friendly).
func _picker(grid: GridContainer, key: String, title: String, names: Array, index: int) -> void:
	grid.add_child(_label(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(row)
	var prev := Button.new()
	prev.text = "<"
	prev.custom_minimum_size = Vector2(52, 0)
	row.add_child(prev)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 20)
	row.add_child(value)
	var next := Button.new()
	next.text = ">"
	next.custom_minimum_size = Vector2(52, 0)
	row.add_child(next)
	_pickers[key] = {"names": names, "index": clampi(index, 0, names.size() - 1), "label": value}
	prev.pressed.connect(func(): _set_pick(key, _pickers[key].index - 1))
	next.pressed.connect(func(): _set_pick(key, _pickers[key].index + 1))
	value.text = names[_pickers[key].index]


func _set_pick(key: String, index: int) -> void:
	var p: Dictionary = _pickers[key]
	p.index = posmod(index, p.names.size())
	p.label.text = p.names[p.index]
	Game.look_hat = _pickers.hat.index - 1
	Game.look_face = _pickers.face.index
	Game.look_skin = _pickers.skin.index - 1
	Game.look_color = _pickers.color.index - 1
	Game.expressive_faces = _pickers.faces.index == 0
	_update_preview()


func _update_preview() -> void:
	var shirt: Color = Game.FFA_COLORS[maxi(Game.look_color, 0) % Game.FFA_COLORS.size()]
	var hat := Game.look_hat if Game.look_hat >= 0 else 0
	_preview.show_look(shirt, hat, Game.look_face, Game.look_skin, 1)


# --- Building blocks --------------------------------------------------------------

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


func _page(stack: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8 if _compact else 12)
	v.visible = false
	stack.add_child(v)
	return v


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8 if _compact else 12)
	parent.add_child(grid)
	return grid


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	return l


func _field(grid: GridContainer, text: String, control: Control) -> void:
	grid.add_child(_label(text))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = 40 if _compact else 48
	grid.add_child(control)


func _spacer(parent: Control) -> void:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(s)


func _big_button(parent: Control, text: String, variation: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size.y = 62 if _compact else 84
	b.add_theme_font_size_override("font_size", 30 if _compact else 40)
	parent.add_child(b)
	return b


func _action_button(parent: Control, text: String, variation: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(300 if _compact else 360, 56 if _compact else 68)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 26 if _compact else 32)
	parent.add_child(b)
	return b


func _store() -> void:
	Game.player_name = _name.text.strip_edges() if not _name.text.strip_edges().is_empty() else "Yeeter"
	Game.mode = _mode.selected
	Game.halloween = _spooky.selected
	Game.water_style = "sculpted" if _water.selected == 1 else "classic"
	Game.sky_override = "" if _sky.selected <= 0 else MapEnvironment.PRESETS[_sky.selected - 1]
	Game.map = _map.get_item_metadata(_map.selected) if _map.selected >= 0 else "facing"
	Game.bot_count = int(_bots.value)
	Game.port = int(_port.value)
	Game.join_address = _address.text.strip_edges()
	Game.save_settings()


func set_status(text: String) -> void:
	_status.text = text


func _process(delta: float) -> void:
	_time += delta
	_logo.pivot_offset = _logo.size * 0.5
	_logo.rotation = sin(_time * 1.1) * 0.015
	_logo.scale = Vector2.ONE * (1.0 + sin(_time * 2.2) * 0.015)
	# Slow drift over the key art.
	_bg.pivot_offset = _bg.size * 0.5
	_bg.scale = Vector2.ONE * (1.04 + sin(_time * 0.12) * 0.02)
	_bg.position = Vector2(sin(_time * 0.09) * 12.0, cos(_time * 0.07) * 8.0)
