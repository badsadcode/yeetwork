class_name UiTheme
extends RefCounted
## The menus' chunky toy look: Lilita One font, beveled colour buttons and a framed slate
## panel (art made by tools/make_ui_art.py). Button colours are theme type variations:
## set Button.theme_type_variation to "YellowButton", "BlueButton", "RedButton",
## "GreenButton" or "GreyButton" (the default look).

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const OUTLINE := Color(0.09, 0.1, 0.16)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 20

	_button_type(t, "Button", "grey")
	for c in ["yellow", "blue", "red", "green", "grey"]:
		var type: String = c.capitalize() + "Button"
		t.set_type_variation(type, "Button")
		_button_type(t, type, c)
	_button_type(t, "OptionButton", "grey")
	# Check boxes stay plain (no plate), just the font.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", Color.WHITE)
	t.set_color("font_hover_color", "CheckBox", Color(1.0, 0.85, 0.4))
	t.set_constant("outline_size", "CheckBox", 5)
	t.set_constant("arrow_margin", "OptionButton", 12)

	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.1, 0.11, 0.16)
	field.border_color = Color(0.36, 0.4, 0.5)
	field.set_border_width_all(2)
	field.border_width_top = 3
	field.set_corner_radius_all(6)
	field.set_content_margin_all(8)
	field.content_margin_left = 12
	t.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate()
	field_focus.border_color = Color(1.0, 0.78, 0.2)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_color("caret_color", "LineEdit", Color(1.0, 0.78, 0.2))

	var panel := StyleBoxTexture.new()
	panel.texture = preload("res://assets/ui/panel.png")
	panel.set_texture_margin_all(44)
	panel.set_content_margin_all(34)
	panel.content_margin_top = 40
	t.set_stylebox("panel", "PanelContainer", panel)

	var popup := StyleBoxFlat.new()
	popup.bg_color = Color(0.13, 0.14, 0.2)
	popup.border_color = Color(1.0, 0.78, 0.2)
	popup.set_border_width_all(2)
	popup.set_corner_radius_all(6)
	popup.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", popup)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.48, 0.95)
	hover.set_corner_radius_all(4)
	t.set_stylebox("hover", "PopupMenu", hover)

	for type in ["Label", "CheckBox", "Button", "OptionButton"]:
		t.set_color("font_outline_color", type, OUTLINE)
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_color", "Label", Color.WHITE)

	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1.0, 0.78, 0.2)
	grab.set_corner_radius_all(4)
	grab.content_margin_top = 4
	grab.content_margin_bottom = 4
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.11, 0.16)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t


static func _button_type(t: Theme, type: String, color: String) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = load("res://assets/ui/button_%s_%s.png" % [color, "hover" if state == "hover" else state])
		sb.texture_margin_left = 24
		sb.texture_margin_right = 24
		sb.texture_margin_top = 18
		sb.texture_margin_bottom = 22
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10 if state == "pressed" else 6
		sb.content_margin_bottom = 10 if state == "pressed" else 14
		t.set_stylebox(state, type, sb)
	t.set_stylebox("hover_pressed", type, t.get_stylebox("pressed", type))
	var dis := (t.get_stylebox("normal", type) as StyleBoxTexture).duplicate() as StyleBoxTexture
	dis.modulate_color = Color(0.6, 0.6, 0.6, 0.7)
	t.set_stylebox("disabled", type, dis)
	# Gamepad / keyboard focus: a bright frame around the plate.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.95)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(10)
	focus.set_expand_margin_all(3)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, Color.WHITE)
	t.set_color("font_hover_color", type, Color.WHITE)
	t.set_color("font_pressed_color", type, Color(0.92, 0.92, 0.92))
	t.set_color("font_focus_color", type, Color.WHITE)
	t.set_constant("outline_size", type, 7)
