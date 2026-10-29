class_name ModePumpkin
extends ModeBase
## Pumpkin Smash ("Trick or Yeet"): free-for-all candy grab. Smash jack-o'-lanterns to
## spill candy, walk over candy to collect it. Getting killed spills everything you carry,
## so yeet the leader. First to WIN_CANDY wins the round.

const PUMPKIN_COUNT := 14
const WIN_CANDY := 40
const MAX_CANDY := 140
const PICKUP_RADIUS := 1.4

var _pumpkins: Array[int] = []
var _candy: Array[int] = []
var _respawn_timer := 0.0


func mode_name() -> String:
	return "Pumpkin Smash"


func allow_build() -> bool:
	return false


func spawn_mode_props() -> void:
	for i in PUMPKIN_COUNT:
		_spawn_pumpkin()


func _spawn_pumpkin() -> void:
	var rng: RandomNumberGenerator = world.rng
	var base: Vector3 = world.arena.random_spawn(0, rng)
	var ang := rng.randf() * TAU
	var pos := base + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(2.0, 5.0) + Vector3.UP * 0.8
	var gold := rng.randf() < 0.12
	var p: Prop = world.server_spawn_prop("pumpkin_gold" if gold else "pumpkin", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos))
	_pumpkins.append(p.prop_id)


func tick(delta: float) -> void:
	for i in range(_pumpkins.size() - 1, -1, -1):
		if world.get_prop(_pumpkins[i]) == null:
			_pumpkins.remove_at(i)
	if _pumpkins.size() < PUMPKIN_COUNT:
		_respawn_timer += delta
		if _respawn_timer > 2.5:
			_respawn_timer = 0.0
			_spawn_pumpkin()
	# Candy pickups.
	for i in range(_candy.size() - 1, -1, -1):
		var c := world.get_prop(_candy[i]) as Prop
		if c == null:
			_candy.remove_at(i)
			continue
		if Time.get_ticks_msec() / 1000.0 - c.spawn_time < 0.4:
			continue # let it fly a little first
		for pl: Player in world.players.values():
			if pl.is_alive() and pl.body_center().distance_to(c.global_position) < PICKUP_RADIUS:
				_collect(pl, c)
				_candy.remove_at(i)
				break


func _collect(pl: Player, c: Prop) -> void:
	pl.score += int(c.extra.get("value", 1))
	world.server_player_stats(pl)
	world.server_fx("pickup", c.global_position, Vector3.UP, 1.0)
	world.server_despawn_prop(c)
	if pl.score >= WIN_CANDY:
		world.server_message("%s WINS PUMPKIN SMASH with %d candy!" % [pl.display_name.to_upper(), pl.score], Color(1.0, 0.6, 0.15), true)
		for o: Player in world.players.values():
			o.score = 0
			world.server_player_stats(o)


func on_prop_broken(prop: Prop) -> void:
	if not prop.kind.begins_with("pumpkin"):
		return
	var gold := prop.kind == "pumpkin_gold"
	spill(prop.global_position + Vector3.UP * 0.3, 10 if gold else world.rng.randi_range(4, 6), 2 if gold else 1)


func spill(pos: Vector3, count: int, value: int) -> void:
	var rng: RandomNumberGenerator = world.rng
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var vel := dir * rng.randf_range(2.0, 6.0) + Vector3.UP * rng.randf_range(5.0, 9.0)
		var c: Prop = world.server_spawn_prop("candy", Transform3D(Basis.IDENTITY, pos + dir * 0.2), Vector3.ZERO, Color(0, 0, 0, 0), 0, vel, {"value": value})
		_candy.append(c.prop_id)
	while _candy.size() > MAX_CANDY:
		var old := world.get_prop(_candy.pop_front()) as Prop
		if old:
			world.server_despawn_prop(old)


func on_kill(victim: Player, _killer: Player, _cause: String) -> void:
	var held := victim.score
	if held <= 0:
		return
	var pieces := mini(held, 20)
	spill(victim.body_center(), pieces, maxi(1, held / pieces))
	victim.score = 0
	if held >= 10:
		world.server_message("%s dropped %d candy!" % [victim.display_name, held], Color(1.0, 0.6, 0.15))
