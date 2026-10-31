class_name Burning
extends Node3D
## Fire on something (visual and audio only, on every peer; World decides what burns).
## Stylized, glowing fire: one big soft flame wrapping the thing and rising into a curling
## tip (flame_body.gdshader: one metaball mass, see-through in the middle, droplets
## pinching off its top), a glowing shell over the thing's meshes (fire_shell.gdshader as
## their material_overlay), smoke, a flickering light and the crackle of fire. Colours come from a palette: orange
## fire, blue or green magic fire. Burning.area() makes a burning place instead (one mass of
## flame over a box footprint, no shell).
##   Burning.on(prop, 8.0)      sets something alight (or keeps it burning longer)
##   Burning.off(prop)          puts it out (fades)

const SHELL := preload("res://scripts/fx/fire_shell.gdshader")
const OUTLINE := preload("res://scripts/fx/fire_outline.gdshader") # (Options: Flame outline)
const BODY := preload("res://scripts/fx/flame_body.gdshader")
## Palettes: [edge, mid, hot] colours.
const PALETTES := {
	"orange": [Color(1.0, 0.3, 0.04), Color(1.0, 0.6, 0.12), Color(1.0, 0.93, 0.58)],
	"blue": [Color(0.05, 0.25, 1.0), Color(0.2, 0.6, 1.0), Color(0.8, 0.95, 1.0)],
	"green": [Color(0.12, 0.65, 0.04), Color(0.45, 1.0, 0.2), Color(0.9, 1.0, 0.7)],
	"gold": [Color(1.0, 0.45, 0.05), Color(1.0, 0.75, 0.2), Color(1.0, 0.97, 0.65)],
	"violet": [Color(0.4, 0.14, 1.0), Color(0.65, 0.35, 1.0), Color(0.88, 0.7, 1.0)],
}


var box := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE) # what burns, in the parent's space
var is_area := false
var palette := "orange"
## How round the burning thing's outline is (0 box .. 1 ball): the flames hug it.
var roundness := 0.35
var _left := 0.0
var _fade := 0.0
var _out := false
var _shell: ShaderMaterial
var _overlaid: Array[MeshInstance3D] = []
var _bodies: Array[ShaderMaterial] = []
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _t := 0.0
var _gone := 0.0 # time since the flames died (the last smoke drifts off)


## Sets target on fire for `seconds` (0 = until put out). `p_box`: the burning volume in
## the target's space (default: the bounds of its meshes).
static func on(target: Node3D, seconds := 0.0, p_box := AABB(), p_palette := "orange") -> Burning:
	var b := target.get_node_or_null("Burning") as Burning
	if b:
		# Already burning (or dying down): flare up again.
		b._left = 0.0 if seconds <= 0.0 else (seconds if b._out else maxf(b._left, seconds))
		if b._out:
			b._out = false
			b._gone = 0.0
			b._set_emitting(true)
			b._apply_shell()
		return b
	b = Burning.new()
	b.name = "Burning"
	b._left = seconds
	b.palette = p_palette
	b.box = p_box if p_box.size != Vector3.ZERO else _bounds(target)
	if target is Prop:
		var shape: String = Prop.DEFS.get((target as Prop).kind, {}).get("shape", "box")
		b.roundness = {"sphere": 1.0, "cyl": 0.55, "pumpkin": 0.85, "couch": 0.25, "box": 0.15}.get(shape, 0.35)
	else:
		b.roundness = 0.6 # players: a rounded body
	target.add_child(b)
	return b


static func off(target: Node) -> void:
	var b := target.get_node_or_null("Burning") as Burning
	if b:
		b.extinguish()


## A burning place: flames over the footprint of a box of `size` (centred, standing on its
## bottom face), e.g. a campfire, a burning wreck or a fire pit.
static func area(parent: Node, xf: Transform3D, size: Vector3, p_palette := "orange") -> Burning:
	var b := Burning.new()
	b.name = "FireArea"
	b.is_area = true
	b.palette = p_palette
	b.box = AABB(Vector3(-size.x * 0.5, -size.y * 0.5, -size.z * 0.5), Vector3(size.x, size.y * 0.25, size.z))
	b.transform = xf
	parent.add_child(b)
	return b


static func _bounds(target: Node3D) -> AABB:
	var inv := target.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in _meshes(target):
		var bb: AABB = (inv * mi.global_transform) * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out if not first else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


static func _meshes(n: Node, into: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	for c in n.get_children():
		if c is Burning or c is CPUParticles3D:
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			into.append(c)
		_meshes(c, into)
	return into


func _ready() -> void:
	var low := Game.graphics == 0
	var pal: Array = PALETTES.get(palette, PALETTES.orange)
	var s := box.size
	var foot := Vector2(s.x, s.z).length() * 0.5 # rough radius of what burns
	var mid := box.get_center()
	if not is_area:
		_shell = ShaderMaterial.new()
		_shell.shader = SHELL
		_shell.set_shader_parameter("intensity", 0.0)
		_shell.set_shader_parameter("deep_color", pal[0])
		_shell.set_shader_parameter("core_color", pal[1])
		_shell.set_shader_parameter("tip_color", pal[2])
		if Game.fire_outline:
			var o := ShaderMaterial.new()
			o.shader = OUTLINE
			o.set_shader_parameter("intensity", 0.0)
			o.set_shader_parameter("deep_color", pal[0])
			o.set_shader_parameter("core_color", pal[1])
			o.set_shader_parameter("tip_color", pal[2])
			_shell.next_pass = o # a flaming outline licking around the glow
		_apply_shell()
		# One flame mass hugging the thing and rising to about twice its height. Wide things
		# (a couch) get two columns of tongues instead of one big bulb.
		var half := lerpf(maxf(s.x, s.z) * 0.5, foot, 0.5)
		var w := half * 2.0 + 1.0 # room for the side tongues to curl out
		var h := s.y * 1.4 + 1.0 + half * 0.4
		if not Game.fire_outline: # (with the flame outline, the outline is the fire)
			_add_body(Vector3(mid.x, box.position.y - 0.05 + h * 0.5, mid.z), w, h, s.y / h, half * 0.8, pal,
				2 if w > h * 1.1 else 1, Vector2(half / (w * 0.5), s.y / (w * 0.5)))
	else:
		# A burning place: one mass of flame over the footprint (up to three columns melted
		# together), no see-through middle.
		var w := maxf(s.x, s.z) * 1.35
		var h := w * 0.8 + 1.3
		var cols := clampi(int(round(w / 1.2)), 1, 3)
		_add_body(Vector3(mid.x, box.position.y - 0.05 + h * 0.5, mid.z), w, h, 0.0, 0.0, pal, cols, Vector2(0.78, 0.4))
	var top := box.position.y + (s.y + foot * 1.8 if not is_area else s.y + 1.4)
	# Smoke: dark cauliflower puffs drifting up above the flames (not with the flame outline:
	# no particles there).
	if not low and not (Game.fire_outline and not is_area):
		_smoke = CPUParticles3D.new()
		_smoke.amount = int(clampf(foot * 4.0, 3.0, 10.0))
		_smoke.lifetime = 2.6
		_smoke.local_coords = false
		_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_smoke.emission_box_extents = Vector3(s.x * 0.25, 0.2, s.z * 0.25)
		_smoke.position = Vector3(mid.x, top + 0.2, mid.z)
		_smoke.direction = Vector3.UP
		_smoke.spread = 15.0
		_smoke.initial_velocity_min = 0.8
		_smoke.initial_velocity_max = 1.6
		_smoke.gravity = Vector3(0.3, 0.6, 0.1)
		_smoke.angle_min = -180.0
		_smoke.angle_max = 180.0
		var size := clampf(foot * 1.5, 0.75, 2.4)
		_smoke.scale_amount_min = size * 1.2
		_smoke.scale_amount_max = size * 2.0
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 1.3))
		_smoke.scale_amount_curve = sc
		var sg := Gradient.new()
		sg.set_color(0, Color(0.25, 0.2, 0.18, 0.0))
		sg.set_color(1, Color(0.35, 0.34, 0.36, 0.0))
		sg.add_point(0.2, Color(0.22, 0.19, 0.18, 0.45))
		_smoke.color_ramp = sg
		_smoke.mesh = QuadMesh.new()
		var world := get_node_or_null("/root/Main/World")
		var fx: Effects = world.get("fx") if world else null
		if fx:
			_smoke.material_override = fx._puff_material(0.0)
		_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = (pal[1] as Color).lerp(Color.WHITE, 0.15)
	_light.omni_range = clampf(foot * 4.5, 3.5, 10.0)
	_light.position = mid + Vector3(0, s.y * 0.5 + 0.5, 0)
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	add_child(_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.stream("fire")
	_sound.bus = "SFX"
	_sound.unit_size = clampf(foot * 3.0, 2.0, 6.0)
	_sound.max_distance = 40.0
	_sound.volume_db = -6.0
	_sound.position = mid
	add_child(_sound)
	_sound.play(randf() * 2.0)
	_set_emitting(true)


func _add_body(at: Vector3, w: float, h: float, hole: float, push: float, pal: Array, cols := 1, hull := Vector2(0.6, 1.0)) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = h
	var m := ShaderMaterial.new()
	m.shader = BODY
	m.set_shader_parameter("edge_color", pal[0])
	m.set_shader_parameter("mid_color", pal[1])
	m.set_shader_parameter("hot_color", pal[2])
	m.set_shader_parameter("hole_top", hole)
	m.set_shader_parameter("aspect", h / w)
	m.set_shader_parameter("columns", cols)
	m.set_shader_parameter("hull", hull)
	m.set_shader_parameter("roundness", roundness if not is_area else 0.8)
	m.set_shader_parameter("tongues", 3 if Game.graphics == 0 else 5)
	m.set_shader_parameter("push", push)
	m.set_shader_parameter("seed", randf())
	m.set_shader_parameter("intensity", 0.0)
	mi.material_override = m
	add_child(mi)
	_bodies.append(m)


func _apply_shell() -> void:
	if _shell == null or not _overlaid.is_empty():
		return
	for mi in _meshes(get_parent()):
		if mi.material_overlay == null:
			mi.material_overlay = _shell
			_overlaid.append(mi)


func extinguish() -> void:
	if _out:
		return
	_out = true
	_set_emitting(false)


func _set_emitting(on: bool) -> void:
	for p in [_smoke]:
		if p:
			(p as CPUParticles3D).emitting = on


func _process(delta: float) -> void:
	_t += delta
	if _left > 0.0 and not _out:
		_left -= delta
		if _left <= 0.0:
			extinguish()
	_fade = move_toward(_fade, 0.0 if _out else 1.0, delta * (1.5 if _out else 3.0))
	if _shell:
		_shell.set_shader_parameter("intensity", _fade)
		if _shell.next_pass:
			(_shell.next_pass as ShaderMaterial).set_shader_parameter("intensity", _fade)
	for m in _bodies:
		m.set_shader_parameter("intensity", _fade)
	_light.light_energy = _fade * (1.8 + 0.5 * sin(_t * 17.0) * sin(_t * 7.3) + 0.3 * sin(_t * 31.0))
	_sound.volume_db = linear_to_db(maxf(_fade, 0.001)) - 6.0
	if _out and _fade <= 0.0:
		for mi in _overlaid:
			if is_instance_valid(mi) and mi.material_overlay == _shell:
				mi.material_overlay = null
		_overlaid.clear()
		_gone += delta
		if _gone > 2.6:
			queue_free()
