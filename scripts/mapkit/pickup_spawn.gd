@tool
class_name PickupSpawn
extends Node3D
## A pickup floating over a pad on the floor: walk through it to take it. It comes back
## after a while. First aid kits heal; power-ups give a boost for a few seconds (see
## Pickups for what each one does). Put the node on the floor: the item floats a metre up.
## The host can turn power-ups (or all pickups) off; the Puzzle mode has none.

@export_enum("health", "health_big", "speed", "super", "feather", "iron", "random") var kind := "health":
	set(v):
		kind = v
		_rebuild()
## Seconds until it's back after someone takes it (0: the usual for its kind).
@export_range(0.0, 300.0, 1.0) var respawn := 0.0

var shown_kind := "" # what it is right now (a random one changes each time)
var _item: Node3D
var _pad: MeshInstance3D
var _available := true
var _t := 0.0


func _ready() -> void:
	_rebuild()


## The server says what's on the pad: available (and which kind), or gone for now.
func set_state(available: bool, k: String) -> void:
	_available = available
	if k != shown_kind:
		shown_kind = k
		_build_item()
	if _item:
		_item.visible = available
	if _pad:
		(_pad.material_override as StandardMaterial3D).albedo_color.a = 0.85 if available else 0.25


## Hidden entirely (pickups off for this match, or this kind isn't allowed).
func set_disabled() -> void:
	visible = false


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _pad == null:
		_pad = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.42
		ring.outer_radius = 0.55
		ring.rings = 24
		ring.ring_segments = 6
		_pad.mesh = ring
		_pad.scale = Vector3(1, 0.12, 1)
		_pad.position.y = 0.03
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pad.material_override = m
		_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_pad, false, Node.INTERNAL_MODE_FRONT)
	shown_kind = Pickups.RANDOM_PREVIEW if kind == "random" else kind
	_build_item()


func _build_item() -> void:
	if _item:
		_item.queue_free()
	_item = Pickups.build_model(shown_kind)
	_item.position.y = 1.0
	_item.visible = _available
	add_child(_item, false, Node.INTERNAL_MODE_FRONT)
	if _pad:
		var c: Color = Pickups.color_of(shown_kind)
		c.a = 0.85 if _available else 0.25
		(_pad.material_override as StandardMaterial3D).albedo_color = c


## Something on the pad to take right now.
func is_available() -> bool:
	return visible and _available and shown_kind != ""


## Where a Yeet touches it (the item, floating over the pad).
func item_position() -> Vector3:
	return global_position + Vector3.UP * 1.0


func _process(delta: float) -> void:
	if _item == null:
		return
	_t += delta
	_item.rotation.y = _t * 1.6
	_item.position.y = 1.0 + sin(_t * 2.2) * 0.1
