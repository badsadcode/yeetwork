class_name Grapple
extends Node3D
## The grapple hook (G / middle mouse / R3). Hold it to hang on and reel in (hold crouch to
## let rope out instead); let go to drop off. What it hooks:
## - the level (anywhere, or only on GrapplePoints, as the map's settings say): you swing on
##   the rope and get reeled up to it;
## - a light prop: it's yanked to you; a heavy or frozen one: you're reeled in to it;
## - a friend: they're yanked to you (help them up a ledge).
## The player who grapples runs the swing on their own peer; everyone sees the rope.

enum Kind { NONE, WORLD, PROP, PLAYER }

const RANGE := 32.0
const REEL := 7.0 # m/s while held
const MIN_LENGTH := 1.6
const YANK_MASS := 60.0 # props this light are pulled to you
const POINT_ASSIST := 1.6 # in grapple-points mode, a point this close to the aim line counts

var player: Player
var kind: int = Kind.NONE
var point := Vector3.ZERO # WORLD: the anchor; PROP: where on the prop (its space)
var target_id := 0
var length := 0.0
var _rope: RopeLine
var _hook: MeshInstance3D
var _flash := 0.0 # PROP yanks / PLAYER yanks: how long the rope still shows
var test_hold := false # (dev checks: hold the grapple without the key)


func _ready() -> void:
	_rope = RopeLine.new()
	_rope.width = 0.05
	_rope.set_color(Color(0.3, 0.3, 0.34))
	add_child(_rope)
	_rope.hide_rope()
	_hook = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	_hook.mesh = sm
	_hook.material_override = Mats.plastic(Color(0.85, 0.75, 0.3), 0.3, 0.6)
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)


## Is the rope taut on something we swing from?
func swinging() -> bool:
	return kind == Kind.WORLD or (kind == Kind.PROP and _flash <= 0.0)


## Where the rope ends (world space), or INF if that's gone.
func anchor() -> Vector3:
	match kind:
		Kind.WORLD:
			return point
		Kind.PROP:
			var p: Prop = player.world.get_prop(target_id)
			return p.global_transform * point if p else Vector3.INF
		Kind.PLAYER:
			var q: Player = player.world.get_player(target_id)
			return q.body_center() if q and q.is_alive() else Vector3.INF
	return Vector3.INF


# --- The player who grapples ----------------------------------------------------------------

func fire() -> void:
	if not player.is_alive() or kind != Kind.NONE:
		return
	var w := player.world
	var mode: String = w.grapple_mode()
	if mode == "off":
		return
	var eye := player.eye_position()
	var aim := player.aim_direction()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + aim * RANGE, Game.L_WORLD | Game.L_PROPS | Game.L_PLAYERS, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var col: Object = hit.get("collider")
	if col is Prop:
		var p := col as Prop
		if p.has_meta("delivered") or p.has_meta("no_grab"):
			_miss()
			return
		if p.mass <= YANK_MASS and not p.freeze:
			_attach(Kind.PROP, Vector3.ZERO, p.prop_id, 0.0, 0.35)
			w.grapple_yank(player, 0, p.prop_id)
		else:
			_attach(Kind.PROP, p.global_transform.affine_inverse() * (hit.position as Vector3), p.prop_id, eye.distance_to(hit.position), 0.0)
		return
	if col is Player:
		_attach(Kind.PLAYER, Vector3.ZERO, (col as Player).player_id, 0.0, 0.35)
		w.grapple_yank(player, 1, (col as Player).player_id)
		return
	if mode == "anywhere" and not hit.is_empty():
		_attach(Kind.WORLD, hit.position, 0, eye.distance_to(hit.position), 0.0)
		return
	# Grapple points only: the one closest to the aim (by angle; a little forgiving), in sight.
	var best: Node3D = null
	var best_d := INF
	for g in get_tree().get_nodes_in_group("grapple_points"):
		var gp: Vector3 = (g as Node3D).global_position
		var to := gp - eye
		var along := to.dot(aim)
		if along <= 0.0 or along > RANGE or (to - aim * along).length() > POINT_ASSIST + along * 0.03:
			continue
		var los := PhysicsRayQueryParameters3D.create(eye, gp, Game.L_WORLD, [player.get_rid()])
		var block := player.get_world_3d().direct_space_state.intersect_ray(los)
		if not block.is_empty() and (block.position as Vector3).distance_to(gp) > 0.6:
			continue
		var angle := (to - aim * along).length() / along
		if angle < best_d:
			best_d = angle
			best = g
	if best:
		_attach(Kind.WORLD, best.global_position, 0, eye.distance_to(best.global_position), 0.0)
	else:
		_miss()


func release() -> void:
	if kind != Kind.NONE:
		_attach(Kind.NONE, Vector3.ZERO, 0, 0.0, 0.0)


func _miss() -> void:
	Sfx.play3d("punt", player.eye_position(), -8.0, 1.6)


func _attach(k: int, p: Vector3, id: int, l: float, flash: float) -> void:
	kind = k
	point = p
	target_id = id
	length = maxf(l, MIN_LENGTH)
	_flash = flash
	if k != Kind.NONE:
		Sfx.play3d("whoosh", player.eye_position(), -2.0, 1.5)
	player.world.grapple_state(player, k, p, id)


## Runs before the player moves (on the peer that controls them): keeps the rope from
## stretching and reels in.
func constrain(delta: float, held: bool, let_out: bool) -> void:
	if kind == Kind.NONE:
		return
	if not held or not player.is_alive():
		release()
		return
	if not swinging():
		return
	var a := anchor()
	if not a.is_finite():
		release()
		return
	if not let_out:
		length = maxf(MIN_LENGTH, length - REEL * delta)
	else:
		length = minf(RANGE, length + REEL * 0.6 * delta)
	var c := player.body_center()
	var to := a - c
	var d := to.length()
	if d < 0.01:
		return
	var n := to / d
	# Reeled all the way in: hang under the anchor, steady (let go to drop right there).
	if length <= MIN_LENGTH + 0.01:
		var hang := a - Vector3.UP * MIN_LENGTH - c
		player.velocity = player.velocity.lerp(hang * 5.0, minf(1.0, 6.0 * delta))
		player.lift_off()
		return
	# On the rope: a little air drag, so reeling in doesn't pump the swing up and up.
	player.velocity *= exp(-0.9 * delta)
	player.velocity = player.velocity.limit_length(16.0)
	if d <= length:
		return
	# No moving away from the anchor, and a firm pull back to the rope's length; reeled in
	# no faster than the reel runs (plus the swing).
	var out := player.velocity.dot(-n)
	if out > 0.0:
		player.velocity += n * out
	player.velocity += n * minf((d - length) * 60.0, 90.0) * delta
	var toward := player.velocity.dot(n)
	if toward > REEL + 4.0:
		player.velocity -= n * (toward - REEL - 4.0)
	if n.y > 0.2:
		player.lift_off()


# --- Everyone: the picture ---------------------------------------------------------------------

## The rope's state from the network (other players' grapples).
func apply_state(k: int, p: Vector3, id: int) -> void:
	kind = k
	point = p
	target_id = id
	_flash = 0.35 if k == Kind.PLAYER or (k == Kind.PROP and p == Vector3.ZERO) else 0.0


func _process(delta: float) -> void:
	if kind == Kind.NONE or player == null:
		if _rope.visible:
			_rope.hide_rope()
			_hook.visible = false
		return
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and (kind == Kind.PLAYER or (kind == Kind.PROP and point == Vector3.ZERO)):
			kind = Kind.NONE # (a yank: the rope shows for a moment)
			return
	var a := anchor()
	if not a.is_finite():
		_rope.hide_rope()
		_hook.visible = false
		return
	var from: Vector3 = player.gun.muzzle_position() if player.gun else player.eye_position()
	_rope.draw(from, a, maxf(length - from.distance_to(a), 0.0) if swinging() else 0.0)
	_hook.global_position = a
	_hook.visible = true
