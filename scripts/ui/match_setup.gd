class_name MatchSetup
extends Control
## The host's match setup (the main menu's PLAY): the mode first, then only the maps that suit
## it (Game.mode_fits: CTF needs flag stands, the sports their goals, hoops or net, Puzzle a
## puzzle level; the rest any map), then that mode's options (bots, pickups; the sports'
## rules, length and knockdowns; MegaYeet's rules, the map's own or custom: the Heart's health,
## bites, waves, the boss, the breaks) and the world (spooky, water, sky). START MATCH stores
## it all (Game) and asks the menu to host. Mouse, keyboard or gamepad.

signal start_pressed
signal back_pressed

var _modes: ItemList
var _mode_about: Label
var _maps: ItemList
var _map_about: Label
var _grid: GridContainer
var _rows: Array = [] # [label, control, modes it shows for ([]: all)]
var _bots: SpinBox
var _pickups: OptionButton
var _rules: OptionButton
var _minutes: OptionButton
var _knock: OptionButton
var _spooky: OptionButton
var _water: OptionButton
var _sky: OptionButton
var _mega_custom: OptionButton
var _economy: OptionButton
var _mega := {} # rule -> SpinBox
var _compact := false

## MegaYeet's rules the host can set: [key, label, min, max, step].
const MEGA_FIELDS := [
	["health", "Heart's health", 100.0, 10000.0, 50.0],
	["bite", "A monster's bite", 0.0, 500.0, 5.0],
	["kill_refill", "A kill puts back", 0.0, 50.0, 0.5],
	["wave_bonus", "Holding a wave puts back", 0.0, 1000.0, 5.0],
	["wave_size", "Wave size (times)", 0.25, 4.0, 0.05],
	["max_monsters", "Most monsters at once", 20.0, 400.0, 10.0],
	["boss_every", "A boss every (waves, 0: none)", 0.0, 20.0, 1.0],
	["boss_health", "Boss's health", 200.0, 50000.0, 100.0],
	["boss_reward", "The boss pays back", 0.0, 5000.0, 10.0],
	["first_break", "Before the first wave (s)", 3.0, 120.0, 1.0],
	["break_time", "Breaks between waves (s)", 3.0, 300.0, 1.0],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_compact = get_viewport_rect().size.y < 880.0
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.03
	panel.anchor_top = 0.04
	panel.anchor_right = 0.97
	panel.anchor_bottom = 0.96
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10 if _compact else 14)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Match setup"
	title.add_theme_font_size_override("font_size", 30 if _compact else 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)

	# The mode.
	var c1 := _column(cols, "Mode", 290.0 if _compact else 330.0)
	_modes = ItemList.new()
	_modes.custom_minimum_size.y = 300 if _compact else 380
	for i in Game.MODE_NAMES.size():
		_modes.add_item(Game.MODE_NAMES[i])
	_modes.select(clampi(Game.mode, 0, Game.MODE_NAMES.size() - 1))
	_modes.item_selected.connect(_mode_changed)
	c1.add_child(_modes)
	_mode_about = _about(c1)

	# The map.
	var c2 := _column(cols, "Map", 0.0)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_maps = ItemList.new()
	_maps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_maps.item_selected.connect(func(_i: int): _show_map())
	c2.add_child(_maps)
	_map_about = _about(c2)

	# The options.
	var c3 := _column(cols, "Options", 450.0 if _compact else 520.0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	c3.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 6 if _compact else 10)
	scroll.add_child(_grid)
	_build_options()

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 18)
	v.add_child(bottom)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 52 if _compact else 60)
	back.pressed.connect(func(): back_pressed.emit())
	bottom.add_child(back)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap)
	var start := Button.new()
	start.text = "START MATCH"
	start.theme_type_variation = "YellowButton"
	start.custom_minimum_size = Vector2(320 if _compact else 380, 56 if _compact else 68)
	start.add_theme_font_size_override("font_size", 26 if _compact else 32)
	start.pressed.connect(func():
		store()
		start_pressed.emit())
	bottom.add_child(start)
	_mode_changed(_modes.get_selected_items()[0])
	_modes.grab_focus.call_deferred()


func _column(parent: Control, heading: String, width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	if width > 0.0:
		c.custom_minimum_size.x = width
	parent.add_child(c)
	var h := Label.new()
	h.text = heading
	h.add_theme_font_size_override("font_size", 24 if _compact else 28)
	h.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	c.add_child(h)
	return c


func _about(parent: Control) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.y = 70 if _compact else 90
	l.add_theme_font_size_override("font_size", 17 if _compact else 19)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	parent.add_child(l)
	return l


func _build_options() -> void:
	_bots = SpinBox.new()
	_bots.min_value = 0
	_bots.max_value = 11
	_bots.value = Game.bot_count
	_row("Bots", _bots, [])
	_pickups = _options(["First aid + power-ups", "First aid only", "None"], clampi(Game.pickups, 0, 2))
	_row("Pickups", _pickups, [])
	_rules = _options(["Classic Chaos", "TOTAL YEET"], clampi(Game.yeetball_rules, 0, 1))
	_rules.tooltip_text = "Classic Chaos: recognisable sport with gravity guns.\nTOTAL YEET: longer holds, a faster ball, multi-ball and barrels from the sky."
	_row("Sport rules", _rules, [Game.Mode.YEETBALL, Game.Mode.HOOPS, Game.Mode.VOLLEY])
	var lengths := []
	for m: int in Game.MATCH_LENGTHS:
		lengths.append("First to 5 goals" if m == 0 else "%d minutes" % m)
	_minutes = _options(lengths, maxi(Game.MATCH_LENGTHS.find(Game.match_minutes), 0))
	_row("Match length", _minutes, [Game.Mode.YEETBALL, Game.Mode.HOOPS, Game.Mode.VOLLEY])
	_knock = _options(["A harmless bonk", "Knocks them over"], 1 if Game.ball_knockdown else 0)
	_row("Ball hits players", _knock, [Game.Mode.YEETBALL, Game.Mode.HOOPS, Game.Mode.VOLLEY])
	# MegaYeet: the map's own rules (its FortressHeart's), or the host's.
	var r: Dictionary = Game.megayeet_rules
	_economy = _options(["Shared: the Fortress meter", "Personal Y$"], 1 if r.get("economy", "shared") == "personal" else 0)
	_economy.tooltip_text = "Shared: the shop spends the Fortress meter (the team's life), and kills fill it back.\nPersonal Y$: every Yeet earns their own Y$ (kills, style, combos, the boss, waves held)\nand shops with it; the meter is only the fortress's life (Y$ can heal it, dearly)."
	_row("Economy", _economy, [Game.Mode.MEGAYEET])
	_mega_custom = _options(["The map's own", "Custom"], 1 if r.get("custom", false) else 0)
	_mega_custom.item_selected.connect(func(_i: int): _mega_editable())
	_row("MegaYeet rules", _mega_custom, [Game.Mode.MEGAYEET])
	for f in MEGA_FIELDS:
		var sb := SpinBox.new()
		sb.min_value = f[2]
		sb.max_value = f[3]
		sb.step = f[4]
		sb.value = float(r.get(f[0], f[2]))
		_mega[f[0]] = sb
		_row(f[1], sb, [Game.Mode.MEGAYEET])
	_mega_editable()
	# The world, any mode.
	_spooky = _options(["Off", "Auto (Halloween season)", "Always"], Game.halloween)
	_row("Spooky mode", _spooky, [])
	_water = _options(["Classic", "Sculpted (new)"], 1 if Game.water_style == "sculpted" else 0)
	_row("Water style", _water, [])
	var skies := ["Map's own"]
	var pick := 0
	for i in MapEnvironment.PRESETS.size():
		skies.append(String(MapEnvironment.PRESETS[i]).capitalize())
		if MapEnvironment.PRESETS[i] == Game.sky_override:
			pick = i + 1
	_sky = _options(skies, pick)
	_row("Environment", _sky, [])


func _options(items: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = selected
	return o


func _row(text: String, control: Control, modes: Array) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	_grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = 38 if _compact else 44
	_grid.add_child(control)
	_rows.append([l, control, modes])


func _mega_editable() -> void:
	var on := _mega_custom.selected == 1
	for k in _mega:
		(_mega[k] as SpinBox).editable = on
		(_mega[k] as SpinBox).modulate.a = 1.0 if on else 0.45


func mode() -> int:
	var sel := _modes.get_selected_items()
	return sel[0] if not sel.is_empty() else 0


func _mode_changed(m: int) -> void:
	_mode_about.text = Game.MODE_ABOUT[m] if m < Game.MODE_ABOUT.size() else ""
	for r in _rows:
		var show: bool = (r[2] as Array).is_empty() or m in r[2]
		(r[0] as Control).visible = show
		(r[1] as Control).visible = show
	_fill_maps(m)


## The maps that suit this mode (MegaYeet: fortresses first), keeping the one picked if it's
## still there.
func _fill_maps(m: int) -> void:
	var keep := Game.map
	var sel := _maps.get_selected_items()
	if not sel.is_empty():
		keep = _maps.get_item_metadata(sel[0])
	_maps.clear()
	var list := Game.list_maps().filter(func(e): return Game.mode_fits(m, e))
	if m == Game.Mode.MEGAYEET:
		list.sort_custom(func(a, b): return a.get("features", {}).get("fortress", false) and not b.get("features", {}).get("fortress", false))
	var pick := 0
	for i in list.size():
		var e: Dictionary = list[i]
		var tag := "  ★" if m == Game.Mode.MEGAYEET and e.get("features", {}).get("fortress", false) else ""
		_maps.add_item(e.name + tag)
		_maps.set_item_metadata(i, e.key)
		_maps.set_item_tooltip(i, e.get("description", ""))
		if e.key == keep:
			pick = i
	if _maps.item_count > 0:
		_maps.select(pick)
		_maps.ensure_current_is_visible()
	_show_map()


func _show_map() -> void:
	var sel := _maps.get_selected_items()
	if sel.is_empty():
		_map_about.text = "No map suits this mode yet."
		return
	var e := Game.map_info(_maps.get_item_metadata(sel[0]))
	var good := []
	var f: Dictionary = e.get("features", {})
	for pair in [["ctf", "Capture the Flag"], ["yeetball", "Yeetball"], ["hoops", "YeetHoops"], ["volley", "YeetVolley"], ["puzzle", "Puzzle"], ["fortress", "MegaYeet (a fortress)"]]:
		if f.get(pair[0], false):
			good.append(pair[1])
	var text: String = e.get("description", "")
	if not good.is_empty():
		text += ("\n" if text != "" else "") + "Made for: " + ", ".join(good)
	_map_about.text = text


## Everything picked, into Game (and saved).
func store() -> void:
	Game.mode = mode()
	var sel := _maps.get_selected_items()
	if not sel.is_empty():
		Game.map = _maps.get_item_metadata(sel[0])
	Game.bot_count = int(_bots.value)
	Game.pickups = _pickups.selected
	Game.yeetball_rules = _rules.selected
	Game.match_minutes = Game.MATCH_LENGTHS[maxi(_minutes.selected, 0)]
	Game.ball_knockdown = _knock.selected == 1
	Game.halloween = _spooky.selected
	Game.water_style = "sculpted" if _water.selected == 1 else "classic"
	Game.sky_override = "" if _sky.selected <= 0 else MapEnvironment.PRESETS[_sky.selected - 1]
	Game.megayeet_rules.custom = _mega_custom.selected == 1
	Game.megayeet_rules.economy = "personal" if _economy.selected == 1 else "shared"
	for k in _mega:
		Game.megayeet_rules[k] = (_mega[k] as SpinBox).value
	Game.save_settings()
