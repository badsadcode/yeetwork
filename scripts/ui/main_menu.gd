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
var _rules: OptionButton
var _minutes: OptionButton
var _knock: OptionButton
var _pickups: OptionButton
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
	if "--noor" in args: # (screenshots: the Character page with Noor picked)
		_set_pick.call_deferred("character", CharacterModel.NOOR)
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
	# The options scroll if they don't fit (Yeetball adds two); START MATCH stays in view.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)
	var grid := _grid(scroll)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode = OptionButton.new()
	for m in Game.MODE_NAMES:
		_mode.add_item(m)
	_mode.selected = Game.mode
	_field(grid, "Mode", _mode)
	_map = OptionButton.new()
	_fill_maps()
	_field(grid, "Map", _map)
	_bots = SpinBox.new()
	_bots.min_value = 0
	_bots.max_value = 11
	_bots.value = Game.bot_count
	_field(grid, "Bots", _bots)
	_pickups = OptionButton.new()
	for item in ["First aid + power-ups", "First aid only", "None"]:
		_pickups.add_item(item)
	_pickups.selected = clampi(Game.pickups, 0, 2)
	_pickups.tooltip_text = "The pickups a map has: first aid kits, and power-ups (speed, Super Yeet, feather, Iron Yeet)."
	_field(grid, "Pickups", _pickups)
	_rules = OptionButton.new()
	for item in ["Classic Chaos", "TOTAL YEET"]:
		_rules.add_item(item)
	_rules.selected = clampi(Game.yeetball_rules, 0, 1)
	_rules.tooltip_text = "Classic Chaos: recognisable football with gravity guns.
TOTAL YEET: longer holds, a faster ball, multi-ball and barrels from the sky."
	_field(grid, "Sport rules", _rules)
	_minutes = OptionButton.new()
	for m: int in Game.MATCH_LENGTHS:
		_minutes.add_item("First to 5 goals" if m == 0 else "%d minutes" % m)
	_minutes.selected = maxi(Game.MATCH_LENGTHS.find(Game.match_minutes), 0)
	_field(grid, "Match length", _minutes)
	_knock = OptionButton.new()
	for item in ["A harmless bonk", "Knocks them over"]:
		_knock.add_item(item)
	_knock.selected = 1 if Game.ball_knockdown else 0
	_knock.tooltip_text = "Never hurts. Knocked over, you tumble for a moment.
TOTAL YEET always knocks players over."
	_field(grid, "Ball hits players", _knock)
	var sport_only := func(i: int) -> void:
		var on := Game.is_sport(i)
		for c: Control in [_rules, _minutes, _knock]:
			c.visible = on
			grid.get_child(c.get_index() - 1).visible = on # its label
	_mode.item_selected.connect(sport_only)
	sport_only.call(_mode.selected)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var host := _action_button(row, "START MATCH", "YellowButton")
	host.pressed.connect(func():
		_store()
		host_pressed.emit())
	var hint := Label.new()
	hint.text = "Friends on your network join you with the address shown in the pause menu."
	hint.add_theme_font_size_override("font_size", 16)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = 160
	row.add_child(hint)
	_pack_notices(v)
	return v


func _fill_maps() -> void:
	_map.clear()
	var maps := Game.list_maps()
	for i in maps.size():
		_map.add_item(maps[i].name)
		_map.set_item_metadata(i, maps[i].key)
		if maps[i].key == Game.map:
			_map.selected = i


## Map packs with scripts of their own wait for the player's OK (one button each).
func _pack_notices(v: Control) -> void:
	var waiting := MapPacks.waiting()
	if waiting.is_empty():
		return
	var note := Label.new()
	note.text = "These map packs run their own code on your computer. Only allow packs from people you trust:"
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	for info in waiting:
		var b := Button.new()
		b.text = "Allow %s" % info.name
		b.pressed.connect(func():
			if Game.allow_pack(info):
				b.text = "%s allowed" % info.name
				b.disabled = true
				_fill_maps()
			else:
				b.text = "%s could not be loaded" % info.name)
		v.add_child(b)


func _page_join(stack: Control) -> Control:
	var v := _page(stack)
	var grid := _grid(v)
	_address = LineEdit.new()
	_address.text = Game.join_address
	_address.placeholder_text = "IP address, or host:port"
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
	hint.text = "Over the internet: forward UDP port %d on the host's router, use Tailscale / ZeroTier, or a UDP tunnel such as playit.gg (paste the address it gives you, host:port)." % Game.DEFAULT_PORT
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
	_picker(grid, "character", "Yeet", CharacterModel.CHARACTER_NAMES, Game.look_character)
	_picker(grid, "hat", "Hat", hats, Game.look_hat + 1)
	_picker(grid, "face", "Head extra", CharacterModel.FACE_NAMES, Game.look_face)
	_picker(grid, "skin", "Skin", skins, Game.look_skin + 1)
	_picker(grid, "color", "Shirt", colors, Game.look_color + 1)
	_picker(grid, "faces", "Faces", ["Expressive", "Classic"], 0 if Game.expressive_faces else 1)
	var note := Label.new()
	note.text = "Noor wears her own gear; the shirt colour is her scarf. Teams wear team colours."
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
	var sargs := OS.get_cmdline_user_args()
	var si := sargs.find("--menu-scroll") # (screenshots: scroll the options down by N px)
	if si >= 0 and si + 1 < sargs.size():
		var px := int(sargs[si + 1])
		get_tree().create_timer(1.2).timeout.connect(func(): scroll.scroll_vertical = px)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	v.add_child(SettingsForm.build_settings_controls())
	var head := _label("Controls")
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	v.add_child(head)
	v.add_child(ControlsForm.new())
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
	Game.look_character = _pickers.character.index
	Game.look_hat = _pickers.hat.index - 1
	Game.look_face = _pickers.face.index
	Game.look_skin = _pickers.skin.index - 1
	Game.look_color = _pickers.color.index - 1
	Game.expressive_faces = _pickers.faces.index == 0
	_update_preview()


func _update_preview() -> void:
	var shirt: Color = Game.FFA_COLORS[maxi(Game.look_color, 0) % Game.FFA_COLORS.size()]
	var hat := Game.look_hat if Game.look_hat >= 0 else 0
	_preview.show_look(shirt, hat, Game.look_face, Game.look_skin, 1, 0, Game.look_character)


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
	Game.pickups = _pickups.selected
	Game.yeetball_rules = _rules.selected
	Game.match_minutes = Game.MATCH_LENGTHS[maxi(_minutes.selected, 0)]
	Game.ball_knockdown = _knock.selected == 1
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
