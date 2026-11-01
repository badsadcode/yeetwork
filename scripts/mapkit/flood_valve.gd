@tool
class_name FloodValve
extends PuzzleNode
## A pipe that pours water into the FloodZone it's in while its inputs are on (always, with
## no inputs): fill a room, raise a raft, flush a corridor. Put it on a wall or a ceiling;
## the water falls straight down from the node. Rate: m³ a second (a 4 x 4 m room rises
## ~6 cm a second at 1). Total: stops after pouring this much (0: never).

## How fast it pours, cubic metres a second (a 10 x 12 m room rises 1 m per 120).
@export_range(0.1, 20.0, 0.1) var rate := 2.0
## Stops after pouring this much, cubic metres (0: never).
@export_range(0.0, 2000.0, 1.0) var total := 0.0
## How wide the water lands where it pours, metres.
@export_range(0.2, 3.0, 0.1) var radius := 0.6

## Your own model for it (a scene: an imported .glb...), instead of the built-in look and
## the map theme's.
## A child named "Wheel" turns while it pours; one named "Spout" is where the water comes out,
## the way it points (its Y axis: a Blender arrow empty's arrow), say sideways out of a pipe
## in a wall: the water arcs out and lands where it falls.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()

var poured := 0.0 # host
var _zone: FloodZone
var _parts: Node3D
var _stream: CPUParticles3D
var _wheel: Node3D # the model's "Wheel", turning while it pours
var _spout: Node3D # the model's "Spout": where the water comes out, and which way
const SPOUT_SPEED := 4.0 # (m/s out of a Spout; the built-in pipe just lets it fall)
var _splash: CPUParticles3D
var _sound_t := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var metal := Mats.plastic(Color(0.45, 0.5, 0.58), 0.35)
	var pipe := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.28
	cm.height = 0.6
	pipe.mesh = cm
	pipe.material_override = metal
	pipe.position.y = 0.2
	_parts.add_child(pipe)
	var lip := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.36
	lm.bottom_radius = 0.36
	lm.height = 0.1
	lip.mesh = lm
	lip.material_override = metal
	lip.position.y = -0.1
	_parts.add_child(lip)
	var look := Looks.apply(_parts, MapTheme.pick(self, "valve", model))
	_wheel = Looks.part(look, "Wheel")
	_spout = Looks.part(look, Looks.SPOUT)
	if Engine.is_editor_hint():
		return
	# The falling water: a column of streaks, and spray where it lands.
	_stream = CPUParticles3D.new()
	_stream.amount = 70
	_stream.lifetime = 0.9
	_stream.emitting = false
	_stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_stream.emission_sphere_radius = 0.18
	_stream.direction = Vector3.DOWN
	_stream.spread = 4.0
	_stream.initial_velocity_min = 2.0
	_stream.initial_velocity_max = 3.0
	_stream.gravity = Vector3(0, -24, 0)
	_stream.scale_amount_min = 0.5
	_stream.scale_amount_max = 0.9
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.7)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.75, 0.88, 1.0, 0.55)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = wm
	_stream.mesh = qm
	_stream.position.y = -0.15
	_parts.add_child(_stream)
	if _spout:
		_stream.initial_velocity_min = SPOUT_SPEED * 0.85
		_stream.initial_velocity_max = SPOUT_SPEED
		_stream.local_coords = false
	_splash = CPUParticles3D.new()
	_splash.amount = 40
	_splash.lifetime = 0.6
	_splash.emitting = false
	_splash.direction = Vector3.UP
	_splash.spread = 50.0
	_splash.initial_velocity_min = 2.0
	_splash.initial_velocity_max = 4.0
	_splash.gravity = Vector3(0, -18, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	var spm := StandardMaterial3D.new()
	spm.albedo_color = Color(0.92, 0.97, 1.0, 0.8)
	spm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = spm
	_splash.mesh = sm
	_parts.add_child(_splash)


func link() -> void:
	_zone = FloodZone.at(world, spout()[0]) # (where the water comes out: a pipe on a pool's wall)


## Where the water comes out (the model's Spout, or the pipe's mouth) and which way.
func spout() -> Array:
	if _spout and _spout.is_inside_tree():
		return [_spout.global_position, _spout.global_basis.y.normalized()]
	return [global_position + Vector3.DOWN * 0.15, Vector3.DOWN]


## Where the water lands (thrown out of a Spout at SPOUT_SPEED, it arcs; out of the built-in
## pipe it falls straight down), and the height it lands at.
func landing() -> Vector3:
	var s := spout()
	var p: Vector3 = s[0]
	var d: Vector3 = s[1]
	var v := SPOUT_SPEED if _spout else 0.0
	var below := _ground_at(p)
	var h := maxf(p.y - below, 0.0)
	var vy := d.y * v
	var t := (vy + sqrt(vy * vy + 2.0 * 24.0 * h)) / 24.0
	var out := p + Vector3(d.x, 0, d.z) * v * t
	out.y = below
	return out


func _ground_at(p: Vector3) -> float:
	if _zone:
		var s := _zone.surface_at(p)
		if s > -1.0e5:
			return s
	return _floor_below(p)


func evaluate() -> bool:
	if total > 0.0 and poured >= total:
		return false
	return inputs.is_empty() or inputs_on()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or world == null or not active:
		return
	if _zone == null:
		_zone = FloodZone.at(world, spout()[0])
	if world.is_server and _zone:
		var amount := rate * delta
		if total > 0.0:
			amount = minf(amount, total - poured)
		if amount > 0.0:
			_zone.pour(landing() if _spout else global_position, radius, amount)
			poured += amount


func _state_changed(play_fx: bool) -> void:
	if _stream:
		_stream.emitting = active
		_splash.emitting = active
	if play_fx:
		Sfx.play3d("splash", global_position, -2.0, 0.8 if active else 1.2)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _stream == null or not active:
		return
	if _wheel:
		_wheel.rotate_object_local(Vector3.FORWARD, delta * 4.0)
	# The stream falls (or arcs out of a Spout) to the water or the floor below.
	var s := spout()
	var land := landing()
	var fall := maxf((s[0] as Vector3).y - land.y, 0.3)
	_stream.lifetime = clampf(sqrt(2.0 * fall / 24.0) + 0.05 + (0.1 if _spout else 0.0), 0.15, 1.4)
	if _spout:
		_stream.global_position = s[0]
		_stream.direction = _stream.global_basis.inverse() * (s[1] as Vector3)
	_splash.global_position = land + Vector3.UP * 0.05
	_sound_t -= delta
	if _sound_t <= 0.0:
		_sound_t = 0.7
		Sfx.play3d("splash", _splash.global_position, -10.0, randf_range(0.7, 0.9))


func _floor_below(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.DOWN * 0.3, p + Vector3.DOWN * 30.0, Game.L_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else p.y - 6.0


func problems() -> Array[String]:
	var out := super.problems()
	if FloodZone.at(world, spout()[0]) == null and world != null:
		out.append("%s: the valve isn't inside a FloodZone." % name)
	return out
