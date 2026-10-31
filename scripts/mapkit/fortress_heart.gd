@tool
class_name FortressHeart
extends Node3D
## MegaYeet: what the players defend (put one at the fortress's centre). Monsters head for it
## through the fortress; one that reaches it (within Radius) takes a big bite out of the
## Fortress meter. The built-in look is a glowing crystal over a pedestal; Model (or the
## theme's `heart` slot) replaces it: a throne, a reactor, a giant cake.
## MegaYeet Rules: how the game goes on this map (the Fortress meter's size, what a bite and
## a kill are worth, the breaks, how big the waves get): tune it to the fortress you built.

@export var radius := 2.5:
	set(v):
		radius = v
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()
@export var color := Color(0.35, 0.9, 1.0):
	set(v):
		color = v
		_rebuild()

@export_group("MegaYeet Rules")
## The Fortress meter: how much it holds (the team's life).
@export_range(100.0, 10000.0, 10.0) var health := 1000.0
## What a monster reaching the Heart takes off it.
@export_range(0.0, 1000.0, 1.0) var bite := 40.0
## What a kill puts back, and the extra for a stylish one (a fall, a crush, fire, lava...).
@export_range(0.0, 100.0, 0.5) var kill_refill := 3.0
@export_range(0.0, 100.0, 0.5) var style_refill := 2.0
## What holding a wave puts back.
@export_range(0.0, 2000.0, 5.0) var wave_bonus := 60.0
## Seconds before the first wave, and between waves.
@export_range(3.0, 120.0, 1.0) var first_break := 12.0
@export_range(3.0, 300.0, 1.0) var break_time := 25.0
## How many monsters a wave brings, times this (1: 24 in wave 1, ten more each wave).
@export_range(0.2, 5.0, 0.05) var wave_size := 1.0
## The most monsters at once (the rest of a wave waits for room). Mind the Steam Deck.
@export_range(10, 400, 5) var max_monsters := 220

var _parts: Node3D
var _gem: Node3D
var _gem_mat: StandardMaterial3D
var _light: OmniLight3D
var _t := 0.0
var _hurt := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var stone := Mats.plastic(Color(0.55, 0.55, 0.6), 0.8)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.3
	cm.height = 1.2
	cm.radial_segments = 8
	ped.mesh = cm
	ped.position.y = 0.6
	ped.material_override = stone
	_parts.add_child(ped)
	_gem = Node3D.new()
	_gem.position.y = 2.6
	_parts.add_child(_gem)
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new() # (four segments, two rings: an octahedron, a crystal)
	sm.radius = 0.75
	sm.height = 2.2
	sm.radial_segments = 4
	sm.rings = 2
	gem.mesh = sm
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = color
	_gem_mat.emission_enabled = true
	_gem_mat.emission = color
	_gem_mat.emission_energy_multiplier = 2.0
	_gem_mat.roughness = 0.1
	gem.material_override = _gem_mat
	_gem.add_child(gem)
	Looks.apply(_parts, MapTheme.pick(self, "heart", model))
	if Engine.is_editor_hint():
		return
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 9.0
	_light.light_energy = 2.0
	_light.position.y = 2.6
	_parts.add_child(_light)


## A monster got through: a red flash and a shudder (every peer).
func hurt() -> void:
	_hurt = 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _gem == null:
		return
	_t += delta
	_hurt = maxf(_hurt - delta * 1.5, 0.0)
	_gem.rotation.y = _t * 0.6
	_gem.position.y = 2.6 + sin(_t * 1.4) * 0.12 + randf_range(-1, 1) * _hurt * 0.08
	var c := color.lerp(Color(1.0, 0.15, 0.1), _hurt)
	_gem_mat.emission = c
	_gem_mat.albedo_color = c
	if _light:
		_light.light_color = c
		_light.light_energy = 2.0 + _hurt * 4.0
