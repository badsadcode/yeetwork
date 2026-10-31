@tool
class_name PuzzleTarget
extends PuzzleNode
## A bullseye that turns on when something thrown hits it hard enough. Faces its local +Z
## (rotate it to aim; lay it flat for a floor target). Kind: only that kind of prop counts
## ("any": anything). Stay On: seconds it stays on after a hit (0: for good).

@export_range(0.3, 4.0, 0.05) var radius := 0.8:
	set(v):
		radius = v
		_rebuild()
@export_enum("any", "ball", "beachball", "crate", "crate_big", "barrel", "boom_barrel", "anvil", "plank", "couch", "tire", "cone") var kind := "any"
## How fast the thing must hit (m/s): ~5 is a gentle throw, ~15 a hard one.
@export_range(0.0, 40.0, 0.5) var min_speed := 5.0
@export_range(0.0, 120.0, 0.5) var stay_on := 4.0

## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var _parts: Node3D
var _ring_mats: Array[StandardMaterial3D] = []
var _on_until := -1.0
var _flash := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_ring_mats.clear()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var body := StaticBody3D.new()
	body.collision_layer = 1 # Game.L_WORLD (no autoloads in the editor)
	body.collision_mask = 0
	body.set_meta("puzzle_target", self)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.2
	cs.shape = cyl
	cs.rotation_degrees = Vector3(90, 0, 0)
	body.add_child(cs)
	_parts.add_child(body)
	# Rings, outermost first, each slightly in front of the last.
	for i in 4:
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		_ring_mats.append(m)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius * (1.0 - i * 0.24)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.2 + i * 0.02
		cm.radial_segments = 32
		mi.mesh = cm
		mi.material_override = m
		mi.rotation_degrees = Vector3(90, 0, 0)
		_parts.add_child(mi)
	_tint()
	Looks.apply(_parts, MapTheme.pick(self, "target", model))


func _tint() -> void:
	for i in _ring_mats.size():
		var m := _ring_mats[i]
		var c: Color
		if active:
			c = Color(0.35, 1.0, 0.45) if i % 2 == 0 else Color(0.85, 1.0, 0.85)
		else:
			c = Color(0.95, 0.2, 0.15) if i % 2 == 0 else Color(0.97, 0.95, 0.9)
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = (2.0 if active else 0.3) + _flash * 3.0


## Server: a prop hit the target (World.server_prop_impact).
func server_hit(p: Prop, speed: float) -> void:
	if speed < min_speed or (kind != "any" and p.kind != kind):
		return
	_on_until = INF if stay_on <= 0.0 else world.now() + stay_on


func evaluate() -> bool:
	return world.now() < _on_until


func _state_changed(play_fx: bool) -> void:
	_flash = 1.0 if active else 0.0
	_tint()
	if play_fx and active:
		Sfx.play3d("score", global_position, -6.0, 1.5)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.0, 0.0)
		_tint()
