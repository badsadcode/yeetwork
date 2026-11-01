@tool
class_name HazardVolume
extends Node3D
## A box that does something to whatever is in it, by Kind: acid or lava (a glowing pool that
## hurts and bounces you up), water (a pool to swim in; wood and rubber float), kill (instant
## death: under a void), wind (a constant push: an updraft) or fire (a burning place: flames
## over the bottom of the box that set players and wood alight).

## acid and lava hurt and bounce up; water is a pool to swim in; kill is instant death (under-
## map voids); wind pushes (updrafts); fire sets alight what's in it.
@export_enum("acid", "kill", "wind", "water", "lava", "fire") var kind := "acid":
	set(v):
		kind = v
		_rebuild()
## Its box, metres. For a liquid the surface sits 80% of the way up (give it a floor and
## walls).
@export var size := Vector3(8, 2, 8):
	set(v):
		size = v
		_rebuild()
## Acid / lava: damage per touch. Others: ignored.
@export var damage := 22.0
## Fire: the colour of the flames (orange fire, or blue / green magic fire).
@export_enum("orange", "blue", "green") var fire_color := "orange"
## Wind: acceleration in m/s^2 (world space).
@export var wind := Vector3(0, 30, 0)

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var bm := BoxMesh.new()
	bm.size = size
	_preview.mesh = bm
	var cols := {"acid": Color(0.45, 1, 0.2, 0.35), "kill": Color(1, 0.1, 0.1, 0.25), "wind": Color(0.6, 0.9, 1, 0.2), "water": Color(0.1, 0.55, 0.7, 0.4), "lava": Color(1, 0.4, 0.05, 0.45), "fire": Color(1, 0.55, 0.1, 0.35)}
	var m := StandardMaterial3D.new()
	m.albedo_color = cols[kind]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview.material_override = m
