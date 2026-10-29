extends Node
## Developer tool: flies the local camera through fixed viewpoints and saves screenshots.
## Usage: godot -- --host --bots 6 --tour <output_dir>

const SHOTS_FACING := [
	["overview", Vector3(-30, 26, 38), Vector3(30, 4, 0), 6.0],
	["blue_tower", Vector3(38, 6, 12), Vector3(76, 20, 0), 2.5],
	["hill", Vector3(-34, 3, 4), Vector3(0, 5, 0), 2.5],
	["tower_inside", Vector3(-71.5, 3, 5.5), Vector3(-80, 2, -4), 2.5],
	["roof_view", Vector3(-71, 44.5, 5), Vector3(40, 0, 0), 2.5],
	["planet", Vector3(0, 6, 0), Vector3(5.5, 9.2, -7.7), 2.0],
	["lineup", Vector3(-54.5, 1.9, 0), Vector3(-60, 1.0, 0), 2.0],
	["action", Vector3.ZERO, Vector3.ZERO, 2.5],
	["action2", Vector3.ZERO, Vector3.ZERO, 2.5],
]

const SHOTS_PRIME := [
	# name, eye position, look-at point, settle seconds
	["overview", Vector3(-58, 24, 26), Vector3(0, 4, 0), 6.0],
	["pit_and_tower", Vector3(0, 7.6, 24), Vector3(0, 6, 0), 2.5],
	["blue_base", Vector3(14, 8, 3), Vector3(52, 6, 0), 2.5],
	["side_lane", Vector3(-40, 2, 25), Vector3(10, 3, 22), 2.5],
	["red_base_hall", Vector3(-33, 2, -3), Vector3(-55, 2, 3), 2.5],
	["lineup", Vector3(-42.5, 7.9, 0), Vector3(-48, 7.0, 0), 2.0],
	["action", Vector3.ZERO, Vector3.ZERO, 2.5],
	["action2", Vector3.ZERO, Vector3.ZERO, 2.5],
	["action3", Vector3.ZERO, Vector3.ZERO, 2.5],
]

var world: Node
var out_dir := ""
var _i := -1
var _t := 0.0
var _focus: Node3D
var SHOTS: Array = []


func _process(delta: float) -> void:
	var pl: Player = world.local_player if world else null
	if pl == null or pl.camera == null:
		return
	if _i < 0:
		match world.map_key:
			"facing":
				SHOTS = SHOTS_FACING
			"prime":
				SHOTS = SHOTS_PRIME
			_:
				SHOTS = _generic_shots()
		pl.process_mode = Node.PROCESS_MODE_DISABLED
		pl.model.visible = false
		_next()
	_t += delta
	var shot: Array = SHOTS[_i]
	if shot[0].begins_with("action"):
		_follow_action(pl)
	if _t >= shot[3]:
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%02d_%s.png" % [out_dir, _i, shot[0]]
		img.save_png(path)
		print("Saved ", path)
		if _i + 1 >= SHOTS.size():
			get_tree().quit()
			return
		_next()


## Viewpoints derived from a Map Kit map's spawn points.
func _generic_shots() -> Array:
	var pts: Array = []
	for k in world.arena.spawn_points:
		pts.append_array(world.arena.spawn_points[k])
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	var c := box.get_center()
	var e := box.size * 0.5
	var shots := [
		["overview", c + Vector3(-e.x * 1.15, 16, e.z * 1.35), c, 6.0],
		["overview_b", c + Vector3(e.x * 1.1, 11, -e.z * 1.15), c, 2.5],
	]
	var red: Array = world.arena.spawn_points[1]
	if not red.is_empty():
		shots.append(["from_red_base", red[0] + Vector3(0, 1.7, 0), c + Vector3(0, 1.5, 0), 2.5])
	shots.append(["action", Vector3.ZERO, Vector3.ZERO, 2.5])
	shots.append(["action2", Vector3.ZERO, Vector3.ZERO, 2.5])
	return shots


func _next() -> void:
	_i += 1
	_t = 0.0
	_focus = null
	var shot: Array = SHOTS[_i]
	if shot[0] == "lineup":
		_build_lineup()
	if not shot[0].begins_with("action"):
		_place(world.local_player, shot[1], shot[2])


func _build_lineup() -> void:
	for i in CharacterModel.HAT_COUNT:
		var m := CharacterModel.new()
		world.add_child(m)
		var col: Color = Game.FFA_COLORS[i % Game.FFA_COLORS.size()]
		m.setup(col, i, i + 3)
		var base := Vector3(-60.0, 0.0, 0.0) if world.map_key == "facing" else Vector3(-48.0, 6.0, 0.0)
		m.global_position = base + Vector3(0, 0, -4.5 + i * 1.5)
		for k in 30:
			m.animate(0.05, Vector3.ZERO, Player.F_GROUNDED, -PI * 0.5 + (i - 3) * 0.15, false)


func _place(pl: Player, eye: Vector3, target: Vector3) -> void:
	var to := target - eye
	pl.global_position = eye - Vector3(0, Player.EYE_STAND, 0)
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	pl._head.position = Vector3(0, Player.EYE_STAND, 0)
	pl._head.rotation = Vector3(pl.pitch, pl.yaw, 0)
	pl.camera.rotation = Vector3.ZERO
	pl.camera.fov = 85.0


## Front-on view of whichever bot is doing something interesting.
func _follow_action(pl: Player) -> void:
	if _focus == null or not is_instance_valid(_focus) or not (_focus as Player).is_alive():
		var best: Player = null
		for p: Player in world.players.values():
			if p == pl or not p.is_alive():
				continue
			# Only bots out in the open (sky above) make for a readable shot.
			var head := p.global_position + Vector3(0, 1.4, 0)
			var up := PhysicsRayQueryParameters3D.create(head, head + Vector3.UP * 30.0, Game.L_WORLD)
			if not p.get_world_3d().direct_space_state.intersect_ray(up).is_empty():
				continue
			if best == null or p.gun.vis_kind != GravityGun.Kind.NONE:
				best = p
		_focus = best
	if _focus:
		var p := _focus as Player
		var head := p.global_position + Vector3(0, 1.4, 0)
		var want := head + Basis(Vector3.UP, p.yaw) * Vector3(1.2, 0.6, -3.6)
		var q := PhysicsRayQueryParameters3D.create(head, want, Game.L_WORLD)
		var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			want = head.lerp(hit.position, 0.85)
		_place(pl, want, head - Vector3(0, 0.3, 0))
