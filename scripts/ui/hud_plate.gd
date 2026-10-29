class_name HudPlate
extends Control
## HUD backgrounds in the menu's chunky toy style (see tools/make_ui_art.py): a chamfered
## plate with a dark outline, a two-tone body and a light rim along the top. Drawn in code
## so it stays crisp at any size. As a bar (value 0..1) it draws a segmented fill on the
## plate, like the health bar.

var fill := Color(0.16, 0.18, 0.24, 0.9)
var outline := Color(0.06, 0.07, 0.11, 0.95)
var chamfer := 8.0
## Bar mode: fraction filled (-1 = a plain plate), the fill colour and how many segments.
var value := -1.0
var bar_color := Color(0.4, 1.0, 0.5)
var segments := 10


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func poly(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c),
		r.end - Vector2(0, c), Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y),
		Vector2(r.position.x, r.end.y - c), r.position + Vector2(0, c)])


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := minf(chamfer, size.y * 0.45)
	draw_colored_polygon(poly(Rect2(r.position + Vector2(0, 3), r.size), c), Color(0, 0, 0, 0.3)) # drop shadow
	draw_colored_polygon(poly(r, c), outline)
	var inner := r.grow(-3.0)
	var ic := maxf(c - 2.0, 1.0)
	draw_colored_polygon(poly(inner, ic), fill.darkened(0.25))
	var top := Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.55))
	draw_colored_polygon(poly(top, minf(ic, top.size.y * 0.45)), fill)
	if value >= 0.0:
		var track := inner.grow(-3.0)
		var w := track.size.x * clampf(value, 0.0, 1.0)
		if w > 1.0:
			var f := Rect2(track.position, Vector2(w, track.size.y))
			var fc := minf(maxf(ic - 2.0, 1.0), w * 0.5)
			draw_colored_polygon(poly(f, fc), bar_color.darkened(0.2))
			draw_colored_polygon(poly(Rect2(f.position, Vector2(w, f.size.y * 0.5)), minf(fc, f.size.y * 0.25)), bar_color)
			draw_line(f.position + Vector2(fc, 1.5), Vector2(f.end.x - fc, f.position.y + 1.5), bar_color.lightened(0.5), 2.0)
		for i in range(1, segments):
			var x := track.position.x + track.size.x * i / segments
			draw_line(Vector2(x, track.position.y + 2), Vector2(x, track.end.y - 2), Color(0, 0, 0, 0.35), 2.0)
	# Light rim along the top edge.
	draw_line(Vector2(c, 4.5), Vector2(size.x - c, 4.5), Color(1, 1, 1, 0.22), 2.0)
