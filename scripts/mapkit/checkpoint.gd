@tool
class_name Checkpoint
extends PuzzleNode
## A flag on a ring. Once any player reaches it, it turns green and (in the Puzzle mode)
## everyone who dies respawns here. The last one reached counts.

@export_range(1.0, 10.0, 0.1) var radius := 3.0:
	set(v):
		radius = v
		_rebuild()

## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var _ring_mat: StandardMaterial3D
var _parts: Node3D


func _ready() -> void:
	latch = true
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.emission_enabled = true
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.12
	tm.outer_radius = radius
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.position.y = 0.05
	_parts.add_child(ring)
	_parts.add_child(PuzzleNode.box_mesh(Vector3(0.12, 2.6, 0.12), Mats.world(Color(0.85, 0.85, 0.9), 0.4, 0.5), Vector3(0, 1.3, 0)))
	var flag := PuzzleNode.box_mesh(Vector3(0.9, 0.55, 0.04), _ring_mat, Vector3(0.48, 2.25, 0))
	_parts.add_child(flag)
	_tint()
	Looks.apply(_parts, MapTheme.pick(self, "checkpoint", model))


func _tint() -> void:
	if _ring_mat == null:
		return
	var c := Color(0.3, 1.0, 0.45) if active else Color(0.75, 0.75, 0.85)
	_ring_mat.albedo_color = c
	_ring_mat.emission = c
	_ring_mat.emission_energy_multiplier = 2.5 if active else 0.4


func evaluate() -> bool:
	return not players_in(Vector3(0, 1.0, 0), Vector3(radius * 2.0, 3.0, radius * 2.0)).is_empty()


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx and active:
		Sfx.play3d("pickup", global_position, 0.0, 0.8)


## A spot near the flag for a respawning player.
func spawn_spot(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var r := rng.randf_range(0.8, maxf(radius - 0.6, 0.9))
	return global_position + Vector3(cos(a) * r, 0.2, sin(a) * r)
