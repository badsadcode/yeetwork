@tool
class_name AnimatedModel
extends PuzzleNode
## Your own model, moving the way you animated it in Blender: a windmill's sails turning, a
## sign swinging, a buoy bobbing, a piston, a platform sliding to and fro, a drawbridge.
## Object animation is enough (no armature needed); an armature works too.
## - Model: a .glb/.gltf/.blend/.tscn with at least one animation; Animation picks which.
## - Parts named "Collision..." (CollisionDeck, Collision_Arm) are what things bump into,
##   moving with the animation and carrying what stands on them (hidden in the game; a
##   moving part is best a box or another simple shape: it's made convex). With none, it's
##   only seen: you walk through it.
## - Every player sees it at the same point of its animation: it runs off the match clock,
##   nothing is sent.
## - Inputs (it's a puzzle piece): without any, it plays all the time; with some, it plays
##   while they're on (Play once: forward while on, back while off: a drawbridge, a gate
##   you made). It's on (an input for others) while it plays.

## Your model (with its animation).
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()
## Which of its animations plays (empty: the first one).
@export var animation := "":
	set(v):
		animation = v
		_rebuild()
## How fast: 1 as you animated it, 2 twice as fast, 0.5 half as fast.
@export_range(0.05, 10.0, 0.05, "or_greater") var speed := 1.0
## loop: over and over. ping pong: there and back again. once: to its end, then it stays
## there (with Inputs: forward while they're on, back while they're off).
@export_enum("loop", "ping pong", "once") var play := "loop"
## Seconds into its animation it starts (several the same: offset them so they don't move
## in step).
@export var offset := 0.0
## Its parts named "Collision..." are solid and move with it.
@export var solid := true
## In the editor, show it moving (off: its first frame).
@export var preview := true

var _inst: Node3D
var _ap: AnimationPlayer
var _anim := ""
var _len := 0.0
var _head := 0.0 # (the playhead, with Inputs or Play once: where it's got to)
var _bodies: Array = [] # [AnimatableBody3D, its Collision mesh]
var _started := false


func _ready() -> void:
	_rebuild()


func evaluate() -> bool:
	return inputs.is_empty() or inputs_on()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _inst:
		_inst.queue_free()
	for b in _bodies:
		(b[0] as Node).queue_free()
	_bodies.clear()
	_inst = null
	_ap = null
	_anim = ""
	_len = 0.0
	if model == null:
		return
	_inst = model.instantiate() as Node3D
	if _inst == null:
		return
	add_child(_inst, false, Node.INTERNAL_MODE_FRONT)
	var aps := _inst.find_children("*", "AnimationPlayer", true, false)
	_ap = aps[0] as AnimationPlayer if not aps.is_empty() else null
	if _ap:
		var names := _ap.get_animation_list()
		_anim = animation if _ap.has_animation(animation) else (String(names[0]) if not names.is_empty() else "")
	if _anim != "":
		_len = maxf(_ap.get_animation(_anim).length, 0.01)
		_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_ap.play(_anim)
		_ap.seek(0.0, true)
	if Engine.is_editor_hint():
		return
	for mi in _inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not String(m.name).to_lower().begins_with("collision") or m.mesh == null:
			continue
		m.visible = false
		if solid:
			_bodies.append([_body_for(m), m])


## A body that follows a Collision mesh (its shape made convex, its scale baked in).
func _body_for(m: MeshInstance3D) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = true
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	var shape := m.mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
	var xf := m.global_transform if m.is_inside_tree() else m.transform
	var scl := xf.basis.orthonormalized().inverse() * xf.basis
	var pts := PackedVector3Array()
	for p in shape.points:
		pts.append(scl * p)
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	body.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	return body


## Where its animation is now, seconds.
func time_now(clock: float) -> float:
	var loops := play != "once" and inputs.is_empty()
	if loops:
		var t := clock * speed + offset
		if play == "ping pong":
			var u := fposmod(t, _len * 2.0)
			return u if u < _len else _len * 2.0 - u
		return fposmod(t, _len)
	return _head


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and _ap and _anim != "":
		_ap.seek(time_now(Time.get_ticks_msec() / 1000.0) if preview else 0.0, true)
		if preview and (play == "once" or not inputs.is_empty()):
			_head = fposmod(_head + delta * speed, _len) # (the editor: just show it moving)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _ap == null or _anim == "":
		return
	var on := active if world else inputs.is_empty()
	if not _started:
		_started = true
		_head = clampf(offset, 0.0, _len) if play == "once" else fposmod(offset, _len)
	if play == "once":
		_head = clampf(_head + (delta if on else -delta) * speed, 0.0, _len)
	elif not inputs.is_empty() and on:
		_head += delta * speed
		if play == "ping pong":
			_head = fposmod(_head, _len * 2.0)
		else:
			_head = fposmod(_head, _len)
	var t := time_now(world.net_time() if world else 0.0)
	if play == "ping pong" and not inputs.is_empty():
		t = _head if _head < _len else _len * 2.0 - _head
	_ap.seek(t, true)
	for b in _bodies:
		var m: MeshInstance3D = b[1]
		(b[0] as AnimatableBody3D).global_transform = Transform3D(m.global_basis.orthonormalized(), m.global_position)


## (the map check) What's wrong with a model for this piece: no animation, or none by the name.
static func notes(who: String, scene: PackedScene, anim: String) -> Array[String]:
	var out: Array[String] = []
	if scene == null:
		return out
	var root := scene.instantiate()
	if root == null:
		return out
	var aps := root.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty() or (aps[0] as AnimationPlayer).get_animation_list().is_empty():
		out.append("%s: its model has no animation (it stands still)." % who)
	elif anim != "" and not (aps[0] as AnimationPlayer).has_animation(anim):
		out.append("%s: its model has no animation \"%s\" (it has %s); the first plays." % [who, anim, ", ".join((aps[0] as AnimationPlayer).get_animation_list())])
	root.free()
	return out
