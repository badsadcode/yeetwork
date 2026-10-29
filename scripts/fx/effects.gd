class_name Effects
extends Node3D
## Local-only visual effects: blood (or confetti), persistent decals, explosions, debris
## chunks, punt shockwaves. Called by World when the server broadcasts an effect.

const MAX_DECALS := 320
const MAX_CHUNKS := 160

var _decals: Array[Decal] = []
var _chunks: Array[RigidBody3D] = []
var _blood_mat: StandardMaterial3D
var _drop_mesh: SphereMesh
var _chunk_mesh: BoxMesh
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "FX"
	_rng.randomize()
	_blood_mat = Mats.plastic(Color(0.75, 0.02, 0.05), 0.15)
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.05
	_drop_mesh.height = 0.1
	_drop_mesh.radial_segments = 6
	_drop_mesh.rings = 3
	_chunk_mesh = BoxMesh.new()
	_chunk_mesh.size = Vector3.ONE


func _space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


# --- Blood ------------------------------------------------------------------------

## `dir` is the travel direction of whatever got squished; splatter sprays along it.
func blood(pos: Vector3, normal: Vector3, dir: Vector3, amount: float) -> void:
	amount = clampf(amount, 0.1, 3.0)
	if Game.gore_level == 0:
		_confetti(pos, normal, amount)
		return
	var mult := 1.0 if Game.gore_level == 1 else 2.5
	var a := amount * mult
	_burst(pos, normal + dir.normalized() * 0.6, int(18 * a) + 6, _drop_mesh, _blood_mat, 3.0, 10.0 * clampf(a, 0.6, 2.0), 1.1)
	var travel := dir.normalized() if dir.length() > 0.1 else -normal
	var rays := int(3 + a * 4)
	for i in rays:
		var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.8
		var ray_dir := (travel + spread).normalized() if i % 2 == 0 else (-normal + spread * 1.3).normalized()
		var q := PhysicsRayQueryParameters3D.create(pos + normal * 0.2, pos + normal * 0.2 + ray_dir * (2.5 + a * 2.0), Game.L_WORLD)
		var hit := _space().intersect_ray(q)
		if hit.is_empty():
			continue
		var size := _rng.randf_range(0.5, 1.4) * clampf(a, 0.6, 2.4)
		_decal(hit.position, hit.normal, travel, size, Color(0.55, 0.0, 0.03, 0.95), _rng.randf_range(1.0, 2.2))
	if Game.gore_level == 2 and amount > 1.0:
		for i in int(amount * 3):
			_chunk(pos + normal * 0.3, Vector3(0.12, 0.12, 0.12), Color(0.7, 0.05, 0.08), (normal + travel) * 6.0 + _rand_vec() * 4.0, 3.0)


func _confetti(pos: Vector3, normal: Vector3, amount: float) -> void:
	var cols := [Color(1, 0.3, 0.4), Color(1, 0.85, 0.2), Color(0.3, 0.8, 1), Color(0.5, 1, 0.4), Color(0.9, 0.4, 1)]
	for c in cols:
		var m := BoxMesh.new()
		m.size = Vector3(0.08, 0.02, 0.06)
		_burst(pos, normal, int(6 * amount) + 2, m, Mats.plastic(c, 0.4, 0.5), 3.0, 8.0, 1.5, 6.0)


func _decal(pos: Vector3, normal: Vector3, travel: Vector3, size: float, tint: Color, stretch := 1.0) -> void:
	var d := Decal.new()
	var tex := Mats.splat_textures()
	d.texture_albedo = tex[_rng.randi() % tex.size()]
	d.modulate = tint
	d.albedo_mix = 1.0
	d.normal_fade = 0.35
	d.upper_fade = 0.1
	d.lower_fade = 0.2
	var tangent := travel - normal * travel.dot(normal)
	if tangent.length() < 0.1:
		tangent = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT)
	tangent = tangent.normalized().rotated(normal, _rng.randf_range(-0.4, 0.4))
	var y := normal.normalized()
	var x := tangent
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	d.size = Vector3(size * stretch, 0.8, size)
	add_child(d)
	d.global_transform = Transform3D(Basis(x, y, z), pos)
	_decals.append(d)
	if _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func scorch(pos: Vector3, radius: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 3.0, Game.L_WORLD)
	var hit := _space().intersect_ray(q)
	if not hit.is_empty():
		_decal(hit.position, hit.normal, Vector3.FORWARD, radius * 1.6, Color(0.05, 0.04, 0.04, 0.9), 1.0)


# --- Particles & chunks ---------------------------------------------------------------

func _burst(pos: Vector3, dir: Vector3, amount: int, mesh: Mesh, mat: Material, vmin: float, vmax: float, life: float, damp := 0.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.mesh = mesh
	p.material_override = mat
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, -24, 0)
	p.damping_min = damp
	p.damping_max = damp
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.local_coords = false
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func _rand_vec() -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))


func _chunk(pos: Vector3, size: Vector3, color: Color, vel: Vector3, life: float) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = Game.L_LIMBS
	rb.collision_mask = Game.L_WORLD | Game.L_LIMBS
	rb.mass = maxf(size.x * size.y * size.z * 40.0, 0.2)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _chunk_mesh
	mi.scale = size
	mi.material_override = Mats.world(color, 0.7)
	rb.add_child(mi)
	add_child(rb)
	rb.global_position = pos
	rb.linear_velocity = vel
	rb.angular_velocity = _rand_vec() * 10.0
	_chunks.append(rb)
	if _chunks.size() > MAX_CHUNKS:
		var old = _chunks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var t := get_tree().create_timer(life + _rng.randf() * 2.0)
	t.timeout.connect(func():
		if is_instance_valid(rb):
			var tw := rb.create_tween()
			tw.tween_property(mi, "scale", Vector3.ONE * 0.001, 0.6)
			tw.tween_callback(rb.queue_free)
	)


func wall_break(pos: Vector3, cell_size: Vector3, color: Color, impulse: Vector3) -> void:
	for i in 4:
		var s := cell_size * _rng.randf_range(0.2, 0.4)
		_chunk(pos + _rand_vec() * cell_size * 0.3, s, color, impulse * 0.4 + _rand_vec() * 4.0, 5.0)
	var m := SphereMesh.new()
	m.radius = 0.25
	m.height = 0.5
	_burst(pos, impulse.normalized() + Vector3.UP * 0.3, 10, m, Mats.plastic(color.lightened(0.3), 1.0), 1.0, 4.0, 0.9, 3.0)


func explosion(pos: Vector3, radius: float) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.25)
	flash.light_energy = 12.0
	flash.omni_range = radius * 3.0
	add_child(flash)
	flash.global_position = pos
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.5)
	tw.tween_callback(flash.queue_free)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	ball.mesh = sm
	var mat := Mats.glow(Color(1.0, 0.55, 0.15), 6.0, true).duplicate() as StandardMaterial3D
	ball.material_override = mat
	add_child(ball)
	ball.global_position = pos
	ball.scale = Vector3.ONE * 0.3
	var tw2 := ball.create_tween().set_parallel(true)
	tw2.tween_property(ball, "scale", Vector3.ONE * radius, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw2.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw2.chain().tween_callback(ball.queue_free)
	var smoke := SphereMesh.new()
	smoke.radius = 0.5
	smoke.height = 1.0
	_burst(pos, Vector3.UP, 14, smoke, Mats.plastic(Color(0.25, 0.22, 0.25), 1.0), 2.0, 7.0, 1.6, 4.0)
	_burst(pos, Vector3.UP, 30, _drop_mesh, Mats.glow(Color(1.0, 0.7, 0.2), 4.0), 6.0, 18.0, 0.8)
	scorch(pos, radius * 0.5)


func shockwave(pos: Vector3, dir: Vector3, color := Color(0.5, 0.95, 1.0)) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.4
	tm.outer_radius = 0.5
	ring.mesh = tm
	var mat := Mats.glow(color, 3.0, true).duplicate() as StandardMaterial3D
	ring.material_override = mat
	add_child(ring)
	var up := dir.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	ring.global_transform = Transform3D(Basis(side, up, side.cross(up)), pos)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(5, 1, 5), 0.25)
	tw.tween_property(ring, "position", ring.position + up * 2.0, 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(ring.queue_free)


func zap(pos: Vector3) -> void:
	var m := SphereMesh.new()
	m.radius = 0.04
	m.height = 0.08
	_burst(pos, Vector3.UP, 12, m, Mats.glow(Color(0.5, 1.0, 1.0), 5.0), 1.0, 4.0, 0.4)


func puff(pos: Vector3, normal: Vector3, color := Color(0.9, 0.9, 0.95)) -> void:
	var m := SphereMesh.new()
	m.radius = 0.15
	m.height = 0.3
	_burst(pos, normal, 6, m, Mats.plastic(color, 1.0), 1.0, 3.0, 0.5, 4.0)
