class_name GravityGun
extends Node3D
## The gravity gun. Gameplay runs on the server (grab, pull, hold, throw, punt, freeze);
## every peer draws the beam from the replicated held target.
##
## Hold LMB: pull/grab whatever is under the crosshair (also catches incoming objects).
## Release LMB: drop, keeping momentum.  RMB while holding: hold to charge, release to
## throw (tap = normal throw, full charge ~1.8x as hard). RMB with nothing held: punt
## everything in a cone (and gravity-jump off a nearby surface when there is nothing).

enum Action { GRAB_START, GRAB_END, THROW, FREEZE, THROW_RELEASE }
enum Kind { NONE, PROP, PLAYER }

const PULL_RANGE := 34.0
const GRAB_RANGE := 4.5
const PLAYER_GRAB_RANGE := 6.5
const PUNT_RANGE := 8.0
const PUNT_COS := 0.86
const PUNT_COOLDOWN := 0.45
const BOOST_COOLDOWN := 0.9
const MAX_PULL_MASS := 160.0
const CHARGE_TIME := 1.0 # seconds to full charge
const MAX_HOLD_DISTANCE := 10.0
const CHARGE_BONUS := 0.8 # full charge throws (1 + bonus) times as hard

var player: Player
var selected_slot := 0

# Server state.
var grab_active := false
var held_kind: int = Kind.NONE
var held_id := 0
var _held_time := 0.0
var _stuck_time := 0.0
var _punt_cd := 0.0
var _boost_cd := 0.0
var _regrab_block := 0.0
var _pull_id := 0
var _charging := false
var _charge_start := 0.0
var _vis_charging := false
var _vis_charge_start := 0.0

# Replicated visual state.
var vis_kind: int = Kind.NONE
var vis_id := 0

# Visuals.
var _viewmodel: Node3D
var _vm_muzzle: Node3D
var _vm_claws: Array[Node3D] = []
var _vm_core: MeshInstance3D
## First-person gun placement (camera space) and size.
const VM_POS := Vector3(0.27, -0.3, -0.3)
const VM_SCALE := 0.4
var _world_model: Node3D
var _wm_muzzle: Node3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _arc_mesh: ImmediateMesh
var _arc_light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _arc_offsets: Array = [] # per strand, per point jitter (re-rolled ~20x/s)
var _arc_reroll := 0.0
var _spark_timer := 0.0

# Hold control (server): extra distance and orientation relative to the player's facing.
var hold_extra := 0.0
var hold_rot := Basis.IDENTITY

const ARC_POINTS := 14
var _kick := 0.0
var _sway := Vector2.ZERO
var _last_yaw := 0.0
var _last_pitch := 0.0
var _vm_visible := true


func _ready() -> void:
	_build_world_model()
	# Electric arc: camera-facing ribbons rebuilt every frame (see _draw_arc).
	_arc_mesh = ImmediateMesh.new()
	_beam = MeshInstance3D.new()
	_beam.mesh = _arc_mesh
	_beam_mat = Mats.glow(_beam_color(), 4.0, true).duplicate()
	_beam_mat.vertex_color_use_as_albedo = true
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	_arc_light = OmniLight3D.new()
	_arc_light.light_color = _beam_color()
	_arc_light.omni_range = 4.0
	_arc_light.top_level = true
	_arc_light.visible = false
	add_child(_arc_light)
	_hum = AudioStreamPlayer3D.new()
	_hum.bus = "SFX"
	_hum.unit_size = 4.0
	_hum.volume_db = -14.0
	_hum.top_level = true
	add_child(_hum)


# --- Visual construction ------------------------------------------------------------

## The gun model (tools/make_gravity_gun.py, made in Blender). It points along -Z.
const GUN_SCENE := preload("res://assets/models/gravity_gun.glb")
## Where the grip is in the model, so a hand can hold it.
const GRIP := Vector3(0.0, -0.25, 0.36)


## Adds the gun model under parent, scaled, with the grip at the parent's origin. The orange
## "Accent" parts take the team colour.
func _gun_mesh(parent: Node3D, scale_f: float) -> Node3D:
	var gun := GUN_SCENE.instantiate() as Node3D
	gun.scale = Vector3.ONE * scale_f
	gun.position = -GRIP * scale_f
	parent.add_child(gun)
	var accent := Color(1.0, 0.45, 0.08) if player.team == 0 else Game.team_color(player.team)
	for mi in _all_geometry(gun):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name == "Accent":
				var tinted := mat.duplicate() as StandardMaterial3D
				tinted.albedo_color = accent
				m.set_surface_override_material(i, tinted)
	return gun


func _build_world_model() -> void:
	if player.model == null or player.model.gun_socket == null:
		return
	_world_model = Node3D.new()
	_world_model.rotation.x = -PI * 0.5
	player.model.gun_socket.add_child(_world_model)
	var gun := _gun_mesh(_world_model, 0.5)
	_wm_muzzle = gun.find_child("Muzzle", true, false) as Node3D


func build_viewmodel(camera: Camera3D) -> void:
	# Low on the right and close to the eye: the claws and core show, the back of the gun
	# and the hands holding it run off the bottom of the screen.
	_viewmodel = Node3D.new()
	_viewmodel.position = VM_POS
	camera.add_child(_viewmodel)
	var gun := _gun_mesh(_viewmodel, VM_SCALE)
	gun.rotation = Vector3(0.06, 0.22, -0.08) # turned in toward the crosshair: its side shows
	_vm_muzzle = gun.find_child("Muzzle", true, false) as Node3D
	_vm_core = gun.find_child("Core", true, false) as MeshInstance3D
	for i in 3:
		var pivot := gun.find_child("ClawPivot%d" % i, true, false) as Node3D
		if pivot and pivot.get_child_count() > 0:
			_vm_claws.append(pivot)
	_build_hands(gun)
	for mi in _all_geometry(_viewmodel):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## First-person hands in the player's skin and sleeve colours, holding the gun.
func _build_hands(gun: Node3D) -> void:
	var skin: Color = player.model.skin_color if player.model else Color(1.0, 0.85, 0.7)
	var sleeve: Color = player.color
	# Gun model space (unscaled): grip at GRIP, the drum's underside around z 0..-0.1.
	for h in [[GRIP + Vector3(0.0, -0.02, 0.02), Vector3(0.3, -0.7, 0.65)]]:
		var hand := Node3D.new()
		hand.position = h[0]
		gun.add_child(hand)
		var fist := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.095
		sm.height = 0.19
		fist.mesh = sm
		fist.scale = Vector3(1.0, 1.15, 1.25)
		fist.material_override = Mats.skin(skin)
		hand.add_child(fist)
		var dir: Vector3 = (h[1] as Vector3).normalized()
		var arm := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.07
		cm.height = 0.8
		arm.mesh = cm
		arm.material_override = Mats.plastic(sleeve, 0.45)
		arm.position = dir * 0.42
		arm.basis = Basis(Quaternion(Vector3.UP, dir))
		hand.add_child(arm)


func _all_geometry(n: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for c in n.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		out.append_array(_all_geometry(c))
	return out


func set_viewmodel_visible(v: bool) -> void:
	_vm_visible = v
	if _viewmodel:
		_viewmodel.visible = v
	if _world_model:
		_world_model.visible = not v or not player.is_local_human()


func muzzle_position() -> Vector3:
	if _viewmodel and _viewmodel.visible and _vm_muzzle:
		return _vm_muzzle.global_position
	if _wm_muzzle:
		return _wm_muzzle.global_position
	return player.eye_position()


func held_node() -> Node:
	if vis_kind == Kind.PROP:
		return player.world.get_prop(vis_id)
	if vis_kind == Kind.PLAYER:
		return player.world.get_player(vis_id)
	return null


## All peers: called when the server announces what this gun holds.
func set_visual_state(kind: int, id: int) -> void:
	var old := held_node()
	if old and old is PhysicsBody3D:
		player.remove_collision_exception_with(old)
	vis_kind = kind
	vis_id = id
	var now := held_node()
	if now and now is PhysicsBody3D:
		player.add_collision_exception_with(now)


func kick(amount: float) -> void:
	_kick = maxf(_kick, amount)


func update_visuals(delta: float) -> void:
	var target := held_node()
	if target and is_instance_valid(target) and player.is_alive():
		var from := muzzle_position()
		var to: Vector3 = target.global_position
		if target is Player:
			to = (target as Player).body_center()
		if from.distance_to(to) > 0.05:
			_draw_arc(from, to, delta)
	else:
		_beam.visible = false
		_arc_light.visible = false
		if _hum.playing:
			_hum.stop()
	if _viewmodel:
		_kick = lerpf(_kick, 0.0, 1.0 - exp(-10.0 * delta))
		var dyaw := clampf(wrapf(player.yaw - _last_yaw, -PI, PI), -0.08, 0.08)
		var dpitch := clampf(player.pitch - _last_pitch, -0.08, 0.08)
		_last_yaw = player.yaw
		_last_pitch = player.pitch
		_sway = _sway.lerp(Vector2(dyaw, dpitch) * 2.0, 1.0 - exp(-12.0 * delta))
		var bob := 0.0
		if player.is_on_floor():
			bob = sin(Time.get_ticks_msec() * 0.012) * clampf(player.horizontal_speed() / 10.0, 0.0, 1.0) * 0.012
		var ch := visual_charge()
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004 * ch
		_viewmodel.position = VM_POS + Vector3(_sway.x * 0.1, bob - _sway.y * 0.1, _kick * 0.06 + ch * 0.07) + jitter
		_viewmodel.rotation = Vector3(_kick * 0.5 - ch * 0.12, _sway.x, 0)
		var open := (0.55 + visual_charge() * 0.35) if vis_kind != Kind.NONE else (0.25 if grab_active else 0.0)
		for c in _vm_claws:
			var claw := c.get_child(0) as Node3D
			claw.rotation.x = lerpf(claw.rotation.x, open, 1.0 - exp(-12.0 * delta))
		var pulse := 1.0 + visual_charge() * 0.8 + sin(Time.get_ticks_msec() * (0.02 + visual_charge() * 0.06 if vis_kind != Kind.NONE else 0.005)) * 0.25
		if _vm_core:
			_vm_core.scale = Vector3.ONE * pulse


func _beam_color() -> Color:
	return Color(0.45, 0.95, 1.0) if player.team == 0 else Game.team_color(player.team).lightened(0.3)


## Lightning between muzzle and target: a main bolt plus thin strands and an occasional
## fork, all following a curve that bends toward where the gun points (so the arc whips
## when the object lags behind your aim). Jitter is re-rolled ~20 times a second.
func _draw_arc(from: Vector3, to: Vector3, delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ch := visual_charge()
	var fp := _viewmodel != null and _viewmodel.visible
	var d := from.distance_to(to)
	var aim := player.aim_direction()
	var ctrl := from + aim * d * 0.55
	var strands := 3 + int(ch * 2.0)
	_arc_reroll -= delta
	if _arc_reroll <= 0.0 or _arc_offsets.size() < strands + 1:
		_arc_reroll = 0.05
		_arc_offsets.clear()
		for s in strands + 1:
			var offs := PackedVector3Array()
			for i in ARC_POINTS + 1:
				offs.append(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))
			_arc_offsets.append(offs)
	var col := _beam_color().lerp(Color(1.0, 0.97, 0.9), ch)
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var cam_pos := cam.global_position
	for s in strands:
		var amp := (0.05 + d * 0.02) * (1.0 + ch * 0.7) * (1.0 if s == 0 else 1.6)
		var width := (0.035 if s == 0 else 0.012) * (1.0 + ch) * (0.5 if fp else 1.0)
		var bright := Color(col, 0.95 if s == 0 else 0.55)
		var prev := from
		var offs: PackedVector3Array = _arc_offsets[s]
		for i in range(1, ARC_POINTS + 1):
			var t := float(i) / ARC_POINTS
			var p := from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)
			if i < ARC_POINTS:
				p += offs[i] * amp * sin(PI * t)
			_ribbon(prev, p, width, bright, cam_pos)
			prev = p
	# A short fork off the main bolt now and then.
	var fork_offs: PackedVector3Array = _arc_offsets[strands]
	if fork_offs[0].x > 0.0:
		var t0 := 0.3 + absf(fork_offs[1].x) * 0.4
		var start := from.lerp(ctrl, t0).lerp(ctrl.lerp(to, t0), t0)
		var end := start + fork_offs[2].normalized() * (0.25 + d * 0.08)
		_ribbon(start, start.lerp(end, 0.5) + fork_offs[3] * 0.08, 0.01, Color(col, 0.6), cam_pos)
		_ribbon(start.lerp(end, 0.5) + fork_offs[3] * 0.08, end, 0.008, Color(col, 0.4), cam_pos)
	_arc_mesh.surface_end()
	_beam.global_transform = Transform3D.IDENTITY
	_beam.visible = true
	_beam_mat.emission = col
	_beam_mat.emission_energy_multiplier = 3.0 + ch * 3.0 + randf() * 1.5
	_arc_light.visible = true
	_arc_light.global_position = to
	_arc_light.light_color = col
	_arc_light.light_energy = (1.2 + randf() * 1.0) * (1.0 + ch)
	_hum.global_position = from
	if not _hum.playing:
		_hum.stream = Sfx.stream("arc")
		_hum.play()
	_hum.pitch_scale = 1.0 + ch * 0.6
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = randf_range(0.08, 0.2)
		player.world.fx.spark(to, col)


## One camera-facing quad between two points.
func _ribbon(a: Vector3, b: Vector3, width: float, col: Color, cam_pos: Vector3) -> void:
	var seg := b - a
	var side := seg.cross(cam_pos - a).normalized() * width
	_arc_mesh.surface_set_color(col)
	_arc_mesh.surface_add_vertex(a - side)
	_arc_mesh.surface_add_vertex(a + side)
	_arc_mesh.surface_add_vertex(b + side)
	_arc_mesh.surface_add_vertex(a - side)
	_arc_mesh.surface_add_vertex(b + side)
	_arc_mesh.surface_add_vertex(b - side)


func on_owner_died() -> void:
	if multiplayer.is_server():
		release(false)
	grab_active = false
	_beam.visible = false
	_arc_light.visible = false
	_hum.stop()


# --- Server gameplay ------------------------------------------------------------------

func server_action(action: int, origin: Vector3, dir: Vector3) -> void:
	if not player.is_alive():
		return
	dir = dir.normalized()
	match action:
		Action.GRAB_START:
			grab_active = true
			if held_kind == Kind.NONE:
				_try_grab(origin, dir)
		Action.GRAB_END:
			grab_active = false
			_pull_id = 0
			release(false)
		Action.THROW:
			if held_kind != Kind.NONE:
				_charging = true
				_charge_start = Time.get_ticks_msec() / 1000.0
				player.world.server_gun_charge(self, true)
			else:
				_punt(origin, dir)
		Action.THROW_RELEASE:
			if _charging and held_kind != Kind.NONE:
				_throw(dir, charge_level())
			_cancel_charge()
		Action.FREEZE:
			_freeze_held()


func server_tick(delta: float) -> void:
	_punt_cd = maxf(_punt_cd - delta, 0.0)
	_boost_cd = maxf(_boost_cd - delta, 0.0)
	_regrab_block = maxf(_regrab_block - delta, 0.0)
	if not player.is_alive():
		if held_kind != Kind.NONE:
			release(false)
		return
	var origin := player.eye_position()
	var dir := player.aim_direction()
	if grab_active and held_kind == Kind.NONE and _regrab_block <= 0.0:
		# Whatever we are already pulling gets caught once it is close, wherever we aim.
		var pulled := player.world.get_prop(_pull_id) as Prop
		if pulled and pulled.held_by == 0 and origin.distance_to(pulled.global_position) <= GRAB_RANGE + pulled.size.length() * 0.5:
			_grab_prop(pulled)
		elif pulled and pulled.held_by == 0 and origin.distance_to(pulled.global_position) < PULL_RANGE * 1.2 and _has_los(origin, pulled):
			_pull(pulled, origin) # tractor lock: keeps coming even if the aim drifts
		else:
			_pull_id = 0
			_try_grab(origin, dir)
	match held_kind:
		Kind.PROP:
			_hold_prop(delta, origin, dir)
		Kind.PLAYER:
			_hold_player(delta, origin, dir)


func _try_grab(origin: Vector3, dir: Vector3) -> void:
	var w := player.world
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * PULL_RANGE, Game.L_WORLD | Game.L_PLAYERS | Game.L_PROPS, [player.get_rid()])
	var hit := space.intersect_ray(q)
	var target: Node = hit.get("collider") if not hit.is_empty() else null
	if not (target is Prop or target is Player):
		target = _catch_assist(origin, dir)
	if target is Prop:
		var p := target as Prop
		var d := origin.distance_to(p.global_position)
		if d <= GRAB_RANGE + p.size.length() * 0.5:
			_grab_prop(p)
		elif p.mass <= MAX_PULL_MASS:
			if p.freeze:
				if not p.frozen_by_player:
					return
				w.server_unfreeze_prop(p)
			_pull(p, origin)
	elif target is Player:
		var pl := target as Player
		if pl != player and pl.is_alive() and origin.distance_to(pl.body_center()) <= PLAYER_GRAB_RANGE:
			if pl.gun.held_kind == Kind.PLAYER and pl.gun.held_id == player.player_id:
				return # no mutual holding loops
			held_kind = Kind.PLAYER
			held_id = pl.player_id
			hold_extra = 0.0
			_held_time = 0.0
			w.server_set_last_attacker(pl, player.player_id)
			w.server_gun_state_changed(self)
			Sfx.play3d("zap", pl.global_position, -2.0, 0.8)


func _pull(p: Prop, origin: Vector3) -> void:
	var to_me := origin - p.global_position
	var d := to_me.length()
	# Ease in so the object arrives at the hold point instead of overshooting.
	var pull := minf(clampf(2200.0 / p.mass, 6.0, 28.0), d * 4.0)
	p.linear_velocity = p.linear_velocity.lerp(to_me / d * pull + Vector3.UP * 1.2, 0.25)
	p.sleeping = false
	_pull_id = p.prop_id


func _has_los(origin: Vector3, n: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(origin, n.global_position, Game.L_WORLD, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Sphere search in front of the player so catching fast objects is forgiving.
func _catch_assist(origin: Vector3, dir: Vector3) -> Node:
	var space := player.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, origin + dir * 2.8)
	params.collision_mask = Game.L_PROPS | Game.L_PLAYERS
	params.exclude = [player.get_rid()]
	var best: Node = null
	var best_score := -1.0
	for r in space.intersect_shape(params, 16):
		var n: Node = r.collider
		if not (n is Prop or n is Player):
			continue
		var pos: Vector3 = (n as Node3D).global_position
		var s := dir.dot((pos - origin).normalized())
		if s > 0.6 and s > best_score:
			best_score = s
			best = n
	return best


func _grab_prop(p: Prop) -> void:
	var w := player.world
	if p.held_by != 0 and p.held_by != player.player_id:
		var other := w.get_player(p.held_by) as Player
		if other:
			other.gun.release(false)
	if p.freeze:
		w.server_unfreeze_prop(p)
	held_kind = Kind.PROP
	held_id = p.prop_id
	hold_extra = 0.0
	# Keep the object's current orientation, relative to where the player faces.
	hold_rot = Basis(Vector3.UP, -player.yaw) * p.global_transform.basis.orthonormalized()
	_held_time = 0.0
	_stuck_time = 0.0
	p.held_by = player.player_id
	p.gravity_scale = 0.0
	p.sleeping = false
	w.server_prop_caught(p, player)
	w.server_gun_state_changed(self)
	w.server_fx("zap", p.global_position, Vector3.UP, 0.5)


func _hold_distance(p: Prop) -> float:
	return 1.6 + maxf(p.size.x, maxf(p.size.y, p.size.z)) * 0.7


func _hold_prop(delta: float, origin: Vector3, dir: Vector3) -> void:
	var p := player.world.get_prop(held_id) as Prop
	if p == null or not is_instance_valid(p):
		release(false)
		return
	var c := charge_level()
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.08 * c
	var dist := clampf(_hold_distance(p) + hold_extra, 1.0 + p.size.length() * 0.4, MAX_HOLD_DISTANCE)
	var target := origin + dir * dist * (1.0 - 0.3 * c) + shake
	var to := target - p.global_position
	var desired := to * 16.0 + player.velocity
	var grip := clampf(80.0 / p.mass, 0.12, 1.0)
	p.linear_velocity = p.linear_velocity.lerp(desired, 0.12 + 0.3 * grip)
	# Steer orientation toward hold_rot (relative to the player's facing).
	var want := (Basis(Vector3.UP, player.yaw) * hold_rot).get_rotation_quaternion()
	var cur := p.global_transform.basis.get_rotation_quaternion()
	var q := want * cur.inverse()
	if q.w < 0.0:
		q = -q
	var angle := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var ang_target := Vector3.ZERO
	if angle > 0.001:
		ang_target = Vector3(q.x, q.y, q.z).normalized() * minf(angle * 10.0, 20.0)
	p.angular_velocity = p.angular_velocity.lerp(ang_target, 0.1 + 0.3 * grip)
	p.sleeping = false
	if to.length() > 4.0:
		_stuck_time += delta
		if _stuck_time > 0.6:
			release(false)
	else:
		_stuck_time = 0.0


func _hold_player(delta: float, origin: Vector3, dir: Vector3) -> void:
	var w := player.world
	var pl := w.get_player(held_id) as Player
	if pl == null or not pl.is_alive():
		release(false)
		return
	_held_time += delta
	if _held_time > w.hold_time_limit(player, pl):
		release(true)
		return
	var c := charge_level()
	var target := origin + dir * clampf(2.8 + hold_extra, 1.8, MAX_HOLD_DISTANCE) * (1.0 - 0.25 * c) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.08 * c
	w.server_send_held(pl, target, player.velocity, player.player_id)


## Server: push/pull (meters) and rotate (radians, in the player's facing frame) what we hold.
func server_adjust(dist_delta: float, yaw_delta: float, pitch_delta: float) -> void:
	if held_kind == Kind.NONE:
		return
	hold_extra = clampf(hold_extra + dist_delta, -3.0, MAX_HOLD_DISTANCE)
	if held_kind == Kind.PROP and (yaw_delta != 0.0 or pitch_delta != 0.0):
		hold_rot = (Basis(Vector3.UP, yaw_delta) * Basis(Vector3.RIGHT, pitch_delta) * hold_rot).orthonormalized()


## 0..1 server-side charge of the current wind-up.
func charge_level() -> float:
	if not _charging:
		return 0.0
	return clampf((Time.get_ticks_msec() / 1000.0 - _charge_start) / CHARGE_TIME, 0.0, 1.0)


## 0..1 charge as seen by every peer (for visuals).
func visual_charge() -> float:
	if not _vis_charging:
		return 0.0
	return clampf((Time.get_ticks_msec() / 1000.0 - _vis_charge_start) / CHARGE_TIME, 0.0, 1.0)


func set_charge_visual(on: bool) -> void:
	_vis_charging = on
	_vis_charge_start = Time.get_ticks_msec() / 1000.0
	if on:
		Sfx.play3d("charge", player.eye_position(), -4.0)


func _cancel_charge() -> void:
	if _charging:
		_charging = false
		player.world.server_gun_charge(self, false)


func release(throw_ragdoll: bool) -> void:
	_cancel_charge()
	var w := player.world
	match held_kind:
		Kind.PROP:
			var p := w.get_prop(held_id) as Prop
			if p and is_instance_valid(p):
				p.held_by = 0
				p.gravity_scale = 1.0
		Kind.PLAYER:
			var pl := w.get_player(held_id) as Player
			if pl:
				w.server_release_held(pl, 0.6 if throw_ragdoll else 0.0)
	if held_kind != Kind.NONE:
		held_kind = Kind.NONE
		held_id = 0
		w.server_gun_state_changed(self)


func _throw(dir: Vector3, charge := 0.0) -> void:
	var w := player.world
	var power := 1.0 + CHARGE_BONUS * charge
	var now := Time.get_ticks_msec() / 1000.0
	_regrab_block = 0.5
	match held_kind:
		Kind.PROP:
			var p := w.get_prop(held_id) as Prop
			release(false)
			if p:
				var speed := clampf(48.0 / pow(p.mass / 8.0, 0.33), 9.0, 48.0) * power
				p.linear_velocity = dir * speed + player.velocity
				p.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
				p.last_thrower = player.player_id
				p.last_thrown_time = now
				p.live = true
				w.server_fx("throw", p.global_position, dir, power)
		Kind.PLAYER:
			var pl := w.get_player(held_id) as Player
			held_kind = Kind.NONE
			held_id = 0
			w.server_gun_state_changed(self)
			if pl:
				var vel := dir * 30.0 * power + player.velocity + Vector3.UP * 3.0
				w.server_launch_player(pl, vel, true, 1.6, player.player_id)
				w.server_fx("throw", pl.body_center(), dir, 1.5 * power)
	w.server_gun_kick(player, power)


func _punt(origin: Vector3, dir: Vector3) -> void:
	if _punt_cd > 0.0:
		return
	_punt_cd = PUNT_COOLDOWN
	var w := player.world
	var now := Time.get_ticks_msec() / 1000.0
	var space := player.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PUNT_RANGE
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = Game.L_PROPS | Game.L_PLAYERS
	params.exclude = [player.get_rid()]
	var affected := 0
	for r in space.intersect_shape(params, 32):
		var n: Node = r.collider
		if not (n is Prop or n is Player):
			continue
		var center: Vector3 = (n as Player).body_center() if n is Player else (n as Node3D).global_position
		var to := center - origin
		var d := to.length()
		if d > PUNT_RANGE or (d > 1.5 and dir.dot(to / d) < PUNT_COS):
			continue
		var los := PhysicsRayQueryParameters3D.create(origin, center, Game.L_WORLD, [player.get_rid()])
		if not space.intersect_ray(los).is_empty():
			continue
		var falloff := 1.0 - (d / PUNT_RANGE) * 0.5
		if n is Prop:
			var p := n as Prop
			if p.freeze and not p.frozen_by_player:
				continue
			if p.freeze:
				w.server_unfreeze_prop(p)
			var dv := minf(1600.0 / p.mass, 36.0) * falloff
			p.linear_velocity += dir * dv + Vector3.UP * 2.0 + player.velocity * 0.5
			p.angular_velocity += Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
			p.last_thrower = player.player_id
			p.last_thrown_time = now
			p.live = true
			p.sleeping = false
			affected += 1
		else:
			var pl := n as Player
			if pl.is_alive():
				w.server_launch_player(pl, dir * 17.0 * falloff + Vector3.UP * 5.0, false, 0.9, player.player_id)
				affected += 1
	# Chip at breakable walls directly ahead.
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 4.5, Game.L_WORLD, [player.get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col: Node = hit.collider
		if col.has_meta("destructible"):
			w.server_damage_destructible(col.get_meta("destructible"), hit.position, 0.8, 45.0, dir * 10.0, player.player_id, 2.0)
			affected += 1
		elif affected == 0 and _boost_cd <= 0.0 and origin.distance_to(hit.position) < 3.5:
			# Gravity jump: push yourself off the surface.
			_boost_cd = BOOST_COOLDOWN
			w.server_launch_player(player, -dir * 15.0, false, 0.0, 0)
	w.server_fx("punt", origin + dir * 1.5, dir, 1.0)
	w.server_gun_kick(player, 0.7)


func _freeze_held() -> void:
	if held_kind != Kind.PROP or not player.world.allow_freeze():
		return
	var p := player.world.get_prop(held_id) as Prop
	release(false)
	if p and p.kind != "flag":
		player.world.server_freeze_prop(p)
