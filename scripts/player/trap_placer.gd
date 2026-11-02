class_name TrapPlacer
extends Node3D
## MegaYeet: putting a trap down (the local player, between waves). A trap bought in the shop
## (paid when it's down) or picked up from where it was (free; cancelled, it's sold) follows
## the aim as a preview: green where it fits, red where it can't (and why: the HUD's prompt).
## The grab button (or Use) puts it down, the wheel (or the push / pull buttons) turns it,
## the throw button cancels. A map's spot of its type takes it as you aim into it. The server
## decides (ModeMegaYeet.placement, server_place); a refusal puts the preview back.

const TURN := PI / 4.0

var world: Node
var active := false
var key := ""
var free := false # (picked up: putting it down costs nothing; cancelling sells it)
var ok := false
var why := ""
var _turn := 0.0
var _preview: TrapSpot
var _frame: Node3D
var _fill: StandardMaterial3D
var _edge: StandardMaterial3D
var _check_t := 0.0
var _at := Vector3.ZERO
var _yaw := 0.0


func start(type_key: String, picked_up: bool) -> void:
	stop()
	key = type_key
	free = picked_up
	active = true
	_turn = 0.0
	_check_t = 0.0
	_preview = TrapSpot.make(world, key)
	_preview.active = true # (its built look)
	_preview.name = "TrapPreview"
	add_child(_preview)
	_fill = StandardMaterial3D.new()
	_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill.no_depth_test = true
	_edge = _fill.duplicate() as StandardMaterial3D
	_frame = Node3D.new()
	add_child(_frame)
	var s := _preview.size
	_frame.add_child(PuzzleNode.box_mesh(Vector3(s.x, 0.02, s.z), _fill, Vector3(0, 0.06, 0)))
	var w := 0.1
	for side in [-1, 1]:
		_frame.add_child(PuzzleNode.box_mesh(Vector3(s.x, 0.05, w), _edge, Vector3(0, 0.08, side * (s.z - w) * 0.5)))
		_frame.add_child(PuzzleNode.box_mesh(Vector3(w, 0.05, s.z), _edge, Vector3(side * (s.x - w) * 0.5, 0.08, 0)))
	for c in _frame.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func stop() -> void:
	active = false
	ok = false
	if _preview:
		_preview.queue_free()
		_preview = null
	if _frame:
		_frame.queue_free()
		_frame = null


## The player's buttons while placing (Player hands them here instead of to the gun).
func handle_input() -> void:
	if Input.is_action_just_pressed("gun_grab") or Input.is_action_just_pressed("use"):
		confirm()
	elif Input.is_action_just_pressed("gun_throw"):
		cancel()
	elif Input.is_action_just_pressed("hold_farther"):
		turn(1)
	elif Input.is_action_just_pressed("hold_closer"):
		turn(-1)


## A step round (the wheel: Player hands it here).
func turn(dir: int) -> void:
	_turn += TURN * dir


## Put it down here (if it fits: the server checks again).
func confirm() -> void:
	if not active:
		return
	if not ok:
		Sfx.play_ui("tick", -2.0, 0.5)
		return
	world.place_trap(key, _at, _yaw)
	stop()


func cancel() -> void:
	if not active:
		return
	world.cancel_trap()
	stop()


## What the HUD's prompt says.
func prompt(pad: bool) -> String:
	var k := func(a: String) -> String: return Controls.pad_of(a) if pad else Controls.key_of(a)
	var title := key.get_slice("|", 0)
	var cost := "" if free else "  (%s)" % ModeMegaYeet.price_text(world, ModeMegaYeet.price_of(world, key))
	var head := ("[%s]  Put %s down%s" % [k.call("gun_grab"), title, cost]) if ok else ("%s: %s" % [title, why])
	var sell := "sell it" if free else "cancel"
	var turning := ("%s / %s" % [k.call("hold_farther"), k.call("hold_closer")]) if pad else "Wheel"
	return "%s\n[%s] turn    [%s] %s" % [head, turning, k.call("gun_throw"), sell]


func _process(delta: float) -> void:
	if not active:
		return
	var pl: Player = world.local_player
	if pl == null or not pl.is_alive() or int(world.mode_state.get("phase", -1)) != ModeMegaYeet.Phase.BREAK:
		if free:
			world.cancel_trap() # (the server sells it anyway when the wave comes)
		stop()
		return
	var from := pl.eye_position()
	var q := PhysicsRayQueryParameters3D.create(from, from + pl.aim_direction() * (ModeMegaYeet.PLACE_REACH + 4.0), Game.L_WORLD, [pl.get_rid()])
	var hit := pl.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.5:
		visible = false
		ok = false
		why = "aim at the ground"
		return
	visible = true
	_yaw = pl.yaw + _turn
	var at: Vector3 = hit.position
	_check_t -= delta
	if _check_t <= 0.0 or at.distance_to(_at) > 0.25:
		_check_t = 0.1
		var p := ModeMegaYeet.placement(world, pl, key, at, _yaw, free)
		ok = p.ok
		why = String(p.why).to_lower()
		if p.spot:
			_yaw = (p.spot as TrapSpot).global_rotation.y
		at = p.at
		_at = at
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), _at)
	var c := Color(0.3, 1.0, 0.45) if ok else Color(1.0, 0.3, 0.25)
	_fill.albedo_color = Color(c, 0.18)
	_edge.albedo_color = Color(c, 0.9)
