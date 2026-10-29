class_name World
extends Node3D
## A running match. Owns the arena, players, props and effects, and is the single hub for
## all network traffic (every RPC lives here, so node paths always resolve).
##
## Authority model:
##   * Server simulates props, destruction, damage, scoring and gravity guns.
##   * Each peer simulates its own player (bots run on the server) and streams state.
##   * Effects that only change how things look are broadcast and played locally.

signal leave_requested

const STATE_RATE := 1.0 / 30.0
const PROP_RATE := 1.0 / 30.0
const MAX_DEBRIS := 200
const NET_FRAGMENT_VOLUME := 0.05 # m^3; smaller fragments are local-only effects
const SMALL_ISLAND := 6 # unsupported groups up to this many cells drop at once
const BREAK_SHATTER := 0
const BREAK_DROP := 1
const MAX_SPAWNED_PER_PLAYER := 25
const MAX_CORPSES := 12
const RESPAWN_TIME := 3.0
const SPOOKY_BOT_NAMES := ["Count Yeetula", "Boo-nkers", "Pumpkin Spice", "Ghoulie", "Skelly Splat", "Mummy Dearest", "Frankenyeet", "Wobblin' Goblin", "Jack O'Splat", "Witchy Wanda", "Casper the Thrown", "Sir Spooks-a-lot"]
const BOT_NAMES := ["Bonkers", "Sir Yeets-a-lot", "Wobbles", "Ragdolly Parton", "Flopsy", "Chonk", "Splatworth", "Gravy Gunner", "Noodle", "Bumpkin", "Captain Thud", "Jellybean"]

var arena: Arena
var fx: Effects
var fx_root: Node3D
var hud: Hud
var players_root: Node3D
var props_root: Node3D
var mode_logic: ModeBase
var mode: int = Game.Mode.SANDBOX
var map_key := "facing"
var is_server := false
var rng := RandomNumberGenerator.new()
var players := {} # id -> Player
var props := {} # id -> Prop
var team_scores := {1: 0, 2: 0}
var local_player: Player
var ready_peers: Array[int] = []

var _time_offset := 0.0
var _next_prop_id := 1
var _next_bot_id := 1000
var _state_accum := 0.0
var _prop_accum := 0.0
var _prop_cursor := 0
var _sent_xforms := {} # prop id -> Transform3D last sent
var _respawn_at := {} # player id -> time
var _restock: Array = [] # [time, kind, Transform3D]
var _debris: Array[int] = []
var _crumbling := {} # Destructible -> next crumble time
var _spawned_by := {} # player id -> Array[int]
var _spawn_cd := {}
var _pair_cd := {}
var _corpses: Array[Node] = []


func _ready() -> void:
	name = "World"


func net_time() -> float:
	return Time.get_ticks_msec() / 1000.0 + _time_offset


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func start(server: bool) -> void:
	is_server = server
	rng.randomize()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	fx = Effects.new()
	add_child(fx)
	fx_root = fx
	hud = Hud.new()
	hud.world = self
	add_child(hud)
	hud.leave_pressed.connect(func(): leave_requested.emit())
	if server:
		mode = Game.mode
		Game.spooky = Game.halloween_active()
		_build_arena(Game.map)
		mode_logic = _make_mode(mode)
		mode_logic.setup(self)
		if Game.spooky:
			_server_spooky_props()
		for entry in arena.initial_props:
			var p := server_spawn_prop(entry[0], entry[1])
			p.set_meta("map_prop", true)
		mode_logic.spawn_mode_props()
		_start_ambience()
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_server_add_player(1, Game.player_name, false)
		for i in Game.bot_count:
			_server_add_bot()
		hud.on_mode_changed()
	else:
		_c_hello.rpc_id(1, Game.player_name, Game.VERSION)


func _start_ambience() -> void:
	Sfx.set_ambience("wind" if Game.spooky else "", -16.0)


func _exit_tree() -> void:
	Sfx.set_ambience("")


## Halloween dressing: some crates become jack-o'-lanterns, plus pumpkins, gravestones and
## coffins scattered near spawn points (skipping spots blocked by geometry).
func _server_spooky_props() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = 31337
	for entry in arena.initial_props:
		if entry[0] == "crate" and srng.randf() < 0.4:
			entry[0] = "pumpkin"
	var spots: Array = arena.spawn_points[0].duplicate()
	for t in [1, 2]:
		spots.append_array(arena.spawn_points[t])
	var placed := 0
	for i in spots.size():
		if placed >= 18:
			break
		var sp: Vector3 = spots[(i * 7) % spots.size()]
		var kinds := ["pumpkin", "pumpkin", "gravestone", "pumpkin", "coffin", "gravestone"]
		var kind: String = kinds[placed % kinds.size()]
		var ang := srng.randf() * TAU
		var pos := sp + Vector3(cos(ang), 0, sin(ang)) * srng.randf_range(2.5, 4.0)
		var half: Vector3 = Prop.DEFS[kind].size
		var h := half.y if kind.begins_with("pumpkin") else half.y * 0.5
		pos.y += h + 0.05
		if not _spot_free(pos, half):
			continue
		arena.initial_props.append([kind, Transform3D(Basis(Vector3.UP, srng.randf() * TAU), pos)])
		placed += 1


func _spot_free(pos: Vector3, half: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = half * 0.9
	params.shape = b
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.collision_mask = Game.L_WORLD
	if not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
		return false
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 3.0, Game.L_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _build_arena(key: String) -> void:
	map_key = key
	arena = Arena.new()
	add_child(arena)
	move_child(arena, 0)
	arena.build(self, key)


func _make_mode(m: int) -> ModeBase:
	match m:
		Game.Mode.CTF:
			return ModeCTF.new()
		Game.Mode.DODGEBALL:
			return ModeDodgeball.new()
		Game.Mode.PUMPKIN:
			return ModePumpkin.new()
	return ModeBase.new()


func mode_name() -> String:
	return "%s · %s" % [Game.MODE_NAMES[mode], Game.map_display_name(map_key)]


func is_team_mode() -> bool:
	return mode == Game.Mode.CTF or mode == Game.Mode.DODGEBALL


func get_player(id: int) -> Player:
	return players.get(id)


func get_prop(id: int) -> Prop:
	var p: Prop = props.get(id)
	return p if is_instance_valid(p) else null


func are_teammates(a: Player, b: Player) -> bool:
	return a.team != Game.TEAM_NONE and a.team == b.team


func hold_time_limit(a: Player, b: Player) -> float:
	return mode_logic.hold_time_limit(a, b) if mode_logic else 2.0


func allow_freeze() -> bool:
	return mode_logic.allow_build() if mode_logic else false


# --- Broadcast helpers ------------------------------------------------------------

## Send an RPC to every peer that has finished joining (not to ourselves).
func _bc(method: StringName, args: Array) -> void:
	for peer in ready_peers:
		callv("rpc_id", [peer, method] + args)


## Run locally on the server and send to every joined peer.
func _bc_all(method: StringName, args: Array) -> void:
	callv(method, args)
	_bc(method, args)


## Deliver to the peer that simulates this player.
func _to_owner(pl: Player, method: StringName, args: Array) -> void:
	if pl.is_bot or pl.owner_peer == multiplayer.get_unique_id():
		callv(method, args)
	elif ready_peers.has(pl.owner_peer):
		callv("rpc_id", [pl.owner_peer, method] + args)


# --- Joining / leaving ------------------------------------------------------------

func _on_peer_connected(_peer: int) -> void:
	pass # Wait for _c_hello.


func _on_peer_disconnected(peer: int) -> void:
	ready_peers.erase(peer)
	var pl := get_player(peer)
	if pl:
		server_message("%s left" % pl.display_name, Color(0.8, 0.8, 0.8))
		_server_remove_player(pl)


@rpc("any_peer", "call_remote", "reliable")
func _c_hello(pname: String, version: String) -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if players.has(peer):
		return
	if version != Game.VERSION:
		print("Peer %d has version %s (server %s)" % [peer, version, Game.VERSION])
	pname = pname.strip_edges().substr(0, 20)
	if pname.is_empty():
		pname = "Yeeter"
	_server_add_player(peer, pname, false)
	_s_init.rpc_id(peer, _build_init_state())
	ready_peers.append(peer)
	server_message("%s joined the chaos" % pname, Color(0.7, 1.0, 0.7))


func _build_init_state() -> Dictionary:
	var pl_list := []
	for pl: Player in players.values():
		pl_list.append(_player_info(pl))
	var pr_list := []
	for p: Prop in props.values():
		if is_instance_valid(p):
			pr_list.append([p.prop_id, p.kind, p.global_transform, p.size, p.color, p.team, p.extra])
	var broken := {}
	for d in arena.destructibles:
		if not d.broken_cells.is_empty():
			broken[d.wall_id] = d.broken_cells
	var wall_damage := {}
	for d in arena.destructibles:
		wall_damage[d.wall_id] = d.all_damage_bytes()
	var guns := []
	for pl: Player in players.values():
		if pl.gun.held_kind != GravityGun.Kind.NONE:
			guns.append([pl.player_id, pl.gun.held_kind, pl.gun.held_id])
	return {
		"mode": mode,
		"spooky": Game.spooky,
		"map": map_key,
		"time": net_time(),
		"players": pl_list,
		"props": pr_list,
		"broken": broken,
		"wall_damage": wall_damage,
		"scores": team_scores,
		"guns": guns,
	}


func _player_info(pl: Player) -> Dictionary:
	return {
		"id": pl.player_id, "owner": pl.owner_peer, "bot": pl.is_bot, "name": pl.display_name,
		"team": pl.team, "color": pl.color, "hat": pl.hat, "frags": pl.frags, "deaths": pl.deaths,
		"score": pl.score, "pos": pl.global_position, "yaw": pl.yaw, "hp": pl.hp, "alive": pl.is_alive(),
	}


@rpc("authority", "call_remote", "reliable")
func _s_init(state: Dictionary) -> void:
	mode = state.mode
	Game.spooky = state.get("spooky", false)
	_start_ambience()
	_build_arena(state.map)
	_time_offset = state.time - now()
	team_scores = state.scores
	for info in state.players:
		_create_player(info)
	for e in state.props:
		_create_prop(e[0], e[1], e[2], e[3], e[4], e[5], false, e[6])
	for wall_id in state.broken:
		if wall_id < arena.destructibles.size():
			arena.destructibles[wall_id].remove_cells(state.broken[wall_id])
	for wall_id in state.wall_damage:
		if wall_id < arena.destructibles.size():
			arena.destructibles[wall_id].set_all_damage(state.wall_damage[wall_id])
	for g in state.guns:
		var pl := get_player(g[0])
		if pl:
			pl.gun.set_visual_state(g[1], g[2])
	hud.on_mode_changed()


func _server_add_player(peer: int, pname: String, bot: bool) -> Player:
	var id := peer
	if bot:
		id = _next_bot_id
		_next_bot_id += 1
	var team := mode_logic.pick_team(players)
	var info := {
		"id": id, "owner": 1 if bot else peer, "bot": bot, "name": pname, "team": team,
		"color": mode_logic.player_color(team, players.size()), "hat": (CharacterModel.NORMAL_HATS + rng.randi() % 2) if Game.spooky and rng.randf() < 0.75 else rng.randi() % CharacterModel.NORMAL_HATS,
		"frags": 0, "deaths": 0, "score": 0, "pos": Vector3.ZERO, "yaw": 0.0, "hp": 100.0, "alive": true,
	}
	var pl := _create_player(info)
	var spawn := mode_logic.spawn_point(pl)
	pl.respawn(spawn, _yaw_toward_center(spawn))
	info.pos = spawn
	info.yaw = pl.yaw
	_bc("_s_add_player", [info])
	if bot:
		pl.bot_brain = BotBrain.new(pl, self)
	return pl


func _server_add_bot() -> void:
	var used := {}
	for pl: Player in players.values():
		used[pl.display_name] = true
	var names: Array = SPOOKY_BOT_NAMES if Game.spooky else BOT_NAMES
	var free := names.filter(func(n): return not used.has(n))
	var bot_name: String = free[rng.randi() % free.size()] if not free.is_empty() else "Bot %d" % _next_bot_id
	_server_add_player(0, bot_name, true)


func _yaw_toward_center(pos: Vector3) -> float:
	var to := -pos
	return atan2(-to.x, -to.z)


func _create_player(info: Dictionary) -> Player:
	var pl := Player.new()
	pl.setup(self, info)
	players_root.add_child(pl)
	players[pl.player_id] = pl
	pl.global_position = info.pos
	pl.yaw = info.yaw
	pl.hp = info.hp
	if not info.alive:
		pl.die(Vector3.ZERO)
	if pl.is_local_human():
		local_player = pl
	hud.on_players_changed()
	return pl


@rpc("authority", "call_remote", "reliable")
func _s_add_player(info: Dictionary) -> void:
	if not players.has(info.id):
		_create_player(info)


func _server_remove_player(pl: Player) -> void:
	pl.gun.release(false)
	for other: Player in players.values():
		if other.gun.held_kind == GravityGun.Kind.PLAYER and other.gun.held_id == pl.player_id:
			other.gun.release(false)
	for id in _spawned_by.get(pl.player_id, []):
		var p := get_prop(id)
		if p:
			server_despawn_prop(p)
	_spawned_by.erase(pl.player_id)
	_bc_all("_s_remove_player", [pl.player_id])


@rpc("authority", "call_remote", "reliable")
func _s_remove_player(id: int) -> void:
	var pl := get_player(id)
	if pl:
		players.erase(id)
		pl.queue_free()
		hud.on_players_changed()


# --- Main loop ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_server:
		return
	mode_logic.tick(delta)
	if not _crumbling.is_empty():
		_server_crumble_tick()
	var t := now()
	for id in _respawn_at.keys():
		if t >= _respawn_at[id]:
			_respawn_at.erase(id)
			var pl := get_player(id)
			if pl:
				var pos := mode_logic.spawn_point(pl)
				_bc_all("_s_respawn", [id, pos, _yaw_toward_center(pos)])
	for i in range(_restock.size() - 1, -1, -1):
		if t >= _restock[i][0]:
			var p := server_spawn_prop(_restock[i][1], _restock[i][2])
			p.set_meta("map_prop", true)
			server_fx("spawn", p.global_position, Vector3.UP, 1.0)
			_restock.remove_at(i)
	_state_accum += delta
	if _state_accum >= STATE_RATE:
		_state_accum = 0.0
		_send_player_states()
	_prop_accum += delta
	if _prop_accum >= PROP_RATE:
		_prop_accum = 0.0
		_send_prop_snapshot()


# --- Player state sync ------------------------------------------------------------

## Called by the controlling peer at ~30 Hz.
func net_send_player_state(pl: Player) -> void:
	if is_server:
		return # the server streams everyone in _send_player_states
	_c_state.rpc_id(1, pl.global_position, pl.velocity, pl.yaw, pl.pitch, pl.flags)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _c_state(pos: Vector3, vel: Vector3, yaw: float, pitch: float, flags: int) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl:
		pl.apply_net_state(pos, vel, yaw, pitch, flags)


func _send_player_states() -> void:
	if ready_peers.is_empty():
		return
	var data := []
	for pl: Player in players.values():
		data.append(pl.get_net_state())
	_bc("_s_states", [data])


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _s_states(data: Array) -> void:
	for s in data:
		var pl := get_player(s[0])
		if pl:
			pl.apply_net_state(s[1], s[2], s[3], s[4], s[5])


# --- Props ------------------------------------------------------------------------

func _create_prop(id: int, kind: String, xform: Transform3D, size: Vector3, color: Color, team: int, server: bool, extra := {}) -> Prop:
	var p := Prop.create(self, id, kind, xform, size, color, team, extra)
	p.setup_role(server)
	props_root.add_child(p)
	props[id] = p
	return p


func server_spawn_prop(kind: String, xform: Transform3D, size := Vector3.ZERO, color := Color(0, 0, 0, 0), team := 0, vel := Vector3.ZERO, extra := {}) -> Prop:
	var id := _next_prop_id
	_next_prop_id += 1
	var p := _create_prop(id, kind, xform, size, color, team, true, extra)
	p.linear_velocity = vel
	_sent_xforms[id] = xform
	_bc("_s_spawn_prop", [id, p.kind, xform, p.size, p.color, team, extra])
	return p


@rpc("authority", "call_remote", "reliable")
func _s_spawn_prop(id: int, kind: String, xform: Transform3D, size: Vector3, color: Color, team: int, extra: Dictionary) -> void:
	if not props.has(id):
		_create_prop(id, kind, xform, size, color, team, false, extra)


func server_despawn_prop(p: Prop) -> void:
	if p.held_by != 0:
		var holder := get_player(p.held_by)
		if holder:
			holder.gun.release(false)
	_sent_xforms.erase(p.prop_id)
	_bc_all("_s_despawn_prop", [p.prop_id])


@rpc("authority", "call_remote", "reliable")
func _s_despawn_prop(id: int) -> void:
	var p := get_prop(id)
	props.erase(id)
	if p:
		for pl: Player in players.values():
			if pl.gun.vis_kind == GravityGun.Kind.PROP and pl.gun.vis_id == id:
				pl.gun.set_visual_state(GravityGun.Kind.NONE, 0)
		p.queue_free()


func _send_prop_snapshot() -> void:
	if ready_peers.is_empty():
		return
	var ids := props.keys()
	var count := ids.size()
	if count == 0:
		return
	# Packets of up to 28 props (~1.2 KB) stay under the ENet MTU; at most 4 per tick.
	var buf := PackedFloat32Array()
	var in_packet := 0
	var packets := 0
	var checked := 0
	while checked < count and packets < 4:
		_prop_cursor = (_prop_cursor + 1) % count
		checked += 1
		var p := get_prop(ids[_prop_cursor])
		if p == null:
			continue
		var xf := p.global_transform
		var last: Transform3D = _sent_xforms.get(p.prop_id, Transform3D())
		if xf.origin.distance_squared_to(last.origin) < 0.0001 and xf.basis.is_equal_approx(last.basis):
			continue
		_sent_xforms[p.prop_id] = xf
		var q := xf.basis.get_rotation_quaternion()
		var v := p.linear_velocity
		buf.append_array([p.prop_id, xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w, v.x, v.y, v.z])
		in_packet += 1
		if in_packet >= 28:
			_bc("_s_props", [buf])
			buf = PackedFloat32Array()
			in_packet = 0
			packets += 1
	if in_packet > 0:
		_bc("_s_props", [buf])


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _s_props(buf: PackedFloat32Array) -> void:
	var i := 0
	while i + 10 < buf.size():
		var p := get_prop(int(buf[i]))
		if p:
			p.apply_snapshot(Vector3(buf[i + 1], buf[i + 2], buf[i + 3]), Quaternion(buf[i + 4], buf[i + 5], buf[i + 6], buf[i + 7]).normalized(), Vector3(buf[i + 8], buf[i + 9], buf[i + 10]))
		i += 11


func server_prop_fell_out(p: Prop) -> void:
	if p.is_queued_for_deletion() or not props.has(p.prop_id):
		return
	if mode_logic.on_prop_fell_out(p):
		return
	if p.has_meta("map_prop"):
		_restock.append([now() + 10.0, p.kind, p.home_transform])
	server_despawn_prop(p)


func server_unfreeze_prop(p: Prop) -> void:
	p.freeze = false
	p.frozen_by_player = false
	p.sleeping = false


func server_freeze_prop(p: Prop) -> void:
	p.linear_velocity = Vector3.ZERO
	p.angular_velocity = Vector3.ZERO
	p.freeze = true
	p.frozen_by_player = true
	server_fx("zap", p.global_position, Vector3.UP, 1.0)


## Called (deferred) when a server-side prop touches something.
func server_prop_impact(p: Prop, body: Node, rel: Vector3, speed: float) -> void:
	if not is_instance_valid(p) or not is_instance_valid(body) or p.exploded:
		return
	var t := now()
	if speed > 3.0 and p.can_sound(t):
		var energy := 0.5 * p.mass * speed * speed
		var dir := rel.normalized()
		var contact := p.global_position + dir * p.size.length() * 0.3
		var mat_name := "body" if body is Player else p.impact_material()
		server_fx("impact:" + mat_name, contact, rel, clampf(energy / 6000.0, 0.03, 3.0), -dir)
	if body is Player:
		_prop_hits_player(p, body as Player, rel, speed)
	if p.is_fragile() and 0.5 * p.mass * speed * speed > Prop.DEFS[p.kind].fragile:
		server_break_prop(p, rel)
		return
	if body is Player:
		return
	if p.live and not (body is Prop and (body as Prop).held_by != 0):
		p.live = false
	if body is Prop:
		var o := body as Prop
		if o.explosive and speed > 12.0:
			_schedule_explosion(o, 0.05)
	if p.explosive and speed > 13.0:
		_schedule_explosion(p, 0.0)
		return
	if body.has_meta("destructible") and speed > 7.0:
		var energy := 0.5 * p.mass * speed * speed
		if energy > 900.0:
			var d: Destructible = body.get_meta("destructible")
			var attacker := p.last_thrower if t - p.last_thrown_time < 6.0 else 0
			var broke := false
			var extent := p.size.length() * 0.5
			if p.mass < 12.0:
				# Small fast projectile: concentrated punch, small hole, wide cracks.
				broke = server_damage_destructible(d, p.global_position, 0.2 + extent * 0.4, clampf(energy / 30.0, 0.0, 220.0), rel, attacker, 1.0)
			else:
				# Heavy object: flatter profile, hole scales with size and mass.
				broke = server_damage_destructible(d, p.global_position, clampf(0.45 + extent * 0.6 + p.mass / 400.0, 0.5, 1.9), clampf(energy / 28.0, 0.0, 480.0), rel, attacker, 3.0)
			if broke:
				# Keep most of the momentum: smash through rather than bounce.
				p.linear_velocity = rel * 0.75
	if p.kind == "shard" and speed > 13.0 and 0.5 * p.mass * speed * speed > 4000.0:
		_server_split_fragment(p, rel)


func _prop_hits_player(p: Prop, pl: Player, rel: Vector3, speed: float) -> void:
	if p.held_by == pl.player_id or not pl.is_alive() or speed < 6.0 or p.freeze:
		return
	var t := now()
	var attacker := get_player(p.last_thrower) if t - p.last_thrown_time < 6.0 else null
	if attacker == pl:
		attacker = null
	if mode_logic.on_prop_hit_player(p, pl, attacker):
		return
	var key := "%d:%d" % [p.prop_id, pl.player_id]
	if t - _pair_cd.get(key, -10.0) < 0.3:
		return
	_pair_cd[key] = t
	var dmg := clampf(0.5 * p.mass * speed * speed / 160.0 - 4.0, 0.0, 150.0)
	var kb := rel * (p.mass / (p.mass + Player.MASS)) * 1.3 + Vector3.UP * minf(speed * 0.2, 5.0)
	var rag := 1.1 if kb.length() > 9.0 else 0.0
	server_launch_player(pl, kb, false, rag, attacker.player_id if attacker else 0)
	if dmg > 0.0:
		server_damage_player(pl, dmg, attacker.player_id if attacker else 0, "prop:" + p.kind, pl.body_center(), rel)
	p.live = false
	if p.explosive and speed > 10.0:
		_schedule_explosion(p, 0.0)


func _schedule_explosion(p: Prop, delay: float) -> void:
	if p.exploded:
		return
	p.exploded = true
	if delay <= 0.0:
		server_explode(p)
	else:
		get_tree().create_timer(delay).timeout.connect(_explode_by_id.bind(p.get_instance_id()))


func _explode_by_id(id: int) -> void:
	var p := instance_from_id(id) as Prop
	if p and is_instance_valid(p) and not p.is_queued_for_deletion():
		server_explode(p)


## Fragile props (pumpkins, gravestones, coffins) burst or shatter into fragments.
func server_break_prop(p: Prop, rel: Vector3) -> void:
	if not is_instance_valid(p) or p.is_queued_for_deletion() or not props.has(p.prop_id):
		return
	p.exploded = true
	var def: Dictionary = Prop.DEFS[p.kind]
	var xf := p.global_transform
	var vel := p.linear_velocity
	var kind := p.kind
	var col := p.color
	var thickness := p.size.z
	mode_logic.on_prop_broken(p)
	if p.has_meta("map_prop"):
		_restock.append([now() + 20.0, kind, p.home_transform])
	server_despawn_prop(p)
	if kind.begins_with("pumpkin"):
		server_fx("pumpkin", xf.origin, rel, 2.0 if kind == "pumpkin_gold" else 1.0)
	elif def.has("breaks_into"):
		_server_scatter_pieces(_prop_pieces(kind, def, p.size, p.prop_id), xf, vel, rel, col, "metal" if def.breaks_into == "staves" else "wood")
	elif def.shape == "outline":
		var mat_name: String = def.get("shatter", "concrete")
		var srng := RandomNumberGenerator.new()
		srng.seed = p.prop_id * 7717
		var basis := xf.basis.orthonormalized()
		for piece in Fracture.shatter(Prop.outline_for(kind), 5, srng):
			var pc := Fracture.centroid(piece)
			var local := Fracture.translated(piece, -pc)
			var pos := xf * Vector3(pc.x, pc.y, 0.0)
			var v := vel * 0.5 + (pos - xf.origin).normalized() * srng.randf_range(2.0, 5.0) + Vector3.UP * 2.0
			if Fracture.area(piece) * thickness >= NET_FRAGMENT_VOLUME * 0.4:
				var frag := server_spawn_prop("shard", Transform3D(basis, pos), Vector3.ZERO, col, 0, v, {"polys": [local], "t": thickness, "mat": mat_name})
				_track_debris(frag)
			else:
				server_fx_shard(local, thickness, Transform3D(basis, pos), v, col, mat_name)
		server_fx("impact:" + ("wood" if mat_name == "wood" else "stone"), xf.origin, rel, 1.5, Vector3.UP)


## Breaks a prop into flat pieces: [poly (local 2D), thickness, Transform3D in prop space].
## Crates burst into boards, barrels into staves and lids, planks snap in two.
func _prop_pieces(kind: String, def: Dictionary, size: Vector3, seed_value: int) -> Array:
	var prng := RandomNumberGenerator.new()
	prng.seed = seed_value * 4421
	var out := []
	match def.breaks_into:
		"boards":
			var s := size.x
			var t := 0.08 * s
			for axis in 3:
				for side in [-1.0, 1.0]:
					var n := Vector3.ZERO
					n[axis] = side
					var up := Vector3.UP if axis != 1 else Vector3.FORWARD
					var x := up.cross(n).normalized()
					var y := n.cross(x).normalized()
					var face := Transform3D(Basis(x, y, n), n * (s * 0.5 - t * 0.5))
					for k in 2:
						var y0 := -s * 0.5 + k * s * 0.5
						var rect := PackedVector2Array([Vector2(-s * 0.5, y0), Vector2(s * 0.5, y0), Vector2(s * 0.5, y0 + s * 0.48), Vector2(-s * 0.5, y0 + s * 0.48)])
						for piece in Fracture.shatter(rect, prng.randi_range(1, 2), prng, Vector2.INF, Vector2(0.35, 1.0)):
							out.append([piece, t, face])
		"staves":
			var r := size.x
			var h := size.y
			var count := 8
			var w := TAU * r / count
			for i in count:
				var a := i * TAU / count
				var n := Vector3(cos(a), 0, sin(a))
				var x := Vector3.UP.cross(n).normalized()
				var rect := PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
				out.append([rect, 0.06, Transform3D(Basis(x, Vector3.UP, n), n * (r - 0.03))])
			for side in [-1.0, 1.0]:
				var lid := PackedVector2Array()
				for i in 8:
					lid.append(Vector2.from_angle(i * TAU / 8.0) * r * 0.95)
				out.append([lid, 0.06, Transform3D(Basis(Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP), Vector3.UP * side * (h * 0.5 - 0.03))])
		"split":
			var rect := PackedVector2Array([Vector2(-size.x * 0.5, -size.z * 0.5), Vector2(size.x * 0.5, -size.z * 0.5), Vector2(size.x * 0.5, size.z * 0.5), Vector2(-size.x * 0.5, size.z * 0.5)])
			var cut := Vector2(prng.randf_range(-size.x * 0.2, size.x * 0.2), 0)
			for piece in Fracture.split(rect, cut, prng):
				out.append([piece, size.y, Transform3D(Basis(Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP), Vector3.ZERO)])
	return out


## Spawns prop pieces flying outward. The biggest few are networked (grabbable); the rest
## are local splinters.
func _server_scatter_pieces(pieces: Array, xf: Transform3D, vel: Vector3, rel: Vector3, col: Color, mat_name: String) -> void:
	pieces.sort_custom(func(a, b): return Fracture.area(a[0]) * a[1] > Fracture.area(b[0]) * b[1])
	var srng := RandomNumberGenerator.new()
	srng.randomize()
	var basis := xf.basis.orthonormalized()
	for i in pieces.size():
		var poly: PackedVector2Array = pieces[i][0]
		var t: float = pieces[i][1]
		var local_xf: Transform3D = pieces[i][2]
		var pc := Fracture.centroid(poly)
		var piece_xf := Transform3D(basis, xf.origin) * local_xf * Transform3D(Basis.IDENTITY, Vector3(pc.x, pc.y, 0))
		var out_dir := (piece_xf.origin - xf.origin).normalized()
		var v := vel * 0.4 + out_dir * srng.randf_range(3.0, 7.0) + Vector3.UP * srng.randf_range(1.0, 4.0) - rel.normalized() * 1.5
		var local := Fracture.translated(poly, -pc)
		if i < 4 and Fracture.area(poly) * t >= 0.006:
			var frag := server_spawn_prop("shard", piece_xf, Vector3.ZERO, col, 0, v, {"polys": [local], "t": t, "mat": mat_name})
			frag.angular_velocity = Vector3(srng.randf_range(-9, 9), srng.randf_range(-9, 9), srng.randf_range(-9, 9))
			_track_debris(frag)
		else:
			server_fx_shard(local, t, piece_xf, v, col, mat_name)
	server_fx("impact:" + mat_name, xf.origin, rel, 1.4, Vector3.UP)
	server_fx("crack" if mat_name != "metal" else "impact:metal", xf.origin, rel, 1.0)


func server_explode(p: Prop) -> void:
	p.exploded = true
	var pos := p.global_position
	var radius := 7.5
	var t := now()
	var attacker := p.last_thrower if t - p.last_thrown_time < 8.0 else 0
	server_fx("explosion", pos, Vector3.UP, radius)
	var to_break: Array[Prop] = []
	for o: Prop in props.values():
		if not is_instance_valid(o) or o == p:
			continue
		var to := o.global_position - pos
		var d := to.length()
		if d > radius:
			continue
		if o.is_fragile() and d < radius * 0.7:
			to_break.append(o)
			continue
		if o.explosive and not o.exploded:
			o.last_thrower = attacker
			o.last_thrown_time = p.last_thrown_time
			_schedule_explosion(o, 0.12 + d * 0.02)
			continue
		if o.freeze:
			if not o.frozen_by_player:
				continue
			server_unfreeze_prop(o)
		var f := 1.0 - d / radius
		o.linear_velocity += (to.normalized() + Vector3.UP * 0.5) * f * minf(2200.0 / o.mass, 35.0)
		o.angular_velocity += Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		o.sleeping = false
		o.last_thrower = attacker
		o.last_thrown_time = p.last_thrown_time
	for o in to_break:
		server_break_prop(o, (o.global_position - pos).normalized() * 15.0)
	for pl: Player in players.values():
		if not pl.is_alive():
			continue
		var to := pl.body_center() - pos
		var d := to.length()
		if d > radius:
			continue
		var f := 1.0 - d / radius
		server_launch_player(pl, (to.normalized() + Vector3.UP * 0.6) * 24.0 * f, false, 1.5, attacker)
		server_damage_player(pl, 90.0 * f + 10.0, attacker, "explosion", pl.body_center(), to)
	for d in arena.destructibles:
		if d.global_position.distance_to(pos) < radius + 30.0 and not d.cells_near(pos, radius * 0.6).is_empty():
			server_damage_destructible(d, pos, radius * 0.6, 260.0, (d.global_position - pos).normalized() * 14.0 + Vector3.UP * 4.0, attacker, 2.0)
	var shrapnel := _prop_pieces("barrel", {"breaks_into": "staves"}, p.size, p.prop_id)
	var bxf := p.global_transform
	var bcol := p.color
	if p.has_meta("map_prop"):
		_restock.append([t + 25.0, p.kind, p.home_transform])
	server_despawn_prop(p)
	_server_scatter_pieces(shrapnel, bxf, Vector3.UP * 6.0, Vector3.DOWN * 20.0, bcol, "metal")


# --- Destruction ------------------------------------------------------------------

## Applies damage to a slab. `sharp` shapes the damage profile (see Destructible).
## Returns true if any cell broke.
func server_damage_destructible(d: Destructible, point: Vector3, radius: float, amount: float, impulse: Vector3, _attacker: int, sharp := 2.0) -> bool:
	var res := d.apply_damage(point, radius, amount, sharp)
	var broken: PackedInt32Array = res.broken
	var damaged: PackedInt32Array = res.damaged
	var bytes := d.damage_bytes(damaged)
	if broken.is_empty():
		if not damaged.is_empty():
			_bc_all("_s_wall_damage", [d.wall_id, damaged, bytes])
		server_fx("chip", point, impulse, 0.5)
		return false
	_bc_all("_s_break", [d.wall_id, broken, point, impulse, damaged, bytes, BREAK_SHATTER])
	_server_check_supports(d)
	return true


## Small unsupported pieces drop right away as one chunk; big ones crumble over time.
func _server_check_supports(d: Destructible) -> void:
	for isl in d.unsupported_islands():
		if isl.size() <= SMALL_ISLAND:
			_server_drop(d, isl)
		elif not _crumbling.has(d):
			_crumbling[d] = now() + 0.4


func _server_drop(d: Destructible, isl: PackedInt32Array) -> void:
	var c := d.island_center(isl)
	_bc_all("_s_break", [d.wall_id, isl, d.global_transform * Vector3(c.x, c.y, 0), Vector3.ZERO, PackedInt32Array(), PackedByteArray(), BREAK_DROP])


func _server_crumble_tick() -> void:
	var t := now()
	for d: Destructible in _crumbling.keys():
		if t < _crumbling[d]:
			continue
		var big := false
		for isl in d.unsupported_islands():
			if isl.size() <= SMALL_ISLAND:
				_server_drop(d, isl)
				continue
			big = true
			# Crumble from the hole edges inward, and let the rest visibly strain.
			var edge := d.edge_cells(isl)
			for k in mini(2, edge.size()):
				var cell := edge[rng.randi() % edge.size()]
				if d.is_alive(cell):
					_server_drop(d, PackedInt32Array([cell]))
			var strained := d.strain(isl, 0.06)
			_bc_all("_s_wall_damage", [d.wall_id, strained, d.damage_bytes(strained)])
			var c := d.island_center(isl)
			server_fx("creak", d.global_transform * Vector3(c.x, c.y, 0), Vector3.UP, 1.0)
		if big:
			_crumbling[d] = t + rng.randf_range(0.3, 0.55)
		else:
			_crumbling.erase(d)


@rpc("authority", "call_remote", "reliable")
func _s_wall_damage(wall_id: int, list: PackedInt32Array, bytes: PackedByteArray) -> void:
	if wall_id < arena.destructibles.size():
		arena.destructibles[wall_id].set_damage(list, bytes)


@rpc("authority", "call_remote", "reliable")
func _s_break(wall_id: int, cells: PackedInt32Array, point: Vector3, impulse: Vector3, damaged: PackedInt32Array, bytes: PackedByteArray, mode: int) -> void:
	if wall_id >= arena.destructibles.size():
		return
	var d := arena.destructibles[wall_id]
	d.set_damage(damaged, bytes)
	var live := PackedInt32Array()
	for i in cells:
		if d.is_alive(i):
			live.append(i)
	if live.is_empty():
		return
	# Remove collision first so fragments don't spawn inside the wall.
	d.remove_cells(live)
	if mode == BREAK_DROP:
		_drop_chunk(d, live, point)
	else:
		_shatter_cells(d, live, point, impulse)
	var snd: String = d.matdef.sound
	Sfx.play3d(snd, point, 4.0, rng.randf_range(0.8, 1.1))
	fx.dust(point, d.color, clampf(live.size() * 0.5, 0.5, 3.0))
	if local_player and local_player.global_position.distance_to(point) < 20.0:
		local_player.shake(0.4 if mode == BREAK_SHATTER else 0.2)


## Breaks cells into impact-biased fragments. Big fragments become networked props the
## gravity gun can use (spawned by the server); small ones are local cosmetic debris.
## Fragment shapes are seeded per cell, so every peer computes the same pieces.
func _shatter_cells(d: Destructible, list: PackedInt32Array, point: Vector3, impulse: Vector3) -> void:
	var local_pt3 := d.to_local2(point)
	var local_pt := Vector2(local_pt3.x, local_pt3.y)
	var basis := d.global_transform.basis.orthonormalized()
	var speed := impulse.length()
	var dir := impulse / speed if speed > 0.1 else -basis.z
	var metric: Vector2 = d.matdef.get("grain", Vector2.ONE)
	var net_spawned := 0
	for i in list:
		var frng := RandomNumberGenerator.new()
		frng.seed = d.wall_id * 100003 + i * 31 + 7
		var near := clampf(1.0 - d.centers[i].distance_to(local_pt) / 2.5, 0.0, 1.0)
		var count := int(round(d.matdef.shatter * (0.5 + near * 1.3)))
		var pieces := Fracture.shatter(d.cells[i], count, frng, local_pt if near > 0.2 else Vector2.INF, metric)
		for piece in pieces:
			var pc := Fracture.centroid(piece)
			var local_poly := Fracture.translated(piece, -pc)
			var pos := d.global_transform * Vector3(pc.x, pc.y, 0.0)
			var away := (pos - point).normalized()
			var vel := dir * speed * frng.randf_range(0.25, 0.6) * (0.4 + near) + away * frng.randf_range(1.0, 4.0) + Vector3.UP * frng.randf_range(0.5, 2.0)
			var spin := Vector3(frng.randf_range(-6, 6), frng.randf_range(-6, 6), frng.randf_range(-6, 6))
			var big := Fracture.area(piece) * d.thickness >= NET_FRAGMENT_VOLUME and d.material != "glass"
			if big and net_spawned < 24:
				net_spawned += 1
				if is_server:
					_spawn_fragment(d, [local_poly], Transform3D(basis, pos), vel, spin)
			else:
				fx.shard(local_poly, d.thickness, Transform3D(basis, pos), vel, spin, d.color, d.material)


## An unsupported group of cells falls as one rigid chunk.
func _drop_chunk(d: Destructible, list: PackedInt32Array, _point: Vector3) -> void:
	if not is_server:
		return
	var c := d.island_center(list)
	var polys := []
	for i in list:
		polys.append(Fracture.translated(d.cells[i], -c))
	var basis := d.global_transform.basis.orthonormalized()
	var spin := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
	_spawn_fragment(d, polys, Transform3D(basis, d.global_transform * Vector3(c.x, c.y, 0.0)), Vector3.DOWN * 0.5, spin)


func _spawn_fragment(d: Destructible, polys: Array, xf: Transform3D, vel: Vector3, spin: Vector3) -> void:
	var extra := {"polys": polys, "t": d.thickness, "mat": d.material}
	var piece := server_spawn_prop("shard", xf, Vector3.ZERO, d.color, 0, vel, extra)
	piece.angular_velocity = spin
	_track_debris(piece)


func _track_debris(piece: Prop) -> void:
	_debris.append(piece.prop_id)
	while _debris.size() > MAX_DEBRIS:
		var old := get_prop(_debris.pop_front())
		if old and old.held_by == 0:
			server_despawn_prop(old)


## A fragment hit hard enough splits again (fractal destruction).
func _server_split_fragment(p: Prop, rel: Vector3) -> void:
	var polys: Array = p.extra.get("polys", [])
	var t: float = p.extra.get("t", 0.5)
	var srng := RandomNumberGenerator.new()
	srng.seed = p.prop_id * 92821
	var out := []
	for poly: PackedVector2Array in polys:
		if Fracture.area(poly) > 0.22:
			var through := Fracture.centroid(poly) + Vector2(srng.randf_range(-0.15, 0.15), srng.randf_range(-0.15, 0.15))
			out.append_array(Fracture.split(poly, through, srng))
		else:
			out.append(poly)
	if out.size() <= 1:
		return
	var xf := p.global_transform
	var vel := p.linear_velocity
	var mat_name: String = p.extra.get("mat", "plaster")
	var col := p.color
	server_despawn_prop(p)
	for poly: PackedVector2Array in out:
		var pc := Fracture.centroid(poly)
		var pos := xf * Vector3(pc.x, pc.y, 0.0)
		var v := vel * 0.6 + (pos - xf.origin).normalized() * srng.randf_range(2.0, 5.0) + rel.normalized() * -2.0
		var local := Fracture.translated(poly, -pc)
		if Fracture.area(poly) * t >= NET_FRAGMENT_VOLUME:
			var piece := server_spawn_prop("shard", Transform3D(xf.basis, pos), Vector3.ZERO, col, 0, v, {"polys": [local], "t": t, "mat": mat_name})
			piece.angular_velocity = Vector3(srng.randf_range(-8, 8), srng.randf_range(-8, 8), srng.randf_range(-8, 8))
			_track_debris(piece)
		else:
			server_fx_shard(local, t, Transform3D(xf.basis, pos), v, col, mat_name)
	server_fx("crack", xf.origin, rel, 1.0)


func server_fx_shard(poly: PackedVector2Array, t: float, xf: Transform3D, vel: Vector3, col: Color, mat_name: String) -> void:
	_bc_all("_s_fx_shard", [poly, t, xf, vel, col, mat_name])


@rpc("authority", "call_remote", "unreliable", 3)
func _s_fx_shard(poly: PackedVector2Array, t: float, xf: Transform3D, vel: Vector3, col: Color, mat_name: String) -> void:
	fx.shard(poly, t, xf, vel, Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), col, mat_name)


# --- Damage, death, respawn -------------------------------------------------------

func server_set_last_attacker(pl: Player, attacker: int) -> void:
	if attacker != 0 and attacker != pl.player_id:
		pl.last_attacker = attacker
		pl.last_attacker_time = now()


func server_damage_player(pl: Player, amount: float, attacker: int, cause: String, point: Vector3, dir: Vector3) -> void:
	if not pl.is_alive() or amount <= 0.0:
		return
	var t := now()
	if attacker == 0 and t - pl.last_attacker_time < 7.0:
		attacker = pl.last_attacker # environmental kills credit whoever sent you there
	server_set_last_attacker(pl, attacker)
	pl.hp -= amount
	_bc_all("_s_hp", [pl.player_id, pl.hp])
	if amount >= 6.0 and cause != "void":
		var n := -dir.normalized() if dir.length() > 0.1 else Vector3.UP
		server_fx("blood", point, dir, clampf(amount / 30.0, 0.3, 2.5), n)
	if pl.hp <= 0.0:
		_server_kill(pl, attacker, cause, dir)


@rpc("authority", "call_remote", "reliable")
func _s_hp(id: int, hp: float) -> void:
	var pl := get_player(id)
	if pl:
		if pl == local_player and hp < pl.hp:
			hud.flash_damage(pl.hp - hp)
		pl.hp = hp


func _server_kill(pl: Player, killer_id: int, cause: String, dir: Vector3) -> void:
	pl.gun.release(false)
	for other: Player in players.values():
		if other.gun.held_kind == GravityGun.Kind.PLAYER and other.gun.held_id == pl.player_id:
			other.gun.release(false)
	pl.deaths += 1
	var killer := get_player(killer_id)
	if killer and killer != pl:
		if are_teammates(killer, pl):
			killer.frags -= 1
		else:
			killer.frags += 1
		server_player_stats(killer)
	elif killer_id == 0 or killer == pl:
		pl.frags -= 1 if cause == "suicide" else 0
	mode_logic.on_kill(pl, killer, cause)
	server_player_stats(pl)
	var vel := pl.velocity + dir.normalized() * minf(dir.length(), 20.0) * 0.4
	_bc_all("_s_died", [pl.player_id, killer_id, cause, vel])
	_respawn_at[pl.player_id] = now() + RESPAWN_TIME


@rpc("authority", "call_remote", "reliable")
func _s_died(id: int, killer_id: int, cause: String, vel: Vector3) -> void:
	var pl := get_player(id)
	if pl == null:
		return
	pl.die(vel)
	Sfx.play3d("death", pl.global_position + Vector3.UP, 0.0, rng.randf_range(0.9, 1.1))
	hud.add_kill(pl, get_player(killer_id), cause)


@rpc("authority", "call_remote", "reliable")
func _s_respawn(id: int, pos: Vector3, yaw: float) -> void:
	var pl := get_player(id)
	if pl:
		pl.respawn(pos, yaw)
		fx.zap(pos + Vector3.UP)
		if pl == local_player:
			Sfx.play_ui("spawn", -6.0)


func server_player_stats(pl: Player) -> void:
	_bc_all("_s_stats", [pl.player_id, pl.frags, pl.deaths, pl.score])


@rpc("authority", "call_remote", "reliable")
func _s_stats(id: int, frags: int, deaths: int, score: int) -> void:
	var pl := get_player(id)
	if pl:
		pl.frags = frags
		pl.deaths = deaths
		pl.score = score
		hud.on_players_changed()


func server_team_scores_changed() -> void:
	_bc_all("_s_team_scores", [team_scores])


@rpc("authority", "call_remote", "reliable")
func _s_team_scores(scores: Dictionary) -> void:
	team_scores = scores
	hud.on_players_changed()


func track_corpse(c: Node) -> void:
	_corpses.append(c)
	while _corpses.size() > MAX_CORPSES:
		var old = _corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()


# --- Player physics events (reported by the controlling peer) ----------------------

func report_self_damage(pl: Player, amount: float, cause: String, point: Vector3, normal: Vector3, vel: Vector3) -> void:
	if is_server:
		_server_self_damage(pl, amount, cause, point, normal, vel)
	else:
		_c_hurt.rpc_id(1, amount, cause, point, normal, vel)


@rpc("any_peer", "call_remote", "reliable")
func _c_hurt(amount: float, cause: String, point: Vector3, normal: Vector3, vel: Vector3) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl:
		_server_self_damage(pl, clampf(amount, 0.0, 1000.0), cause, point, normal, vel)


func _server_self_damage(pl: Player, amount: float, cause: String, point: Vector3, normal: Vector3, vel: Vector3) -> void:
	if not pl.is_alive():
		return
	server_damage_player(pl, amount, 0, cause, point, vel)
	if cause == "impact":
		# Everyone hears and sees a body hitting the scenery.
		server_fx("impact:body", point, vel, clampf(amount / 30.0, 0.2, 3.0), normal)
		var hit_mat := "stone"
		server_fx("impact:" + hit_mat, point, vel, clampf(amount / 40.0, 0.1, 2.5), normal)
	if cause == "impact" and amount > 10.0:
		# Extra splatter onto the surface that was hit.
		server_fx("blood", point, vel, clampf(amount / 25.0, 0.5, 3.0), normal)


func report_break(pl: Player, d: Destructible, _cell: int, point: Vector3, speed: float, vel: Vector3) -> void:
	if is_server:
		server_damage_destructible(d, point, 0.85 + speed * 0.01, speed * 11.0, vel, pl.last_attacker, 4.0)
	else:
		_c_break.rpc_id(1, d.wall_id, point, speed, vel)


@rpc("any_peer", "call_remote", "reliable")
func _c_break(wall_id: int, point: Vector3, speed: float, vel: Vector3) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl == null or wall_id < 0 or wall_id >= arena.destructibles.size():
		return
	if pl.global_position.distance_to(point) > 6.0:
		return
	speed = minf(speed, 80.0)
	server_damage_destructible(arena.destructibles[wall_id], point, 0.85 + speed * 0.01, speed * 11.0, vel, pl.last_attacker, 4.0)


func report_player_bump(pl: Player, other: Player, vel: Vector3) -> void:
	if is_server:
		_server_bump(pl, other, vel)
	else:
		_c_bump.rpc_id(1, other.player_id, vel)


@rpc("any_peer", "call_remote", "reliable")
func _c_bump(other_id: int, vel: Vector3) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	var other := get_player(other_id)
	if pl and other:
		_server_bump(pl, other, vel.limit_length(80.0))


func _server_bump(pl: Player, other: Player, vel: Vector3) -> void:
	if not other.is_alive() or not pl.is_alive():
		return
	var t := now()
	var key := "b%d:%d" % [mini(pl.player_id, other.player_id), maxi(pl.player_id, other.player_id)]
	if t - _pair_cd.get(key, -10.0) < 0.3:
		return
	_pair_cd[key] = t
	var rel := vel - other.velocity
	var speed := rel.length()
	if speed < 7.0:
		return
	# A thrown player is a projectile: credit whoever threw them.
	var credit := pl.player_id
	if pl.state == Player.State.RAGDOLL and t - pl.last_attacker_time < 3.0:
		credit = pl.last_attacker
	server_launch_player(other, rel * 0.75 + Vector3.UP * 3.0, false, 1.2 if speed > 12.0 else 0.0, credit)
	if speed > 10.0:
		server_damage_player(other, (speed - 10.0) * 3.5, credit, "player", other.body_center(), rel)
		server_damage_player(pl, (speed - 10.0) * 1.5, 0, "player", pl.body_center(), -rel)
	server_fx("impact:body", other.body_center(), rel, clampf(speed * speed * Player.MASS / 12000.0, 0.1, 3.0), -rel.normalized())


func report_prop_push(pl: Player, p: Prop, vel: Vector3, point: Vector3) -> void:
	if is_server:
		_server_push(pl, p, vel, point)
	else:
		_c_push.rpc_id(1, p.prop_id, vel, point)


@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _c_push(prop_id: int, vel: Vector3, point: Vector3) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	var p := get_prop(prop_id)
	if pl and p:
		_server_push(pl, p, vel.limit_length(60.0), point)


func _server_push(pl: Player, p: Prop, vel: Vector3, _point: Vector3) -> void:
	if p.freeze or p.held_by != 0:
		return
	var speed := vel.length()
	if speed < 0.5:
		return
	var dir := vel / speed
	var target := speed * (2.0 * Player.MASS / (Player.MASS + p.mass))
	var current := p.linear_velocity.dot(dir)
	if current < target:
		p.linear_velocity += dir * (target - current)
		p.sleeping = false
	if speed > 12.0:
		p.last_thrower = pl.player_id
		p.last_thrown_time = now()
		if p.explosive and speed > 15.0:
			_schedule_explosion(p, 0.0)


# --- Launch / hold (server -> owner) ---------------------------------------------

func server_launch_player(pl: Player, vel: Vector3, replace: bool, ragdoll: float, attacker: int) -> void:
	if not pl.is_alive():
		return
	server_set_last_attacker(pl, attacker)
	_to_owner(pl, "_s_launch", [pl.player_id, vel, replace, ragdoll])


@rpc("authority", "call_remote", "reliable")
func _s_launch(id: int, vel: Vector3, replace: bool, ragdoll: float) -> void:
	var pl := get_player(id)
	if pl and pl.is_controlled_here():
		pl.external_launch(vel, replace, ragdoll)
		if pl == local_player:
			pl.punch(clampf(vel.length() / 25.0, 0.0, 1.2))
			pl.shake(clampf(vel.length() / 40.0, 0.0, 0.7))
			if vel.length() > 18.0:
				hud.yeet_text()


func server_send_held(pl: Player, target: Vector3, holder_vel: Vector3, holder: int) -> void:
	_to_owner(pl, "_s_held", [pl.player_id, target, holder_vel, holder])


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _s_held(id: int, target: Vector3, holder_vel: Vector3, holder: int) -> void:
	var pl := get_player(id)
	if pl and pl.is_controlled_here():
		pl.held_update(target, holder_vel, holder)


func server_release_held(pl: Player, ragdoll: float) -> void:
	_to_owner(pl, "_s_held_release", [pl.player_id, ragdoll])


@rpc("authority", "call_remote", "reliable")
func _s_held_release(id: int, ragdoll: float) -> void:
	var pl := get_player(id)
	if pl and pl.is_controlled_here():
		pl.held_release(ragdoll)


func request_break_free(pl: Player) -> void:
	if is_server:
		_server_break_free(pl)
	else:
		_c_break_free.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _c_break_free() -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl:
		_server_break_free(pl)


func _server_break_free(pl: Player) -> void:
	for other: Player in players.values():
		if other.gun.held_kind == GravityGun.Kind.PLAYER and other.gun.held_id == pl.player_id:
			if are_teammates(other, pl) or rng.randf() < 0.2:
				other.gun.release(false)


# --- Gravity gun ------------------------------------------------------------------

func gun_action(pl: Player, action: int) -> void:
	if is_server:
		pl.gun.server_action(action, pl.eye_position(), pl.aim_direction())
	else:
		_c_gun.rpc_id(1, action, pl.eye_position(), pl.aim_direction())


@rpc("any_peer", "call_remote", "reliable")
func _c_gun(action: int, origin: Vector3, dir: Vector3) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl == null:
		return
	if origin.distance_to(pl.eye_position()) > 4.0:
		origin = pl.eye_position()
	pl.gun.server_action(action, origin, dir)


func server_gun_state_changed(gun: GravityGun) -> void:
	_bc_all("_s_gun", [gun.player.player_id, gun.held_kind, gun.held_id])


@rpc("authority", "call_remote", "reliable")
func _s_gun(id: int, kind: int, target: int) -> void:
	var pl := get_player(id)
	if pl:
		pl.gun.set_visual_state(kind, target)
		if kind != GravityGun.Kind.NONE:
			Sfx.play3d("zap", pl.eye_position(), -4.0, 1.0)


func server_gun_charge(gun: GravityGun, on: bool) -> void:
	_bc_all("_s_gun_charge", [gun.player.player_id, on])


@rpc("authority", "call_remote", "reliable")
func _s_gun_charge(id: int, on: bool) -> void:
	var pl := get_player(id)
	if pl:
		pl.gun.set_charge_visual(on)


func server_gun_kick(pl: Player, amount: float) -> void:
	_to_owner(pl, "_s_kick", [pl.player_id, amount])


@rpc("authority", "call_remote", "reliable")
func _s_kick(id: int, amount: float) -> void:
	var pl := get_player(id)
	if pl:
		pl.gun.kick(amount)


func server_prop_caught(p: Prop, pl: Player) -> void:
	mode_logic.on_prop_caught(p, pl)


func request_spawn_prop(pl: Player, slot: int) -> void:
	if is_server:
		_server_spawn_for(pl, slot)
	else:
		_c_spawn.rpc_id(1, slot)


@rpc("any_peer", "call_remote", "reliable")
func _c_spawn(slot: int) -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl:
		_server_spawn_for(pl, slot)


func _server_spawn_for(pl: Player, slot: int) -> void:
	if not pl.is_alive():
		return
	if not mode_logic.allow_build():
		_to_owner(pl, "_s_msg_local", ["Prop spawning is sandbox-only", Color(1, 0.6, 0.4)])
		return
	var t := now()
	if t - _spawn_cd.get(pl.player_id, -10.0) < 0.3:
		return
	_spawn_cd[pl.player_id] = t
	var kind: String = Prop.SPAWNABLE[clampi(slot, 0, Prop.SPAWNABLE.size() - 1)]
	var size: Vector3 = Prop.DEFS[kind].size
	var dir := pl.aim_direction()
	var pos := pl.eye_position() + dir * (2.0 + size.length())
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pl.eye_position(), pos, Game.L_WORLD | Game.L_PROPS, [pl.get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		pos = hit.position - dir * size.length()
	var p := server_spawn_prop(kind, Transform3D(Basis(Vector3.UP, pl.yaw), pos), Vector3.ZERO, Color(0, 0, 0, 0), 0, pl.velocity * 0.5)
	p.spawned_by = pl.player_id
	var list: Array = _spawned_by.get(pl.player_id, [])
	list.append(p.prop_id)
	while list.size() > MAX_SPAWNED_PER_PLAYER:
		var old := get_prop(list.pop_front())
		if old:
			server_despawn_prop(old)
	_spawned_by[pl.player_id] = list
	server_fx("spawn", pos, Vector3.UP, 1.0)


func request_suicide(pl: Player) -> void:
	if is_server:
		server_damage_player(pl, 1000.0, pl.player_id, "suicide", pl.body_center(), Vector3.UP * 12.0)
	else:
		_c_suicide.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _c_suicide() -> void:
	var pl := get_player(multiplayer.get_remote_sender_id())
	if pl:
		server_damage_player(pl, 1000.0, pl.player_id, "suicide", pl.body_center(), Vector3.UP * 12.0)


# --- Effects & messages -----------------------------------------------------------

func server_fx(kind: String, pos: Vector3, dir: Vector3, amount: float, normal := Vector3.UP) -> void:
	_bc_all("_s_fx", [kind, pos, dir, amount, normal])


@rpc("authority", "call_remote", "unreliable", 3)
func _s_fx(kind: String, pos: Vector3, dir: Vector3, amount: float, normal: Vector3) -> void:
	if kind.begins_with("impact:"):
		var mat_name := kind.substr(7)
		fx.impact(pos, normal, amount, mat_name)
		Sfx.impact(mat_name, pos, amount)
		if local_player and amount > 0.6:
			var d := local_player.global_position.distance_to(pos)
			local_player.shake(clampf(amount * 0.35 - d / 30.0, 0.0, 0.8))
			if d < 6.0:
				local_player.punch(clampf(amount * 0.3, 0.0, 0.6))
		return
	match kind:
		"blood":
			fx.blood(pos, normal, dir, amount)
			Sfx.play3d("splat", pos, -2.0 + amount * 2.0, rng.randf_range(0.8, 1.2))
		"explosion":
			fx.explosion(pos, amount)
			Sfx.play3d("boom", pos, 6.0, rng.randf_range(0.8, 1.0))
			if local_player:
				var d := local_player.global_position.distance_to(pos)
				local_player.shake(clampf(1.2 - d / 25.0, 0.0, 1.0))
		"punt":
			fx.shockwave(pos, dir)
			Sfx.play3d("punt", pos, 0.0, rng.randf_range(0.9, 1.1))
		"throw":
			Sfx.play3d("throw", pos, -2.0 + amount * 3.0, rng.randf_range(0.9, 1.2) / maxf(amount * 0.8, 1.0))
			if amount > 1.4:
				# Charged yeet: a deep whump and a shockwave off the muzzle.
				Sfx.play3d("punt", pos, 2.0, 0.75)
				fx.shockwave(pos, dir, Color(1.0, 0.95, 0.85))
		"zap":
			fx.zap(pos)
		"hit":
			fx.puff(pos, -dir.normalized())
			Sfx.play3d("hit", pos, -10.0 + amount * 8.0, rng.randf_range(0.7, 1.2) / maxf(amount, 0.5))
		"boing":
			Sfx.play3d("boing", pos, -10.0 + amount * 8.0, rng.randf_range(0.9, 1.3))
		"chip":
			fx.puff(pos, -dir.normalized(), Arena.C_BREAK)
			Sfx.play3d("hit", pos, -6.0, 0.6)
		"spawn":
			fx.zap(pos)
			Sfx.play3d("spawn", pos, -4.0)
		"pumpkin":
			fx.pumpkin_burst(pos, dir, amount > 1.5)
			Sfx.play3d("squelch", pos, 2.0, rng.randf_range(0.85, 1.1))
			if local_player and local_player.global_position.distance_to(pos) < 12.0:
				local_player.shake(0.3)
		"pickup":
			Sfx.play3d("pickup", pos, -4.0, rng.randf_range(0.9, 1.3))
			fx.zap(pos)
		"creak":
			Sfx.play3d("creak", pos, 2.0, rng.randf_range(0.7, 1.1))
			fx.dust(pos, Color(0.9, 0.85, 0.8), 0.4)
		"crack":
			Sfx.play3d("crack", pos, 0.0, rng.randf_range(1.0, 1.3))
		"score":
			fx.explosion(pos + Vector3.UP * 2.0, 3.0)
			Sfx.play_ui("score", 0.0)


func local_blood(pos: Vector3, normal: Vector3, dir: Vector3, amount: float) -> void:
	fx.blood(pos, normal, dir, amount)


func server_message(text: String, color := Color.WHITE, big := false) -> void:
	_bc_all("_s_msg", [text, color, big])


@rpc("authority", "call_remote", "reliable")
func _s_msg(text: String, color: Color, big: bool) -> void:
	hud.show_message(text, color, big)


@rpc("authority", "call_remote", "reliable")
func _s_msg_local(text: String, color: Color) -> void:
	hud.show_message(text, color, false)
