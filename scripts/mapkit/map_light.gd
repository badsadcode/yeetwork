@tool
class_name MapLight
extends PuzzleNode
## A light for dark maps (and any map): a bulb, a lamp post, a wall lamp, a candle, a torch, a
## spotlight or a neon tube, with its own little model and a light that can flicker. With
## Inputs it's a puzzle piece: on while its inputs are on ("restore the power and the lights
## come on"); without, it's always on.
## - Lamp post: put the node on the ground. Wall lamp: on a wall, facing out (local +Z).
##   Spotlight: it shines along local -Z (point it like a camera). Neon: a 1.2 m tube along X.
## - A Model (or the map theme's light_<kind>) replaces the look; a child named "Light" in it
##   is where the light shines from.

@export_enum("bulb", "lamp_post", "wall_lamp", "candle", "torch", "spotlight", "neon") var kind := "bulb":
	set(v):
		kind = v
		_rebuild()
@export var color := Color(1.0, 0.82, 0.55):
	set(v):
		color = v
		_rebuild()
## Brightness (1 = the usual for its kind).
@export_range(0.0, 8.0, 0.05) var energy := 1.0:
	set(v):
		energy = v
		_rebuild()
## How far it reaches, metres (0 = the usual for its kind).
@export_range(0.0, 60.0, 0.5) var reach := 0.0:
	set(v):
		reach = v
		_rebuild()
## none, candle (a gentle wobble), faulty (on, with sudden drop-outs), strobe, pulse (slow).
@export_enum("none", "candle", "faulty", "strobe", "pulse") var flicker := "none"
## Cast shadows (lovely, costs more; only on High graphics in the game).
@export var shadows := false:
	set(v):
		shadows = v
		_rebuild()
## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

## [height of the light above the node, range, energy] per kind.
const KINDS := {
	"bulb": [0.0, 9.0, 1.6],
	"lamp_post": [3.1, 14.0, 2.2],
	"wall_lamp": [0.0, 10.0, 1.6],
	"candle": [0.32, 4.5, 0.9],
	"torch": [0.75, 10.0, 2.0],
	"spotlight": [0.0, 22.0, 4.0],
	"neon": [0.0, 7.0, 1.4],
}

var _parts: Node3D
var _light: Light3D
var _glow_mat: StandardMaterial3D
var _base_energy := 1.0
var _seed := 0.0


func _ready() -> void:
	if inputs.is_empty():
		active = true # always on: no waiting for the server's first check
	_seed = fposmod(global_position.x * 12.9898 + global_position.z * 78.233, 100.0) if is_inside_tree() else 0.0
	_rebuild()


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func _state_changed(_play_fx: bool) -> void:
	_apply(1.0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var k: Array = KINDS[kind]
	var dark := Mats.plastic(Color(0.16, 0.16, 0.18), 0.5)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = color
	_glow_mat.emission_enabled = true
	_glow_mat.emission = color
	var at := Vector3(0, k[0], 0)
	match kind:
		"bulb":
			_parts.add_child(_sphere(0.11, _glow_mat, Vector3.ZERO))
			_parts.add_child(PuzzleNode.box_mesh(Vector3(0.08, 0.12, 0.08), dark, Vector3(0, 0.14, 0)))
		"lamp_post":
			_parts.add_child(_cyl(0.07, 0.1, 3.0, dark, Vector3(0, 1.5, 0)))
			_parts.add_child(_cyl(0.22, 0.25, 0.12, dark, Vector3(0, 0.06, 0)))
			_parts.add_child(_cyl(0.32, 0.14, 0.12, dark, Vector3(0, 3.36, 0)))
			_parts.add_child(_sphere(0.15, _glow_mat, Vector3(0, 3.18, 0)))
		"wall_lamp":
			_parts.add_child(PuzzleNode.box_mesh(Vector3(0.24, 0.32, 0.06), dark, Vector3(0, 0, 0.03)))
			_parts.add_child(_sphere(0.11, _glow_mat, Vector3(0, 0, 0.17)))
			at = Vector3(0, 0, 0.3)
		"candle":
			_parts.add_child(_cyl(0.05, 0.05, 0.26, Mats.plastic(Color(0.92, 0.88, 0.78), 0.6), Vector3(0, 0.13, 0)))
			_parts.add_child(_sphere(0.035, _glow_mat, Vector3(0, 0.3, 0), Vector3(0.7, 1.6, 0.7)))
		"torch":
			_parts.add_child(_cyl(0.04, 0.03, 0.6, Mats.plastic(Color(0.35, 0.22, 0.12), 0.8), Vector3(0, 0.3, 0)))
			_parts.add_child(_cyl(0.08, 0.06, 0.1, dark, Vector3(0, 0.6, 0)))
			_parts.add_child(_sphere(0.1, _glow_mat, Vector3(0, 0.72, 0), Vector3(0.9, 1.7, 0.9)))
		"spotlight":
			var housing := _cyl(0.16, 0.12, 0.3, dark, Vector3.ZERO)
			housing.rotation.x = PI * 0.5
			_parts.add_child(housing)
			var lens := _cyl(0.15, 0.15, 0.02, _glow_mat, Vector3(0, 0, -0.16))
			lens.rotation.x = PI * 0.5
			_parts.add_child(lens)
			at = Vector3(0, 0, -0.2)
		"neon":
			var tube := _cyl(0.035, 0.035, 1.2, _glow_mat, Vector3.ZERO)
			tube.rotation.z = PI * 0.5
			_parts.add_child(tube)
	var look := Looks.apply(_parts, MapTheme.pick(self, "light_" + kind, model))
	var marker := Looks.part(look, "Light")
	if marker:
		at = _parts.to_local(marker.global_position)
	if kind == "spotlight":
		var s := SpotLight3D.new()
		s.spot_angle = 32.0
		s.spot_angle_attenuation = 1.4
		s.spot_range = reach if reach > 0.0 else k[1]
		_light = s
	else:
		var o := OmniLight3D.new()
		o.omni_range = reach if reach > 0.0 else k[1]
		o.omni_attenuation = 1.2
		_light = o
	_light.position = at
	_light.light_color = color
	_base_energy = float(k[2]) * energy
	var high: bool = Engine.is_editor_hint() or Game.gfx.get("shadows", 2) >= 2
	_light.shadow_enabled = shadows and high
	_light.light_volumetric_fog_energy = 1.5
	_parts.add_child(_light)
	_apply(1.0)


## Light and glow at this much of their brightness (0 when off).
func _apply(k: float) -> void:
	if _light == null:
		return
	var on := k * (1.0 if active else 0.0)
	_light.light_energy = _base_energy * on
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = 2.5 * on
		_glow_mat.albedo_color = color if on > 0.05 else color.darkened(0.6)


func _process(_delta: float) -> void:
	if flicker == "none" or not active or _light == null:
		return
	var t := Time.get_ticks_msec() / 1000.0 + _seed
	var k := 1.0
	match flicker:
		"candle":
			k = 0.82 + 0.1 * sin(t * 9.0) + 0.08 * sin(t * 23.0 + 1.3)
		"faulty":
			# Mostly on; now and then it stutters out for a moment.
			var slot := floori(t * 9.0)
			var r := fposmod(sin(float(slot) * 127.1 + _seed * 3.7) * 43758.5453, 1.0)
			k = 0.05 if r < 0.12 else (0.55 if r < 0.2 else 1.0)
		"strobe":
			k = 1.0 if fposmod(t * 8.0, 1.0) < 0.35 else 0.0
		"pulse":
			k = 0.55 + 0.45 * sin(t * 2.2)
	_apply(k)


func _sphere(r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mat == _glow_mat else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func _cyl(top: float, bottom: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mat == _glow_mat else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi
