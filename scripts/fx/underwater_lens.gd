class_name UnderwaterLens
extends CanvasLayer
## The local camera's view under water swims a little (underwater_lens.gdshader): a slow
## wobble and a soft colour fringe toward the screen's edges. Player sets `amount` (0 above
## water, 1 with the eyes under it); off entirely above water.

var amount := 0.0:
	set(v):
		amount = v
		if _rect:
			_rect.visible = v > 0.001
			_mat.set_shader_parameter("amount", v)
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = -2 # over the 3D view, under the lens drops and the HUD
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/fx/underwater_lens.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func _process(_delta: float) -> void:
	if _rect.visible:
		var size := get_viewport().get_visible_rect().size
		_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
