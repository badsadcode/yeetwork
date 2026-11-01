@tool
class_name Fixture
extends PuzzleNode
## Set dressing that does something: a model (yours, the map theme's fixture_<kind>, or a
## built-in placeholder) that can hum, buzz or crackle, spin a part, shake, sway, puff steam
## or smoke, spark, drip, glow, hurt whoever touches it (hot, electric), shake the camera
## nearby, break when hit hard (sparks, silence, smoke; it comes back), and switch on and
## off with puzzle wiring (it winds up and down). Everything is optional.
## - Kind: a built-in placeholder look and its usual behaviour ("auto" settings below follow
##   it): generator, engine, fan, pump, pipes, radio, or box (a plain block).
## - Your model: parts named "Spin" (turns), "Emitter" (where steam, smoke... come from) and
##   "Light" (where its glow is) are used if they're there.
## - Inputs: on while its inputs are on ("power restored: the machines start up"); without
##   inputs it's always on.

const KINDS := ["box", "generator", "engine", "fan", "pump", "pipes", "radio"]
## What "auto" means per kind: [sound, spin turns/s, effect, vibrate m, light energy, shake].
const AUTO := {
	"box": ["none", 0.0, "none", 0.0, 0.0, 0.0],
	"generator": ["hum", 0.0, "smoke", 0.004, 0.6, 0.0],
	"engine": ["engine", 1.5, "none", 0.006, 0.0, 0.12],
	"fan": ["fan", 3.0, "none", 0.002, 0.0, 0.0],
	"pump": ["hum", 0.0, "drips", 0.01, 0.0, 0.0],
	"pipes": ["steam", 0.3, "steam", 0.0, 0.0, 0.0],
	"radio": ["radio", 0.0, "none", 0.0, 0.5, 0.0],
}

## The built-in look and its usual behaviour (what "auto" and -1 below mean): generator,
## engine, fan, pump, pipes, radio, or box (a plain block).
@export_enum("box", "generator", "engine", "fan", "pump", "pipes", "radio") var kind := "generator":
	set(v):
		kind = v
		_rebuild()
## Your own model (a scene: an imported .glb...), instead of the built-in look and the theme's.
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()
## Players bump into it (a box round its look); off for things to walk through or past.
@export var solid := true

@export_group("Sound")
## A looping sound: auto (the kind's), none, or one of the game's ambient loops (a recording
## in assets/sounds/ named after it replaces it).
@export_enum("auto", "none", "hum", "buzz", "engine", "fan", "steam", "radio") var sound := "auto"
## Your own looping sound instead (an .ogg or .wav: set it to loop in its import settings).
@export var custom_sound: AudioStream
## How loud, decibels (0: as recorded; -6 about half).
@export_range(-30.0, 12.0, 0.5) var volume_db := 0.0
## How far it carries (metres).
@export_range(2.0, 80.0, 0.5) var reach := 14.0
## Higher (above 1) or lower.
@export_range(0.3, 3.0, 0.05) var pitch := 1.0
## Now and then a one-off sound too: game sound names ("metal", "creak", "zap", "sizzle"...) or
## your own recordings, every few seconds (random within One Shot Every).
@export var one_shot_sounds: Array[String] = []
## Your own recordings for the one-off sounds.
@export var one_shot_recordings: Array[AudioStream] = []
## Seconds between one-off sounds: at random between x and y.
@export var one_shot_every := Vector2(4.0, 10.0)

@export_group("Motion")
## Turns per second of the part named "Spin" (-1: the kind's).
@export_range(-1.0, 20.0, 0.05) var spin_speed := -1.0
## The axis the "Spin" part turns about (its own).
@export var spin_axis := Vector3(0, 0, 1)
## Shaking, metres (-1: the kind's).
@export_range(-1.0, 0.1, 0.001) var vibrate := -1.0
## Swinging to and fro, degrees, and how fast (a hanging sign, a buoy).
@export_range(0.0, 45.0, 0.5) var sway := 0.0
## Swings per second.
@export_range(0.05, 4.0, 0.05) var sway_speed := 0.5

@export_group("Effect")
## From the part named "Emitter" (or its top): auto, none, steam, smoke, sparks, drips.
@export_enum("auto", "none", "steam", "smoke", "sparks", "drips") var effect := "auto"
## How much of the effect: 1 the usual, 2 twice as much.
@export_range(0.1, 4.0, 0.05) var effect_rate := 1.0

@export_group("Light")
## Its glow's colour.
@export var light_color := Color(0.5, 1.0, 0.6)
## A glow from the part named "Light" (-1: the kind's; 0: none).
@export_range(-1.0, 8.0, 0.05) var light_energy := -1.0
## Pulses per second (0: steady).
@export_range(0.0, 10.0, 0.05) var light_pulse := 0.0

@export_group("Breaking")
## Breaks when something hits it hard (a flying prop, a blast, a push, lightning): sparks, it
## falls silent and smokes; back after Repair Time seconds (0: until a PuzzleReset over it).
@export var breakable := false
## Seconds until it's mended after breaking (0: until a PuzzleReset over it).
@export_range(0.0, 600.0, 1.0) var repair_time := 40.0

@export_group("Touch")
## Hurts whoever comes within Hazard Radius (of its Emitter, or its middle) while it runs:
## hot (burns, sets alight) or electric (a zap and a jolt).
@export_enum("none", "hot", "electric") var hazard := "none"
## How close is too close, metres.
@export_range(0.3, 6.0, 0.1) var hazard_radius := 1.2
## Shakes the camera of anyone nearby while it runs (-1: the kind's).
@export_range(-1.0, 1.0, 0.01) var shake := -1.0

var broken := false
var _parts: Node3D
var _look: Node3D
var _spin: Node3D
var _emitter: Node3D
var _glow_at: Node3D
var _audio: AudioStreamPlayer3D
var _fx: CPUParticles3D
var _light: OmniLight3D
var _body: StaticBody3D
var _level := 0.0 # 0 off .. 1 running (it winds up and down)
var _t := 0.0
var _next_shot := 3.0
var _hazard_cd := 0.0
var _shake_cd := 0.0
var _smoke_left := 0.0 # (broken: smoke for a while)
var _rest := Transform3D.IDENTITY


func _ready() -> void:
	if inputs.is_empty():
		active = true # always on: no waiting for the server's first check
	_rebuild()


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func _auto(i: int):
	return (AUTO.get(kind, AUTO.box) as Array)[i]


func _sound_name() -> String:
	return str(_auto(0)) if sound == "auto" else sound


# --- Look ----------------------------------------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_look = Node3D.new()
	_look.name = "Look"
	_parts.add_child(_look)
	_build_kind()
	var theirs := Looks.apply(_look, MapTheme.pick(self, "fixture_" + kind, model))
	_spin = Looks.part(theirs, "Spin") if theirs else _look.find_child("Spin", true, false) as Node3D
	_emitter = Looks.part(theirs, "Emitter") if theirs else _look.find_child("Emitter", true, false) as Node3D
	_glow_at = Looks.part(theirs, "Light") if theirs else _look.find_child("Light", true, false) as Node3D
	_rest = _look.transform
	if solid:
		_add_body()
	if Engine.is_editor_hint():
		return
	_add_runtime()


## The built-in placeholder looks (simple shapes), each with its Spin, Emitter and Light parts.
func _build_kind() -> void:
	var dark := Mats.plastic(Color(0.22, 0.24, 0.27), 0.5)
	var paint := Mats.plastic(Color(0.28, 0.45, 0.32), 0.45)
	var steel := Mats.plastic(Color(0.55, 0.57, 0.6), 0.3)
	var red := Mats.plastic(Color(0.75, 0.15, 0.1), 0.4)
	match kind:
		"box":
			_box(Vector3(1, 1, 1), Vector3(0, 0.5, 0), dark)
		"generator":
			_box(Vector3(1.6, 1.0, 0.9), Vector3(0, 0.55, 0), paint)
			_box(Vector3(1.7, 0.1, 1.0), Vector3(0, 0.05, 0), dark)
			_cyl(0.08, 0.6, Vector3(0.55, 1.35, 0.2), steel)
			_marker("Emitter", Vector3(0.55, 1.68, 0.2))
			_box(Vector3(0.3, 0.2, 0.02), Vector3(-0.4, 0.75, 0.46), dark)
			_marker("Light", Vector3(-0.4, 0.75, 0.5))
		"engine":
			_box(Vector3(2.8, 1.3, 1.4), Vector3(0, 0.75, 0), dark)
			for i in 4:
				_cyl(0.22, 0.5, Vector3(-0.9 + i * 0.6, 1.6, 0), steel)
			_box(Vector3(3.0, 0.15, 1.6), Vector3(0, 0.08, 0), dark)
			var wheel := _marker("Spin", Vector3(1.55, 0.8, 0))
			wheel.rotation.y = PI * 0.5 # (its Z along the engine: it turns about the crankshaft)
			var w := _cyl(0.55, 0.15, Vector3.ZERO, red)
			w.rotation.x = PI * 0.5
			w.reparent(wheel, false)
			_box(Vector3(0.12, 1.0, 0.12), Vector3.ZERO, steel).reparent(wheel, false) # (a spoke: it shows turning)
		"fan":
			_box(Vector3(1.4, 1.4, 0.15), Vector3(0, 0.75, -0.25), dark)
			_box(Vector3(0.2, 0.8, 0.2), Vector3(0, 0.4, -0.25), steel)
			var hub := _marker("Spin", Vector3(0, 0.75, -0.12))
			for i in 4:
				var blade := _box(Vector3(0.18, 0.6, 0.04), Vector3(0, 0.32, 0), steel)
				var arm := Node3D.new()
				arm.rotation.z = i * PI * 0.5
				hub.add_child(arm)
				blade.reparent(arm, false)
		"pump":
			_box(Vector3(1.0, 0.5, 1.0), Vector3(0, 0.25, 0), paint)
			_cyl(0.3, 1.0, Vector3(0, 1.0, 0), steel)
			_cyl(0.08, 0.6, Vector3(0.4, 0.3, 0), steel).rotation.z = PI * 0.5
			_marker("Emitter", Vector3(0.75, 0.3, 0))
		"pipes":
			for z in [-0.3, 0.3]:
				_cyl(0.14, 2.4, Vector3(0, 1.2, z), steel)
			_cyl(0.14, 0.6, Vector3(0, 1.5, 0), steel).rotation.x = PI * 0.5
			var valve := _marker("Spin", Vector3(0, 1.5, 0.0))
			var ring := _cyl(0.25, 0.06, Vector3.ZERO, red)
			ring.rotation.x = PI * 0.5
			ring.reparent(valve, false)
			_marker("Emitter", Vector3(0.0, 1.8, 0.3))
		"radio":
			_box(Vector3(0.5, 0.3, 0.22), Vector3(0, 0.15, 0), Mats.plastic(Color(0.45, 0.32, 0.2), 0.6))
			_box(Vector3(0.02, 0.6, 0.02), Vector3(0.2, 0.6, 0), steel)
			_marker("Light", Vector3(-0.12, 0.18, 0.12))


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	_look.add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	_look.add_child(mi)
	return mi


func _marker(n: String, pos: Vector3) -> Node3D:
	var m := Node3D.new()
	m.name = n
	m.position = pos
	_look.add_child(m)
	return m


## A box round the look (the bounds of its visible meshes) that players bump into.
func _add_body() -> void:
	var box := AABB()
	var first := true
	var inv := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	for mi: MeshInstance3D in _parts.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		var bb: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if first:
		return
	_body = StaticBody3D.new()
	_body.collision_layer = Game.L_WORLD
	_body.set_meta("fixture", self) # (World: a prop flung at it breaks it)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position = box.get_center()
	_body.add_child(cs)
	_parts.add_child(_body)


# --- Running --------------------------------------------------------------------------------

func _add_runtime() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "SFX"
	_audio.unit_size = reach * 0.25
	_audio.max_distance = reach
	_audio.volume_db = -80.0
	_parts.add_child(_audio)
	_set_stream()
	var e: String = str(_auto(2)) if effect == "auto" else effect
	if e != "none":
		_fx = _make_fx(e)
		(_emitter if _emitter else _parts).add_child(_fx)
		if _emitter == null:
			_fx.position = Vector3(0, 1.2, 0)
	var energy: float = float(_auto(4)) if light_energy < 0.0 else light_energy
	if energy > 0.0:
		_light = OmniLight3D.new()
		_light.light_color = light_color
		_light.omni_range = 3.0
		_light.light_energy = 0.0
		(_glow_at if _glow_at else _parts).add_child(_light)
		if _glow_at == null:
			_light.position = Vector3(0, 0.6, 0)
		_light.set_meta("energy", energy)


func _set_stream() -> void:
	if custom_sound:
		_audio.stream = custom_sound
	else:
		var s := _sound_name()
		_audio.stream = Sfx.stream(s) if s != "none" else null # (null a moment after startup: retried)


func _make_fx(e: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3.UP
	var g := Gradient.new()
	match e:
		"steam", "smoke":
			var steam := e == "steam"
			p.amount = 16
			p.lifetime = 1.6 if steam else 3.0
			p.spread = 12.0
			p.initial_velocity_min = 1.5 if steam else 0.4
			p.initial_velocity_max = 2.6 if steam else 0.9
			p.gravity = Vector3(0, 0.4, 0)
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.8
			var sc := Curve.new()
			sc.add_point(Vector2(0, 0.4))
			sc.add_point(Vector2(1, 1.6))
			p.scale_amount_curve = sc
			var c := Color(0.95, 0.96, 1.0) if steam else Color(0.25, 0.24, 0.24)
			g.set_color(0, Color(c, 0.55))
			g.set_color(1, Color(c, 0.0))
			p.mesh = QuadMesh.new()
			p.angle_min = -180.0
			p.angle_max = 180.0
			p.set_meta("puff", true) # (the game's smoke look: once World's there, _process)
		"sparks", "drips":
			var sparks := e == "sparks"
			p.amount = 14 if sparks else 6
			p.lifetime = 0.6 if sparks else 1.2
			p.spread = 70.0 if sparks else 5.0
			p.direction = Vector3.UP if sparks else Vector3.DOWN
			p.initial_velocity_min = 2.0 if sparks else 0.0
			p.initial_velocity_max = 4.5 if sparks else 0.2
			p.gravity = Vector3(0, -9.8, 0)
			var sm := SphereMesh.new()
			sm.radius = 0.02 if sparks else 0.035
			sm.height = sm.radius * 2.0
			sm.radial_segments = 6
			sm.rings = 3
			p.mesh = sm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if sparks else BaseMaterial3D.SHADING_MODE_PER_PIXEL
			m.vertex_color_use_as_albedo = true
			if sparks:
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.albedo_color = Color(2.0, 1.5, 0.8)
			p.material_override = m
			var c := Color(1.0, 0.8, 0.3) if sparks else Color(0.4, 0.6, 0.75)
			g.set_color(0, c)
			g.set_color(1, Color(c, 0.0 if sparks else 0.6))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_meta("rate", effect_rate)
	p.speed_scale = effect_rate
	return p


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _parts == null:
		return
	_t += delta
	var target := 1.0 if active and not broken else 0.0
	_level = move_toward(_level, target, delta * (0.6 if target > _level else 0.9))
	# Sound: fades and drops in pitch as it winds down.
	if _audio:
		if _audio.stream == null and _sound_name() != "none" and int(_t * 2.0) % 2 == 0:
			_set_stream()
		if _audio.stream and _level > 0.01:
			_audio.volume_db = volume_db + linear_to_db(_level)
			_audio.pitch_scale = pitch * lerpf(0.55, 1.0, _level)
			if not _audio.playing:
				_audio.play(randf() * 1.5)
		elif _audio.playing:
			_audio.stop()
	# Motion.
	var spin: float = float(_auto(1)) if spin_speed < 0.0 else spin_speed
	if _spin and spin > 0.0 and _level > 0.0:
		_spin.rotate_object_local(spin_axis.normalized(), TAU * spin * _level * delta)
	var vib: float = float(_auto(3)) if vibrate < 0.0 else vibrate
	var xf := _rest
	if vib > 0.0 and _level > 0.0:
		xf.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * vib * _level
	if sway > 0.0:
		xf.basis = xf.basis.rotated(Vector3(0, 0, 1), deg_to_rad(sway) * sin(_t * TAU * sway_speed))
	_look.transform = xf
	# Effects while it runs.
	if _fx:
		if _fx.material_override == null and _fx.has_meta("puff") and world:
			_fx.material_override = world.fx._puff_material(0.0)
		_fx.emitting = _level > 0.5
	if _light:
		var k := 1.0 if light_pulse <= 0.0 else 0.6 + 0.4 * sin(_t * TAU * light_pulse)
		_light.light_energy = float(_light.get_meta("energy")) * _level * k
	# One-off sounds now and then.
	if _level > 0.5 and (not one_shot_sounds.is_empty() or not one_shot_recordings.is_empty()):
		_next_shot -= delta
		if _next_shot <= 0.0:
			_next_shot = randf_range(one_shot_every.x, maxf(one_shot_every.y, one_shot_every.x))
			var pick := randi() % (one_shot_sounds.size() + one_shot_recordings.size())
			if pick < one_shot_sounds.size():
				Sfx.play3d(one_shot_sounds[pick], glow_position(), volume_db - 4.0, randf_range(0.9, 1.1))
			else:
				_one_shot(one_shot_recordings[pick - one_shot_sounds.size()])
	# Camera shake for whoever stands near a big running machine.
	var sh: float = float(_auto(5)) if shake < 0.0 else shake
	if sh > 0.0 and _level > 0.5 and world and world.local_player:
		_shake_cd -= delta
		if _shake_cd <= 0.0:
			_shake_cd = 0.25
			var d: float = world.local_player.global_position.distance_to(glow_position())
			if d < reach * 0.4:
				world.local_player.shake(sh * _level * (1.0 - d / (reach * 0.4)) * 0.4)
	# Broken: it smokes a while.
	if _smoke_left > 0.0 and world:
		_smoke_left -= delta
		if fmod(_t, 0.35) < delta:
			world.fx.puffs(glow_position() + Vector3.UP * 0.3, Vector3.UP, 2, [Color(0.22, 0.22, 0.22, 0.6), Color(0.35, 0.35, 0.37, 0.0)], 0.3, 0.6, 0.6, 1.2, 2.5)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or hazard == "none" or world == null or not multiplayer.is_server() or _level < 0.5:
		return
	_hazard_cd -= delta
	if _hazard_cd > 0.0:
		return
	_hazard_cd = 0.5
	var at := _emitter.global_position if _emitter else glow_position() # (a steam leak scalds where it leaks)
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var d := pl.body_center().distance_to(at)
		if d > hazard_radius + 0.4:
			continue
		if hazard == "hot":
			world.server_damage_player(pl, 6.0, 0, "fire", pl.body_center(), Vector3.UP)
			world.server_ignite_player(pl, 2.0)
		else:
			var away := pl.body_center() - at
			away.y = 0.0
			world.server_damage_player(pl, 12.0, 0, "zap", pl.body_center(), away)
			if pl.is_alive():
				world.server_launch_player(pl, away.normalized() * 6.0 + Vector3.UP * 4.0, false, 0.6, 0)
			world.server_fx("zap", at, Vector3.UP, 1.0)


func _one_shot(stream: AudioStream) -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = stream
	p.unit_size = reach * 0.25
	p.max_distance = reach
	p.volume_db = volume_db
	_parts.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --- Breaking (World: like the map lights) --------------------------------------------------

## How far from its middle it can be hit (about its size).
func hit_size() -> float:
	if _body and _body.get_child_count() > 0:
		var b: Vector3 = ((_body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
		return maxf(b.x, maxf(b.y, b.z)) * 0.5
	return 0.5


## Where it's hit (its middle).
func glow_position() -> Vector3:
	if _body and _body.get_child_count() > 0:
		return (_body.get_child(0) as Node3D).global_position
	return global_position + global_transform.basis.y * 0.6


## Broken (sparks, it falls silent, smokes) or mended (it starts up again). Every peer.
func set_broken(on: bool, fx := true) -> void:
	if on == broken:
		return
	broken = on
	var w = world if world else null
	if not fx or not is_inside_tree() or w == null:
		return
	var at := glow_position()
	_smoke_left = 10.0 if on else 0.0
	if on:
		w.fx.zap(at)
		w.fx.impact(at, Vector3.UP, 1.0, "metal", 1.0)
		w.fx.puffs(at, Vector3.UP, 10, [Color(0.3, 0.3, 0.3, 0.7), Color(0.4, 0.4, 0.42, 0.0)], 0.25, 0.6, 0.6, 1.4, 2.5)
		Sfx.play3d("metal", at, 2.0, 0.7)
		Sfx.play3d("zap", at, 0.0, 0.8)
	else:
		Sfx.play3d("zap", at, -8.0, 1.3)
