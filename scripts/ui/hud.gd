class_name Hud
extends CanvasLayer
## In-game HUD: crosshair, health, speedometer, prop slots, scores, killfeed,
## announcements, scoreboard and the pause/settings menu.

signal leave_pressed

const KILL_VERBS := {
	"impact": ["{k} splattered {v} against the scenery", "{k} turned {v} into wall art", "{k} redecorated with {v}"],
	"prop": ["{k} yeeted a {o} at {v}", "{k} introduced {v} to a {o}", "{v} caught {k}'s {o} with their face"],
	"explosion": ["{k} exploded {v}", "{k} sent {v} to the moon", "{k} made {v} go boom"],
	"acid": ["{k} dunked {v} in acid", "{k} gave {v} an acid bath"],
	"lava": ["{k} fondued {v}", "{k} gave {v} a lava bath"],
	"drown": ["{k} sent {v} to sleep with the fishes", "{k} threw {v} overboard"],
	"void": ["{k} yeeted {v} out of the world", "{k} sent {v} into the void"],
	"player": ["{k} body-slammed {v}", "{k} bowled over {v}"],
	"dodgeball": ["{k} dodgeballed {v}"],
	"caught": ["{k} caught {v}'s ball"],
}

var world: Node
var _root: Control
var _crosshair: Control
var _health_label: Label
var _health_bar: HudPlate
var _score_plate: HudPlate
var _speed_plate: HudPlate
var _slot_plates: Array[PanelContainer] = []
var _speed_label: Label
var _slots_box: HBoxContainer
var _slot_labels: Array[Label] = []
var _score_label: Label
var _killfeed: VBoxContainer
var _messages: VBoxContainer
var _big_label: Label
var _yeet_label: Label
var _vignette: ColorRect
var _death_label: Label
var _scoreboard: PanelContainer
var _scoreboard_text: RichTextLabel
var _pause: PanelContainer
var _help: RichTextLabel
var _aim_state := 0 # 0 nothing, 1 grabbable, 2 holding
var _help_time := 14.0
var _paused := false
var _resume_button: Button
var _hold_hint: Label
var _pad_used := false
var _help_pad := false


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.8, 0.0, 0.05, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	_root.add_child(_crosshair)

	# Health (bottom left): a plate with a plus badge, the number and a segmented bar.
	var hp_plate := HudPlate.new()
	hp_plate.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_plate.position = Vector2(24, -98)
	hp_plate.size = Vector2(300, 74)
	_root.add_child(hp_plate)
	var badge := HudPlate.new()
	badge.fill = Color(0.92, 0.24, 0.3)
	badge.position = Vector2(10, 10)
	badge.size = Vector2(54, 54)
	badge.chamfer = 10.0
	hp_plate.add_child(badge)
	var plus := _label(40, Color.WHITE)
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.position = Vector2(0, -3)
	plus.size = Vector2(54, 54)
	badge.add_child(plus)
	_health_label = _label(30, Color.WHITE)
	_health_label.position = Vector2(76, 2)
	hp_plate.add_child(_health_label)
	_health_bar = HudPlate.new()
	_health_bar.position = Vector2(74, 40)
	_health_bar.size = Vector2(214, 24)
	_health_bar.fill = Color(0.08, 0.09, 0.13)
	_health_bar.chamfer = 6.0
	_health_bar.value = 1.0
	hp_plate.add_child(_health_bar)

	# Speedometer (bottom center): a small pill.
	_speed_plate = HudPlate.new()
	_speed_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_plate.position = Vector2(-80, -96)
	_speed_plate.size = Vector2(160, 40)
	_speed_plate.chamfer = 12.0
	_root.add_child(_speed_plate)
	_speed_label = _label(22, Color(1, 1, 1, 0.95))
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.size = Vector2(160, 38)
	_speed_plate.add_child(_speed_label)

	# Prop slots (bottom right).
	_slots_box = HBoxContainer.new()
	_slots_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_slots_box.position = Vector2(-300, -46)
	_slots_box.add_theme_constant_override("separation", 6)
	_root.add_child(_slots_box)
	for i in Prop.SPAWNABLE.size():
		var tile := PanelContainer.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel", _tile_style(false))
		_slots_box.add_child(tile)
		_slot_plates.append(tile)
		var l := _label(14, Color.WHITE)
		l.text = "%d %s" % [i + 1, Prop.DEFS[Prop.SPAWNABLE[i]].label]
		tile.add_child(l)
		_slot_labels.append(l)

	# Scores (top center).
	_score_plate = HudPlate.new()
	_score_plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_plate.position = Vector2(-200, 10)
	_score_plate.size = Vector2(400, 48)
	_score_plate.chamfer = 12.0
	_root.add_child(_score_plate)
	_score_label = _label(26, Color.WHITE)
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.position = Vector2(-300, 15)
	_score_label.custom_minimum_size = Vector2(600, 0)
	_root.add_child(_score_label)

	_killfeed = VBoxContainer.new()
	_killfeed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_killfeed.position = Vector2(-560, 64)
	_killfeed.custom_minimum_size = Vector2(540, 0)
	_killfeed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_killfeed)

	_messages = VBoxContainer.new()
	_messages.set_anchors_preset(Control.PRESET_CENTER)
	_messages.position = Vector2(-400, -230)
	_messages.custom_minimum_size = Vector2(800, 0)
	_root.add_child(_messages)

	_big_label = _label(64, Color(1, 0.85, 0.3))
	_big_label.set_anchors_preset(Control.PRESET_CENTER)
	_big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_label.position = Vector2(-600, -160)
	_big_label.custom_minimum_size = Vector2(1200, 0)
	_big_label.modulate.a = 0.0
	_root.add_child(_big_label)

	_yeet_label = _label(90, Color(1, 0.4, 0.7))
	_yeet_label.text = "YEET!"
	_yeet_label.set_anchors_preset(Control.PRESET_CENTER)
	_yeet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_yeet_label.position = Vector2(-300, 60)
	_yeet_label.custom_minimum_size = Vector2(600, 0)
	_yeet_label.pivot_offset = Vector2(300, 50)
	_yeet_label.modulate.a = 0.0
	_root.add_child(_yeet_label)

	_death_label = _label(34, Color(1, 0.5, 0.5))
	_death_label.set_anchors_preset(Control.PRESET_CENTER)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.position = Vector2(-500, 120)
	_death_label.custom_minimum_size = Vector2(1000, 0)
	_death_label.visible = false
	_root.add_child(_death_label)

	_help = RichTextLabel.new()
	_help.bbcode_enabled = true
	_help.fit_content = true
	_help.scroll_active = false
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_help.position = Vector2(24, 74)
	_help.size = Vector2(760, 0)
	_help.add_theme_font_override("normal_font", UiTheme.FONT)
	_help.add_theme_font_size_override("normal_font_size", 16)
	_help.add_theme_constant_override("outline_size", 5)
	_help.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_help.add_theme_stylebox_override("normal", _tile_style(false, 0.55))
	_help.text = _help_text(false)
	_root.add_child(_help)

	_hold_hint = _label(15, Color(1, 1, 1, 0.8))
	_hold_hint.set_anchors_preset(Control.PRESET_CENTER)
	_hold_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_hint.position = Vector2(-300, 46)
	_hold_hint.custom_minimum_size = Vector2(600, 0)
	_hold_hint.visible = false
	_root.add_child(_hold_hint)

	_build_scoreboard()
	_build_pause()


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = UiTheme.FONT
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(4, size / 6)
	ls.outline_color = Color(0.05, 0.03, 0.1, 0.9)
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(2, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A small dark tile (prop slots, killfeed, hints); highlighted = yellow border.
func _tile_style(highlighted: bool, alpha := 0.7) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.16, alpha)
	sb.set_corner_radius_all(7)
	sb.set_content_margin_all(5)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.border_color = Color(1.0, 0.78, 0.2) if highlighted else Color(0.05, 0.05, 0.08, alpha)
	sb.set_border_width_all(2)
	return sb


## The controls cheat sheet, with the player's own bindings (keyboard/mouse or gamepad).
func _help_text(pad: bool) -> String:
	var k := func(action: String) -> String:
		return "[color=#ffd23f]%s[/color]" % (Controls.pad_of(action) if pad else Controls.key_of(action))
	var move := "%s %s %s %s" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")]
	if pad:
		move = "[color=#ffd23f]Left stick[/color]"
	var lines := [
		"%s move  ·  %s jump (hold to bunny hop)  ·  %s run  ·  %s crouch & slide" % [move, k.call("jump"), k.call("run") if not pad else k.call("run_toggle"), k.call("crouch")],
		"Run along walls to wall-run, jump off them to wall-jump",
		"%s hold: grab / pull / catch  ·  %s throw (hold to charge) or punt (punt a wall to gravity-jump)" % [k.call("gun_grab"), k.call("gun_throw")],
		"%s freeze held prop  ·  %s spawn prop  ·  %s camera  ·  %s scores  ·  %s respawn  ·  %s menu" % [k.call("freeze_prop"), k.call("spawn_prop"), k.call("toggle_view"), k.call("scoreboard"), k.call("suicide"), k.call("pause")],
	]
	return "\n".join(lines)


func _panel_style(alpha := 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.18, alpha)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	sb.border_color = Color(1, 0.55, 0.85, 0.8)
	sb.set_border_width_all(2)
	return sb


func _build_scoreboard() -> void:
	_scoreboard = PanelContainer.new()
	_scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	_scoreboard.position = Vector2(-380, -260)
	_scoreboard.custom_minimum_size = Vector2(760, 520)
	_scoreboard.add_theme_stylebox_override("panel", _panel_style())
	_scoreboard.visible = false
	_root.add_child(_scoreboard)
	_scoreboard_text = RichTextLabel.new()
	_scoreboard_text.bbcode_enabled = true
	_scoreboard_text.fit_content = true
	_scoreboard_text.scroll_active = false
	_scoreboard_text.add_theme_font_size_override("normal_font_size", 20)
	_scoreboard_text.add_theme_font_size_override("bold_font_size", 22)
	_scoreboard.add_child(_scoreboard_text)


func _build_pause() -> void:
	_pause = PanelContainer.new()
	_pause.theme = UiTheme.get_theme()
	_pause.anchor_left = 0.18
	_pause.anchor_right = 0.82
	_pause.anchor_top = 0.05
	_pause.anchor_bottom = 0.95
	_pause.visible = false
	_root.add_child(_pause)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_pause.add_child(v)
	var title := _label(36, Color(1, 0.8, 0.3))
	title.text = "PAUSED (the chaos is not)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if multiplayer.is_server() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var host_info := _label(18, Color(0.7, 1.0, 0.75))
		host_info.text = "Hosting · friends join: %s  (port %d)" % [", ".join(_lan_addresses()), Game.port]
		host_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		host_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(host_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var resume := Button.new()
	resume.text = "Resume"
	resume.theme_type_variation = "YellowButton"
	resume.custom_minimum_size = Vector2(220, 56)
	resume.pressed.connect(func(): set_paused(false))
	_resume_button = resume
	row.add_child(resume)
	var leave := Button.new()
	leave.text = "Leave match"
	leave.theme_type_variation = "RedButton"
	leave.custom_minimum_size = Vector2(220, 56)
	leave.pressed.connect(func(): leave_pressed.emit())
	row.add_child(leave)
	# Settings scroll inside the panel (the graphics details make the list long).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	var form := SettingsForm.build_settings_controls()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(form)
	var ch := _label(24, Color(1, 0.8, 0.3))
	ch.text = "Controls"
	col.add_child(ch)
	col.add_child(ControlsForm.new())


## Private network addresses of this machine (what friends on the same network type in).
func _lan_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("100.") or (ip.begins_with("172.") and ip.split(".")[1].to_int() >= 16 and ip.split(".")[1].to_int() <= 31):
			out.append(ip)
	if out.is_empty():
		out.append("127.0.0.1")
	return out


func set_paused(p: bool) -> void:
	_paused = p
	if not p:
		_help.text = _help_text(_pad_used) # bindings may have changed in the pause menu
	_pause.visible = p
	if p and _resume_button:
		_resume_button.grab_focus.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
	if not p:
		Game.save_settings()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_pad_used = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_pad_used = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (_paused and event.is_action_pressed("ui_cancel") and event is InputEventJoypadButton):
		set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var pl: Player = world.local_player if world else null
	_scoreboard.visible = Input.is_action_pressed("scoreboard") and not _paused
	if _scoreboard.visible:
		_refresh_scoreboard()
	_help_time -= delta
	_help.modulate.a = clampf(_help_time, 0.0, 1.0)
	if _help_pad != _pad_used:
		_help_pad = _pad_used
		_help.text = _help_text(_pad_used)
	_vignette.color.a = maxf(_vignette.color.a - delta * 0.8, 0.0)
	if pl == null:
		return
	var hp := maxf(pl.hp, 0.0)
	_health_label.text = "%d" % ceilf(hp)
	if absf(_health_bar.value - hp / 100.0) > 0.001:
		_health_bar.value = hp / 100.0
		_health_bar.bar_color = Color(1.0, 0.3, 0.3).lerp(Color(0.4, 1.0, 0.5), hp / 100.0)
		_health_bar.queue_redraw()
	var speed := pl.horizontal_speed()
	_speed_label.text = "%.1f m/s" % speed
	_speed_label.label_settings.font_color = Color.WHITE.lerp(Color(1.0, 0.45, 0.85), clampf((speed - 9.5) / 15.0, 0.0, 1.0))
	var sandbox: bool = world.mode == Game.Mode.SANDBOX
	_slots_box.visible = sandbox
	for i in _slot_labels.size():
		var sel: bool = i == pl.gun.selected_slot
		_slot_labels[i].label_settings.font_color = Color(1, 0.85, 0.3) if sel else Color(1, 1, 1, 0.7)
		if _slot_plates[i].get_meta("sel", false) != sel:
			_slot_plates[i].set_meta("sel", sel)
			_slot_plates[i].add_theme_stylebox_override("panel", _tile_style(sel))
	_death_label.visible = not pl.is_alive()
	var holding := pl.gun.vis_kind != GravityGun.Kind.NONE and pl.is_alive()
	_hold_hint.visible = holding
	if holding:
		if _pad_used:
			_hold_hint.text = "%s hold: charge throw  ·  %s / %s: push / pull  ·  %s + stick: rotate  ·  %s: freeze" % [Controls.pad_of("gun_throw"), Controls.pad_of("hold_farther"), Controls.pad_of("hold_closer"), Controls.pad_of("rotate_held"), Controls.pad_of("freeze_prop")]
		else:
			_hold_hint.text = "%s hold: charge throw  ·  Wheel: push / pull  ·  %s + mouse: rotate  ·  %s: freeze" % [Controls.key_of("gun_throw"), Controls.key_of("rotate_held"), Controls.key_of("freeze_prop")]
	_update_aim_state(pl)
	_crosshair.queue_redraw()


func _update_aim_state(pl: Player) -> void:
	if pl.gun.vis_kind != GravityGun.Kind.NONE:
		_aim_state = 2
		return
	_aim_state = 0
	if pl.camera == null:
		return
	var space := pl.get_world_3d().direct_space_state
	var from := pl.eye_position()
	var q := PhysicsRayQueryParameters3D.create(from, from + pl.aim_direction() * GravityGun.PULL_RANGE, Game.L_WORLD | Game.L_PROPS | Game.L_PLAYERS, [pl.get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and (hit.collider is Prop or hit.collider is Player):
		_aim_state = 1


func _draw_crosshair() -> void:
	var c := Color(1, 1, 1, 0.9)
	match _aim_state:
		1:
			c = Color(0.4, 1.0, 1.0)
		2:
			c = Color(1.0, 0.6, 0.2)
	var r := 10.0 if _aim_state == 0 else 14.0
	var pl: Player = world.local_player if world else null
	var charge := pl.gun.visual_charge() if pl and pl.gun else 0.0
	if charge > 0.0:
		# Charge ring fills clockwise from the top; white-hot at full.
		var col := Color(1.0, 0.6, 0.2).lerp(Color(1.0, 1.0, 0.9), charge)
		_crosshair.draw_arc(Vector2.ZERO, 24.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(0, 0, 0, 0.5), 6.0)
		_crosshair.draw_arc(Vector2.ZERO, 24.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, col, 3.0)
	_crosshair.draw_circle(Vector2.ZERO, 2.5, c)
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25
		var d := Vector2.from_angle(a)
		_crosshair.draw_line(d * r, d * (r + 7.0), Color(0, 0, 0, 0.6), 4.0)
		_crosshair.draw_line(d * r, d * (r + 7.0), c, 2.0)


func on_mode_changed() -> void:
	on_players_changed()
	show_message("Mode: %s" % world.mode_name(), Color(1, 0.85, 0.3), true)


func on_players_changed() -> void:
	if world == null or _score_label == null:
		return
	if world.mode == Game.Mode.PUMPKIN:
		var pl: Player = world.local_player
		var leader: Player = null
		for p: Player in world.players.values():
			if leader == null or p.score > leader.score:
				leader = p
		var lead := "   ·   Leader: %s (%d)" % [leader.display_name, leader.score] if leader and leader.score > 0 else ""
		_score_label.text = "%s     Candy: %d / %d%s" % [world.mode_name(), pl.score if pl else 0, ModePumpkin.WIN_CANDY, lead]
	elif world.is_team_mode():
		_score_label.text = "%s     RED %d  —  %d BLUE" % [world.mode_name(), world.team_scores.get(1, 0), world.team_scores.get(2, 0)]
	else:
		var pl: Player = world.local_player
		_score_label.text = "%s     Frags: %d" % [world.mode_name(), pl.frags if pl else 0]
	_fit_score_plate.call_deferred()


func _fit_score_plate() -> void:
	if _score_plate == null:
		return
	var w := _score_label.get_minimum_size().x + 48.0
	_score_plate.offset_left = -w * 0.5 # offsets from the top-centre anchor
	_score_plate.offset_right = w * 0.5
	_score_plate.offset_top = 10
	_score_plate.offset_bottom = 58
	_score_plate.queue_redraw()


func _refresh_scoreboard() -> void:
	var rows: Array = world.players.values()
	rows.sort_custom(func(a, b): return a.frags + a.score * 5 > b.frags + b.score * 5)
	var t := "[center][b]%s[/b][/center]\n\n" % world.mode_name().to_upper()
	t += "[table=5][cell][b]Player   [/b][/cell][cell][b]Team   [/b][/cell][cell][b]Frags   [/b][/cell][cell][b]Deaths   [/b][/cell][cell][b]Score[/b][/cell]"
	for p: Player in rows:
		var col: Color = p.color
		t += "[cell][color=#%s]%s%s[/color]   [/cell][cell]%s[/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell]" % [col.to_html(false), p.display_name, " (bot)" if p.is_bot else "", Game.TEAM_NAMES[p.team], p.frags, p.deaths, p.score]
	t += "[/table]"
	_scoreboard_text.text = t


func add_kill(victim: Player, killer: Player, cause: String) -> void:
	var text := ""
	var base := cause.split(":")[0]
	var obj := cause.split(":")[1].replace("_", " ") if cause.contains(":") else "thing"
	obj = {"shard": "chunk of wall", "boom barrel": "boom barrel", "crate big": "big crate"}.get(obj, obj)
	var verbs: Array = KILL_VERBS.get(base, ["{k} yeeted {v}"])
	var verb: String = verbs[randi() % verbs.size()]
	if cause == "suicide":
		text = "%s took the easy way out" % victim.display_name
	elif killer and killer != victim:
		text = verb.format({"k": killer.display_name, "v": victim.display_name, "o": obj})
	else:
		match base:
			"impact":
				text = "%s forgot how doors work" % victim.display_name
			"acid":
				text = "%s went for a swim" % victim.display_name
			"lava":
				text = "%s tested the lava" % victim.display_name
			"drown":
				text = "%s sleeps with the fishes" % victim.display_name
			"void":
				text = "%s fell out of the world" % victim.display_name
			"explosion":
				text = "%s hugged a barrel" % victim.display_name
			_:
				text = "%s got yeeted" % victim.display_name
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(540, 0)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _tile_style(killer == world.local_player or victim == world.local_player, 0.6))
	row.add_child(pill)
	var l := _label(17, Color.WHITE)
	l.text = text
	pill.add_child(l)
	_killfeed.add_child(row)
	_fade_out(row, 6.0)
	# queue_free() only takes effect at frame end, so detach first or this never ends.
	while _killfeed.get_child_count() > 6:
		var old := _killfeed.get_child(0)
		_killfeed.remove_child(old)
		old.queue_free()
	if victim == world.local_player:
		_death_label.text = ("Yeeted by %s!" % killer.display_name if killer and killer != victim else "You got yeeted!") + "\nRespawning..."
	elif killer == world.local_player:
		show_message("You yeeted %s!" % victim.display_name, Color(1, 0.6, 0.9), false)
	on_players_changed()


func show_message(text: String, color: Color, big: bool) -> void:
	if big:
		_big_label.text = text
		_big_label.label_settings.font_color = color
		_big_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(_big_label, "modulate:a", 0.0, 0.8)
		return
	var l := _label(24, color)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(800, 0)
	_messages.add_child(l)
	_fade_out(l, 3.5)
	while _messages.get_child_count() > 4:
		var old := _messages.get_child(0)
		_messages.remove_child(old)
		old.queue_free()


func _fade_out(n: CanvasItem, after: float) -> void:
	var tw := n.create_tween()
	tw.tween_interval(after)
	tw.tween_property(n, "modulate:a", 0.0, 0.6)
	tw.tween_callback(n.queue_free)


func flash_damage(amount: float) -> void:
	_vignette.color.a = clampf(_vignette.color.a + amount / 120.0, 0.0, 0.55)


func yeet_text() -> void:
	_yeet_label.modulate.a = 1.0
	_yeet_label.scale = Vector2(0.4, 0.4)
	_yeet_label.rotation = randf_range(-0.25, 0.25)
	var tw := create_tween()
	tw.tween_property(_yeet_label, "scale", Vector2.ONE * 1.2, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(_yeet_label, "modulate:a", 0.0, 0.4)
