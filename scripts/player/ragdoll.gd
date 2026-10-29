class_name Ragdoll
extends Node3D
## Physics corpse built from a CharacterModel's parts: rigid bodies joined by cone-twist
## joints. Purely local (every peer simulates its own), which is fine for comedy.

const LIFETIME := 25.0

var torso: RigidBody3D
var bodies: Array[RigidBody3D] = []
var _age := 0.0
var _last_bleed := 0.0
var _world: Node


static func spawn(parent: Node, model: CharacterModel, _xform: Transform3D, velocity: Vector3, _color: Color) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Corpse"
	parent.add_child(r)
	r._world = parent.get_parent()
	r._build(model, velocity)
	return r


func _build(model: CharacterModel, velocity: Vector3) -> void:
	var by_name := {}
	for part_name in CharacterModel.PART_SPECS:
		var src: Node3D = model.parts[part_name]
		var spec: Array = CharacterModel.PART_SPECS[part_name]
		var rb := RigidBody3D.new()
		rb.collision_layer = Game.L_LIMBS
		rb.collision_mask = Game.L_WORLD | Game.L_PROPS | Game.L_LIMBS
		rb.mass = 30.0 if part_name == "torso" else (6.0 if part_name == "head" else 4.0)
		rb.linear_damp = 0.1
		rb.angular_damp = 0.8
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.3
		pm.friction = 0.8
		rb.physics_material_override = pm
		var cs := CollisionShape3D.new()
		if spec[0] == "sphere":
			var sh := SphereShape3D.new()
			sh.radius = spec[1]
			cs.shape = sh
		else:
			var sh := CapsuleShape3D.new()
			sh.radius = spec[1]
			sh.height = spec[2]
			cs.shape = sh
		cs.position = spec[3]
		rb.add_child(cs)
		var visual := src.duplicate() as Node3D
		visual.transform = Transform3D.IDENTITY
		_restore_shadows(visual)
		rb.add_child(visual)
		add_child(rb)
		rb.global_transform = Transform3D(src.global_transform.basis.orthonormalized(), src.global_position)
		var jitter := Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 2.0
		rb.linear_velocity = velocity + jitter
		rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		bodies.append(rb)
		by_name[part_name] = rb
	torso = by_name.torso
	torso.contact_monitor = true
	torso.max_contacts_reported = 2
	torso.body_entered.connect(_on_torso_hit)
	for a in bodies:
		for b in bodies:
			if a != b:
				a.add_collision_exception_with(b)
	for part_name in ["head", "arm_l", "arm_r", "leg_l", "leg_r"]:
		var limb: RigidBody3D = by_name[part_name]
		var j := ConeTwistJoint3D.new()
		add_child(j)
		var anchor := limb.global_position
		if part_name == "head":
			anchor = limb.global_position - limb.global_transform.basis.y * 0.3
		j.global_transform = Transform3D(limb.global_transform.basis, anchor)
		j.node_a = j.get_path_to(torso)
		j.node_b = j.get_path_to(limb)
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(70.0 if part_name != "head" else 35.0))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(30.0))


func _restore_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_restore_shadows(c)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		var t := clampf((_age - LIFETIME) / 1.5, 0.0, 1.0)
		for rb in bodies:
			if is_instance_valid(rb):
				for c in rb.get_children():
					if c is Node3D and not (c is CollisionShape3D):
						(c as Node3D).scale = Vector3.ONE * (1.0 - t) + Vector3.ONE * 0.001
		if t >= 1.0:
			queue_free()
	if torso and torso.global_position.y < -80.0:
		queue_free()


func _on_torso_hit(_other: Node) -> void:
	var speed := torso.linear_velocity.length()
	if speed < 7.0 or _age - _last_bleed < 0.15:
		return
	_last_bleed = _age
	if _world and _world.has_method("local_blood"):
		_world.local_blood(torso.global_position, -torso.linear_velocity.normalized(), torso.linear_velocity, clampf(speed / 15.0, 0.3, 1.2))
	Sfx.play3d("splat", torso.global_position, -4.0, randf_range(0.8, 1.2))
