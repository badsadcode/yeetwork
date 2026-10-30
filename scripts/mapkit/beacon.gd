@tool
class_name Beacon
extends PuzzleNode
## A brazier: on while it burns. Light it with fire: carry a burning crate to it, walk up
## while burning yourself, burn a FuseLine into it, or switch it on with its inputs. Water
## (a flood up to the bowl) puts it out. A lit beacon sets alight whatever wooden thing (or
## Yeet) touches its flames, so one burning beacon can light the others. Start Lit: burning
## from the start (the level's source of fire). Burn Time: goes out after this long (0: never).

@export var start_lit := false
@export_range(0.0, 300.0, 1.0) var burn_time := 0.0
@export_enum("orange", "blue", "green", "gold", "violet") var palette := "orange":
	set(v):
		palette = v
		_rebuild()

const BOWL_Y := 1.25 # the bowl's height above the node
const REACH := 1.1 # fire this close to the bowl lights it

var _until := -1.0
var _parts: Node3D
var _fire: Burning
var _coal_mat: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var iron := Mats.plastic(Color(0.22, 0.2, 0.2), 0.6)
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = BOWL_Y + 0.2
	cs.shape = cyl
	cs.position.y = (BOWL_Y + 0.2) * 0.5
	body.add_child(cs)
	_parts.add_child(body)
	var stand := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.12
	sm.bottom_radius = 0.3
	sm.height = BOWL_Y - 0.2
	stand.mesh = sm
	stand.material_override = iron
	stand.position.y = (BOWL_Y - 0.2) * 0.5
	_parts.add_child(stand)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 0.3
	bm.height = 0.4
	bowl.mesh = bm
	bowl.material_override = iron
	bowl.position.y = BOWL_Y - 0.1
	_parts.add_child(bowl)
	# Coals: dark when out, glowing when lit.
	_coal_mat = StandardMaterial3D.new()
	_coal_mat.albedo_color = Color(0.1, 0.08, 0.07)
	_coal_mat.emission_enabled = true
	var coals := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.52
	cm.bottom_radius = 0.52
	cm.height = 0.05
	coals.mesh = cm
	coals.material_override = _coal_mat
	coals.position.y = BOWL_Y + 0.08
	_parts.add_child(coals)
	_tint()


func _tint() -> void:
	if _coal_mat == null:
		return
	var c: Color = Burning.PALETTES[palette][0]
	_coal_mat.emission = c if active else Color.BLACK
	_coal_mat.emission_energy_multiplier = 2.0 if active else 0.0


func bowl_position() -> Vector3:
	return global_position + Vector3.UP * (BOWL_Y + 0.1)


func evaluate() -> bool:
	var t: float = world.now()
	var bowl := bowl_position()
	if active:
		if (burn_time > 0.0 and t >= _until) or world.in_water(bowl):
			return false
		world.server_fire_spot(bowl, 0.9, self) # what touches the flames catches fire
		return true
	if world.in_water(bowl):
		return false
	if start_lit and _until < 0.0:
		return true
	if not inputs.is_empty() and inputs_on():
		return true
	return world.fire_near(bowl, REACH, self)


func server_switched(on: bool) -> void:
	if on:
		_until = world.now() + burn_time
	elif world.in_water(bowl_position()):
		world.server_fx("steam", bowl_position(), Vector3.UP, 1.0)


func _state_changed(play_fx: bool) -> void:
	_tint()
	if Engine.is_editor_hint():
		return
	if active and _fire == null:
		_fire = Burning.area(self, Transform3D(Basis.IDENTITY, Vector3.UP * (BOWL_Y + 0.5)), Vector3(0.9, 1.6, 0.9), palette)
		if play_fx:
			Sfx.play3d("whoosh", bowl_position(), 0.0, 0.7)
	elif not active and _fire:
		_fire.extinguish()
		var f := _fire
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(f):
				f.queue_free())
		_fire = null
		if play_fx:
			Sfx.play3d("sizzle", bowl_position(), 0.0, 1.0)
