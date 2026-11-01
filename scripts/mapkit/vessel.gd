@tool
class_name Vessel
extends Node3D
## A ship, a boat, a raft: everything under this node rides the sea's swell together, heaving,
## pitching and rolling the way High Seas' ship does (the same on every player's screen, with
## nothing sent). Build it from any pieces as children of this node: blocks for its hull and
## deck, breakable walls, ladders, a crane, a horn, machines, pickups, props, spawn points.
## Players and props on it ride along; loose cargo slides when it tilts. Needs the map's ocean
## (MapSettings > Ocean); one Vessel a map.
## - Put the node at the water's level (its origin on the waterline), bow along its +X (the red
##   arrow).
## - On a map with a Vessel, its spawn points, props and flag stands go on it (under this node):
##   they're kept in the ship's own frame. The map check says if one is left off.
## - Length and Beam: the hull it floats on (0: the size of its blocks), what the swell lifts.

## Bow to stern, along +X (metres; 0: its blocks' length).
@export_range(0.0, 400.0, 0.5) var length := 0.0:
	set(v):
		length = v
		_rebuild()
## Side to side (metres; 0: its blocks' width).
@export_range(0.0, 100.0, 0.5) var beam := 0.0:
	set(v):
		beam = v
		_rebuild()
## How hard it rolls with the swell, and the most it leans over (degrees), and pitches.
@export_range(0.0, 8.0, 0.1) var roll := 3.2
@export_range(0.0, 45.0, 0.5) var max_roll_degrees := 16.0
@export_range(0.0, 20.0, 0.5) var max_pitch_degrees := 6.0
## How much it rises and falls with the water (1: as much as the water).
@export_range(0.0, 2.0, 0.05) var heave := 0.8
## Seconds it lags behind the water (a big heavy ship: more).
@export_range(0.0, 3.0, 0.05) var lag := 0.8
## High Seas' own weather on it in a stormy sea: green water washing over the rail, rogue
## waves, spray off the hull (laid out for High Seas' ship: about 140 x 32 m, its deck 8 m up).
@export var high_seas_weather := false

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


## The editor: its waterline (Length by Beam).
func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.7, 1.0, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pm := PlaneMesh.new()
	pm.size = Vector2(maxf(length, 1.0), maxf(beam, 1.0))
	_preview.mesh = pm
	_preview.material_override = m
	_preview.visible = length > 0.0 and beam > 0.0
