class_name LensDrops
extends CanvasLayer
## Water droplets on the local camera's lens (lens_drops.gdshader): call wet() when the
## player comes out of the water or gets splashed; the drops run down and dry in a few seconds.

const DRY_TIME := 4.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _wet := 0.0
var _age := 0.0


func _ready() -> void:
	layer = -1 # over the 3D view, under the HUD
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/fx/lens_drops.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## amount 0..1: how much water landed on the lens (1 = just surfaced).
func wet(amount: float) -> void:
	if amount <= _wet:
		return
	if _wet <= 0.0:
		_age = 0.0
		_mat.set_shader_parameter("seed", randf() * 100.0)
	_wet = amount


func _process(delta: float) -> void:
	if _wet <= 0.0:
		_rect.visible = false
		return
	_wet = maxf(_wet - delta / DRY_TIME, 0.0)
	_age += delta
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("wet", _wet)
	_mat.set_shader_parameter("age", _age)
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_rect.visible = true
