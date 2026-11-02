class_name ShopWindow
extends Control
## MegaYeet's shop (the shop key, between waves): what the break can buy, in tabs (traps,
## power-ups, team upgrades, repairs, and the Heart in a Personal Y$ match), each a card with
## a turning 3D thumbnail, its price and what it does. The wares and whether you can have them
## come from ModeMegaYeet.shop_items (the server checks again: World.shop_buy). Mouse or pad:
## the shoulder buttons switch tabs, B (or the shop key, or Esc) closes.

signal closed

const CARD := Vector2(200, 300)
const TAB_COLORS := ["RedButton", "BlueButton", "YellowButton", "GreyButton", "GreenButton"]

var world: Node
var _tab := 0
var _tabs: HBoxContainer
var _tab_buttons := {} # tab -> Button
var _grid: GridContainer
var _wallet: Label
var _clock: Label
var _hint: Label
var _cards := {} # id -> {button, price, why, thumb}
var _shown := "" # the ids on show (rebuilt when they change)
var _refresh_t := 0.0
var _pad := false


func _init(p_world: Node) -> void:
	world = p_world


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.15 # (the Fortress bar and the Y$ stay in sight above it)
	panel.anchor_bottom = 0.95
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	var title := _text(34, Color(1.0, 0.8, 0.25))
	title.text = "FORTRESS SHOP"
	head.add_child(title)
	_clock = _text(22, Color(0.7, 0.9, 1.0))
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_clock)
	_wallet = _text(30, Color(1.0, 0.85, 0.3))
	_wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_wallet)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	v.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	_hint = _text(17, Color(0.75, 0.75, 0.85))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	resized.connect(_fit_columns)
	_refresh()


func _fit_columns() -> void:
	if _grid:
		_grid.columns = maxi(int((size.x * 0.9 - 80.0) / (CARD.x + 12.0)), 2)


func _process(delta: float) -> void:
	if not visible:
		return
	if int(world.mode_state.get("phase", -1)) != ModeMegaYeet.Phase.BREAK:
		close() # (the wave's here)
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_pad = false
	if event.is_action_pressed("shop") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		var tabs := _tab_list()
		var i := tabs.find(_tab)
		_set_tab(tabs[posmod(i + (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1), tabs.size())])
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_shown = ""
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui("click")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## The tabs this match has (the Heart only with personal Y$).
func _tab_list() -> Array:
	var out := [0, 1, 2, 3]
	if ModeMegaYeet.is_personal(world):
		out.append(4)
	return out


func _set_tab(t: int) -> void:
	_tab = t
	_shown = ""
	_refresh()
	Sfx.play_ui("click", -6.0)


func _refresh() -> void:
	_refresh_t = 0.25
	var pl: Player = world.local_player
	if pl == null or _grid == null:
		return
	var s: Dictionary = world.mode_state
	var mine := ModeMegaYeet.is_personal(world)
	var have := ModeMegaYeet.wallet(world, pl)
	_wallet.text = ("Y$ %d" % have) if mine else ("Meter to spend: %d" % maxi(have, 0))
	var left := maxf(float(s.get("next", 0.0)) - world.net_time(), 0.0)
	_clock.text = "Wave %d in %d s" % [int(s.get("wave", 0)) + 1, ceili(left)]
	var close_key := Controls.pad_of("shop") if _pad else Controls.key_of("shop")
	_hint.text = ("%s / B: close   ·   LB / RB: tabs   ·   A: buy" % close_key) if _pad else ("%s or Esc: close   ·   click a card to buy" % close_key)
	if not mine:
		_hint.text += "   ·   paid from the Fortress meter (a tenth is kept back)"
	# The tabs.
	var tabs := _tab_list()
	if not _tab in tabs:
		_tab = 0
	if _tab_buttons.size() != tabs.size():
		for c in _tabs.get_children():
			c.queue_free()
		_tab_buttons.clear()
		for t: int in tabs:
			var b := Button.new()
			b.text = ModeMegaYeet.TABS[t]
			b.custom_minimum_size = Vector2(150, 48)
			b.focus_mode = Control.FOCUS_NONE # (the pad uses the shoulders)
			b.pressed.connect(_set_tab.bind(t))
			_tabs.add_child(b)
			_tab_buttons[t] = b
	for t: int in _tab_buttons:
		(_tab_buttons[t] as Button).theme_type_variation = TAB_COLORS[t] if t == _tab else "GreyButton"
	# The cards.
	var items: Array = ModeMegaYeet.shop_items(world, pl).filter(func(it): return it.tab == _tab)
	var ids := ",".join(items.map(func(it): return it.id))
	if ids != _shown:
		_shown = ids
		_build_cards(items)
	for it: Dictionary in items:
		var c: Dictionary = _cards[it.id]
		var b: Button = c.button
		b.disabled = not it.ok
		c.price.text = "OWNED" if it.owned else (("%d Y$" % it.cost) if mine else ("%d" % it.cost))
		c.price.label_settings.font_color = Color(0.5, 1.0, 0.55) if it.owned else (Color(1.0, 0.85, 0.3) if it.ok else Color(0.75, 0.6, 0.45))
		c.about.text = it.about
		c.why.text = "" if it.owned else it.why
		b.modulate = Color.WHITE if it.ok or it.owned else Color(1, 1, 1, 0.6)
	_fit_columns()


func _build_cards(items: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var first: Button = null
	for it: Dictionary in items:
		var b := Button.new()
		b.custom_minimum_size = CARD
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_buy.bind(String(it.id)))
		_grid.add_child(b)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -10
		v.offset_top = 8
		v.offset_bottom = -8
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var thumb := Thumb.new(build_look(String(it.look), world))
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(thumb)
		var title := _text(21, Color.WHITE)
		title.text = it.name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
		var price := _text(20, Color(1.0, 0.85, 0.3))
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(price)
		var about := _text(14, Color(0.85, 0.85, 0.92))
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.custom_minimum_size.x = CARD.x - 20.0
		v.add_child(about)
		var why := _text(14, Color(1.0, 0.55, 0.45))
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(why)
		for n in [thumb, title, price, about, why]:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.mouse_entered.connect(thumb.spin.bind(true))
		b.mouse_exited.connect(thumb.spin.bind(false))
		b.focus_entered.connect(thumb.spin.bind(true))
		b.focus_exited.connect(thumb.spin.bind(false))
		_cards[it.id] = {"button": b, "price": price, "about": about, "why": why}
		if first == null:
			first = b
	if first and _pad:
		first.grab_focus.call_deferred()


func _buy(id: String) -> void:
	world.shop_buy(id)
	Sfx.play_ui("click")
	if id.begins_with("trap:"):
		close() # (it's put down where you aim: TrapPlacer)
		return
	_refresh_t = 0.1 # (the server's answer comes with the next mode state)


func _text(px: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = UiTheme.FONT
	ls.font_size = px
	ls.font_color = color
	ls.outline_size = maxi(4, px / 5)
	ls.outline_color = Color(0.05, 0.03, 0.1, 0.9)
	l.label_settings = ls
	return l


# --- Thumbnails ------------------------------------------------------------------------

## The model a card shows: the trap (as the map's spot has it: your own model too), the
## pickup, or a little symbol (the upgrades, repairs).
static func build_look(look: String, w: Node = null) -> Node3D:
	var parts := look.split(":")
	match parts[0]:
		"spot":
			var i := int(parts[1])
			var src: TrapSpot = w.arena.puzzle[i] if w and i >= 0 and i < w.arena.puzzle.size() else null
			if src:
				var t := TrapSpot.new()
				t.kind = src.kind
				t.model = src.model
				t.size = Vector3(minf(src.size.x, 3.0), src.size.y, minf(src.size.z, 3.0))
				t.active = true
				return t
		"trap":
			var t := TrapSpot.new()
			t.kind = parts[1]
			t.size = Vector3(2.0, 1.0, 2.0)
			t.active = true
			return t
		"power":
			return Pickups.build_model(parts[1])
		"heal":
			var root := Node3D.new()
			var h := FortressHeart.new()
			h.scale = Vector3.ONE * 0.5
			root.add_child(h)
			var green := Mats.plastic(Color(0.3, 1.0, 0.45), 0.4, 1.5)
			root.add_child(PuzzleNode.box_mesh(Vector3(0.7, 0.22, 0.22), green, Vector3(0.95, 1.6, 0)))
			root.add_child(PuzzleNode.box_mesh(Vector3(0.22, 0.7, 0.22), green, Vector3(0.95, 1.6, 0)))
			return root
		"fix":
			return _wall_look(5 if parts[1] == "all" else 3, 3 if parts[1] == "all" else 2)
		"up":
			match int(parts[1]):
				0:
					return _arrow_look()
				1:
					return _shield_look()
				_:
					return _hourglass_look()
	return Node3D.new()


## Bricks and a hammer: a repair.
static func _wall_look(cols: int, rows: int) -> Node3D:
	var root := Node3D.new()
	var brick := Mats.plastic(Color(0.72, 0.4, 0.3), 0.85)
	var brick2 := Mats.plastic(Color(0.62, 0.34, 0.26), 0.85)
	for r in rows:
		for c in cols - (r % 2):
			var x := (c - (cols - 1) * 0.5 + (0.5 if r % 2 == 1 else 0.0)) * 0.62
			root.add_child(PuzzleNode.box_mesh(Vector3(0.58, 0.3, 0.32), brick if (r + c) % 2 == 0 else brick2, Vector3(x, 0.16 + r * 0.33, 0)))
	var hammer := Node3D.new()
	hammer.position = Vector3(0.35, rows * 0.33 + 0.25, 0.3)
	hammer.rotation_degrees = Vector3(0, 20, -35)
	root.add_child(hammer)
	var wood := Mats.plastic(Color(0.6, 0.42, 0.25), 0.7)
	var steel := Mats.plastic(Color(0.65, 0.67, 0.72), 0.3)
	hammer.add_child(PuzzleNode.box_mesh(Vector3(0.08, 0.8, 0.08), wood, Vector3(0, 0, 0)))
	hammer.add_child(PuzzleNode.box_mesh(Vector3(0.36, 0.16, 0.16), steel, Vector3(0.06, 0.42, 0)))
	return root


## Mighty pushes: a big orange arrow off a ball.
static func _arrow_look() -> Node3D:
	var root := Node3D.new()
	var orange := Mats.plastic(Color(1.0, 0.55, 0.12), 0.4, 0.6)
	var arrow := Node3D.new()
	arrow.rotation_degrees = Vector3(0, 0, -60)
	root.add_child(arrow)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.14
	cm.height = 1.0
	shaft.mesh = cm
	shaft.material_override = orange
	arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.0
	hm.bottom_radius = 0.34
	hm.height = 0.5
	head.mesh = hm
	head.position.y = 0.72
	head.material_override = orange
	arrow.add_child(head)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	ball.mesh = sm
	ball.position = Vector3(-0.62, -0.36, 0)
	ball.material_override = Mats.plastic(Color(0.3, 0.6, 1.0), 0.4)
	root.add_child(ball)
	return root


## Thick skin: a round shield.
static func _shield_look() -> Node3D:
	var root := Node3D.new()
	root.rotation_degrees = Vector3(90, 0, 0)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.75
	cm.height = 0.12
	disc.mesh = cm
	disc.material_override = Mats.plastic(Color(0.3, 0.45, 0.85), 0.5)
	root.add_child(disc)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.82
	rim.mesh = tm
	rim.material_override = Mats.plastic(Color(0.75, 0.77, 0.82), 0.3)
	root.add_child(rim)
	var boss := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.2
	sm.is_hemisphere = true
	boss.mesh = sm
	boss.position.y = 0.06
	boss.material_override = Mats.plastic(Color(1.0, 0.8, 0.25), 0.3, 0.4)
	root.add_child(boss)
	return root


## Quick return: an hourglass.
static func _hourglass_look() -> Node3D:
	var root := Node3D.new()
	var wood := Mats.plastic(Color(0.55, 0.36, 0.2), 0.7)
	var sand := Mats.plastic(Color(1.0, 0.82, 0.45), 0.6, 0.3)
	for y in [0.0, 1.3]:
		var plate := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.5
		pm.bottom_radius = 0.5
		pm.height = 0.1
		plate.mesh = pm
		plate.position.y = y
		plate.material_override = wood
		root.add_child(plate)
	for i in 3:
		var a := TAU * i / 3.0
		root.add_child(PuzzleNode.box_mesh(Vector3(0.06, 1.3, 0.06), wood, Vector3(cos(a) * 0.42, 0.65, sin(a) * 0.42)))
	for up in [true, false]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.34 if up else 0.03
		cm.bottom_radius = 0.03 if up else 0.34
		cm.height = 0.58
		cone.mesh = cm
		cone.position.y = 0.96 if up else 0.34
		cone.material_override = sand
		root.add_child(cone)
	return root


## A card's picture: the model in its own little world, drawn once (and turning while the
## card's under the mouse or focused).
class Thumb extends SubViewportContainer:
	var vp: SubViewport
	var pivot: Node3D
	var model: Node3D
	var _spin := false

	func _init(m: Node3D) -> void:
		model = m
		custom_minimum_size = Vector2(176, 150)
		stretch = true
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.75, 0.75, 0.85)
		env.environment.ambient_light_energy = 0.7
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -35, 0)
		sun.light_energy = 1.3
		vp.add_child(sun)
		pivot = Node3D.new()
		vp.add_child(pivot)
		pivot.add_child(model)
		pivot.rotation_degrees.y = -25.0

	func _ready() -> void:
		_tidy(model)
		# Framed on what the model turned out to be (its meshes' box).
		var boxes: Array[AABB] = []
		_bounds(model, boxes)
		var box := AABB()
		for i in boxes.size():
			box = boxes[i] if i == 0 else box.merge(boxes[i])
		var r := maxf(box.size.length() * 0.5, 0.2)
		model.position -= box.get_center()
		var cam := Camera3D.new()
		cam.fov = 40.0
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0, 0.55, 1.0).normalized() * r / tan(deg_to_rad(20.0)) * 1.05, Vector3.ZERO)

	func spin(on: bool) -> void:
		_spin = on
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_ONCE

	func _process(delta: float) -> void:
		if _spin:
			pivot.rotation.y += delta * 1.4

	## No lights, flames or glowing shells in a picture: they wash it out, and frame it too wide.
	static func _tidy(n: Node) -> void:
		for c in n.get_children(true):
			if c is Light3D or c is CPUParticles3D or c is GPUParticles3D:
				c.visible = false
			elif c is MeshInstance3D and c.material_override is BaseMaterial3D and (c.material_override as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				c.visible = false
			_tidy(c)

	static func _bounds(n: Node, out: Array[AABB]) -> void:
		if n is Node3D and not (n as Node3D).visible:
			return
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			var vi := n as VisualInstance3D
			out.append(vi.global_transform * vi.get_aabb())
		for c in n.get_children(true):
			_bounds(c, out)
