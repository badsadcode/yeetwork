extends Node
## Gameplay smoke tests driven through the real player/gravity-gun code.
## Run: godot --headless -- --host --map prime --bots 0 --test

var world: Node
var pl: Player
var results: Array[String] = []
var failures := 0


class ScriptedBrain:
	## Stand-in brain: tests set cmd/yaw directly; this just keeps jump_pressed one-shot.
	var pl: Player
	var pending_jump := false
	func think(_d: float) -> void:
		pl.cmd.jump_pressed = pending_jump
		pending_jump = false


var brain := ScriptedBrain.new()


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	pl = world.local_player
	pl.is_bot = true # hand control to the scripted brain
	brain.pl = pl
	pl.bot_brain = brain
	await _run()
	print("\n==== TEST RESULTS ====")
	for r in results:
		print(r)
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s  (%s)" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		failures += 1


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func reset(pos: Vector3, yaw: float) -> void:
	# A death in an earlier test schedules a server respawn; it must not fire mid-test.
	world._respawn_at.erase(pl.player_id)
	pl.respawn(pos, yaw)
	pl.cmd.move = Vector2.ZERO
	pl.cmd.jump = false
	pl.cmd.crouch = false
	pl.cmd.run = true
	await ticks(10)


func _run() -> void:
	# 1. Ground speed.
	await reset(Vector3(-50, 0.2, -24), -PI * 0.5)
	pl.cmd.move = Vector2(0, 1)
	await ticks(150)
	check("ground run speed", absf(pl.horizontal_speed() - Player.MAX_SPEED) < 0.6, "%.2f m/s" % pl.horizontal_speed())

	# 1b. Walking: slower, and crouching while walking doesn't slide.
	await reset(Vector3(-50, 0.2, -24), -PI * 0.5)
	pl.cmd.run = false
	pl.cmd.move = Vector2(0, 1)
	await ticks(120)
	var walk := pl.horizontal_speed()
	check("walk speed", absf(walk - Player.WALK_SPEED) < 0.6, "%.2f m/s" % walk)
	pl.cmd.crouch = true
	await ticks(5)
	check("no slide while walking", not pl.sliding, "%.1f m/s" % pl.horizontal_speed())
	pl.cmd.crouch = false
	pl.cmd.run = true

	# 2. Bunny hop + air strafe gains speed.
	await reset(Vector3(-55, 0.2, -24), -PI * 0.5)
	pl.cmd.move = Vector2(0, 1)
	await ticks(60)
	pl.cmd.jump = true
	var side := 1.0
	var max_speed := 0.0
	var last_ground := true
	for i in 300:
		var grounded := pl.is_on_floor()
		if grounded and not last_ground:
			side = -side
		last_ground = grounded
		var v := Vector3(pl.velocity.x, 0, pl.velocity.z)
		if not grounded and v.length() > 1.0:
			# Strafe-only, wish direction just under 90 degrees from velocity.
			var vdir := v.normalized()
			var wish := vdir.rotated(Vector3.UP, -side * (PI * 0.5 + 0.02))
			# For move = (side, 0) the wish dir is basis.x * side.
			var bx := wish * side
			pl.yaw = atan2(-bx.z, bx.x)
			pl.cmd.move = Vector2(side, 0)
		else:
			pl.cmd.move = Vector2(0, 1)
		await ticks(1)
		max_speed = maxf(max_speed, pl.horizontal_speed())
	pl.cmd.jump = false
	check("bhop/strafe gains speed", max_speed > Player.MAX_SPEED + 2.0, "max %.2f m/s" % max_speed)

	# 3. Slide boost.
	await reset(Vector3(-50, 0.2, -24), -PI * 0.5)
	pl.cmd.move = Vector2(0, 1)
	await ticks(120)
	var before := pl.horizontal_speed()
	pl.cmd.crouch = true
	await ticks(3)
	var boosted := pl.horizontal_speed()
	await ticks(60)
	var after := pl.horizontal_speed()
	check("slide boost", pl.sliding or after > 6.0, "%.1f -> %.1f -> %.1f m/s" % [before, boosted, after])
	check("slide keeps momentum", boosted > before + 2.0 and after > 7.0, "boost %.1f, after 1 s %.1f" % [boosted, after])
	pl.cmd.crouch = false

	# 4. Wall run along the breakable lane wall (south face at z = -20.4).
	await reset(Vector3(2, 0.2, -21.4), -PI * 0.5 - 0.04)
	pl.cmd.move = Vector2(0, 1)
	await ticks(80)
	brain.pending_jump = true
	var ran := 0
	for i in 70:
		await ticks(1)
		if pl.wallrunning:
			ran += 1
	check("wall run", ran > 15, "%d ticks wall running" % ran)

	# 5. Grab and throw a crate.
	await reset(Vector3(-50, 0.2, 0), -PI * 0.5)
	pl.pitch = -0.2
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, pl.eye_position() + pl.aim_direction() * 3.0))
	await ticks(5)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await ticks(20)
	check("grab crate", pl.gun.held_kind == GravityGun.Kind.PROP and pl.gun.held_id == crate.prop_id, "held kind %d" % pl.gun.held_kind)
	world.gun_action(pl, GravityGun.Action.THROW)
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await ticks(2)
	var tap_speed := crate.linear_velocity.length()
	check("throw crate", tap_speed > 20.0, "%.1f m/s" % tap_speed)
	world.gun_action(pl, GravityGun.Action.GRAB_END)

	# 5b. Charged throw: hold for a full charge, release, much faster than a tap.
	await reset(Vector3(-50, 0.2, 0), -PI * 0.5)
	pl.pitch = -0.2
	var crate2: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, pl.eye_position() + pl.aim_direction() * 3.0))
	await ticks(5)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await ticks(20)
	world.gun_action(pl, GravityGun.Action.THROW)
	await ticks(70)
	var was_charging := pl.gun.visual_charge() > 0.9
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await ticks(2)
	var charged_speed := crate2.linear_velocity.length() if is_instance_valid(crate2) else 0.0
	check("charged throw", was_charging and charged_speed > tap_speed * 1.5, "tap %.1f m/s, charged %.1f m/s" % [tap_speed, charged_speed])
	world.gun_action(pl, GravityGun.Action.GRAB_END)

	# 5c. Push/pull and rotate a held crate.
	await reset(Vector3(-50, 0.2, 0), -PI * 0.5)
	pl.pitch = 0.0
	var crate3: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, pl.eye_position() + pl.aim_direction() * 3.0))
	await ticks(5)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await ticks(30)
	var near_d := pl.eye_position().distance_to(crate3.global_position)
	var yaw_before := crate3.global_transform.basis.get_euler().y
	world.gun_adjust(pl, 3.0, PI * 0.5, 0.0)
	await ticks(60)
	var far_d := pl.eye_position().distance_to(crate3.global_position)
	var turned := absf(wrapf(crate3.global_transform.basis.get_euler().y - yaw_before, -PI, PI))
	check("push held object farther", far_d > near_d + 2.0, "%.1f m -> %.1f m" % [near_d, far_d])
	check("rotate held object", absf(turned - PI * 0.5) < 0.35, "turned %.0f degrees" % rad_to_deg(turned))
	world.gun_adjust(pl, -3.0, 0.0, 0.0)
	await ticks(60)
	check("pull held object closer", pl.eye_position().distance_to(crate3.global_position) < far_d - 2.0, "%.1f m" % pl.eye_position().distance_to(crate3.global_position))
	world.gun_action(pl, GravityGun.Action.GRAB_END)

	# 6. Pull from range.
	await reset(Vector3(45, 0.2, -24), PI * 0.5)
	var far: Prop = world.server_spawn_prop("ball", Transform3D(Basis.IDENTITY, Vector3(30, 0.5, -24)))
	await ticks(40)
	var to := far.global_position - pl.eye_position()
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await ticks(90)
	check("pull and catch from range", pl.gun.held_kind == GravityGun.Kind.PROP and pl.gun.held_id == far.prop_id, "distance now %.1f" % pl.eye_position().distance_to(far.global_position))
	world.gun_action(pl, GravityGun.Action.GRAB_END)

	# 7. Gravity jump: punt a wall right in front of you (outer wall at x = -64).
	await reset(Vector3(-61.5, 0.2, 30), PI * 0.5)
	pl.pitch = 0.0
	await ticks(5)
	world.gun_action(pl, GravityGun.Action.THROW)
	await ticks(2)
	check("gravity jump off wall", pl.velocity.x > 8.0, "vel %s" % pl.velocity.snapped(Vector3.ONE * 0.1))

	# 8. Smash through a breakable wall by being launched into it.
	var broken_before := 0
	for w in world.arena.destructibles:
		broken_before += w.broken_cells.size()
	await reset(Vector3(25, 2.5, -27), 0.0)
	pl.external_launch(Vector3(0, 3, 28), true, 1.0)
	await ticks(60)
	var broken_after := 0
	for w in world.arena.destructibles:
		broken_after += w.broken_cells.size()
	check("player smashes wall", broken_after > broken_before, "%d -> %d broken cells, hp %.0f" % [broken_before, broken_after, pl.hp])

	# 9. Explosive barrel goes boom on hard impact.
	await reset(Vector3(-50, 0.2, 0), -PI * 0.5)
	var barrel: Prop = world.server_spawn_prop("boom_barrel", Transform3D(Basis.IDENTITY, Vector3(-40, 4, 8)))
	var bid := barrel.prop_id
	await ticks(3)
	barrel.linear_velocity = Vector3(0, -25, 0)
	await ticks(40)
	check("barrel explodes", world.get_prop(bid) == null, "prop still exists: %s" % (world.get_prop(bid) != null))

	# 10. Grab and throw another player.
	await reset(Vector3(-50, 0.2, 0), -PI * 0.5)
	pl.pitch = -0.15
	world._server_add_bot()
	var victim: Player = null
	for p: Player in world.players.values():
		if p != pl:
			victim = p
	victim.bot_brain = null
	victim.respawn(pl.global_position + Vector3(3.0, 0, 0), 0.0)
	await ticks(10)
	world.gun_action(pl, GravityGun.Action.GRAB_START)
	await ticks(15)
	var was_held := victim.state == Player.State.HELD
	world.gun_action(pl, GravityGun.Action.THROW)
	world.gun_action(pl, GravityGun.Action.THROW_RELEASE)
	await ticks(3)
	check("grab player", was_held, "state %d" % victim.state)
	check("throw player", victim.velocity.length() > 20.0 and victim.state == Player.State.RAGDOLL, "vel %.1f state %d" % [victim.velocity.length(), victim.state])
	world.gun_action(pl, GravityGun.Action.GRAB_END)

	# 11. Fall damage from height.
	# Clear any debris from earlier tests under the drop point first.
	for p: Prop in world.props.values():
		if is_instance_valid(p) and Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(-40, 25)) < 4.0:
			world.server_despawn_prop(p)
	await reset(Vector3(-40, 40, 25), 0.0)
	var deaths_before := pl.deaths
	await ticks(150)
	# A 40 m drop leaves a few hp (a death counts too).
	check("fall damage", pl.hp < 100.0 or pl.deaths > deaths_before, "hp %.0f, deaths +%d" % [pl.hp, pl.deaths - deaths_before])

	# 12. CTF capture: drop the blue flag on the red stand while red's flag is home.
	if world.mode == Game.Mode.CTF:
		var ctf := world.mode_logic as ModeCTF
		var blue := world.get_prop(ctf.flags[Game.TEAM_BLUE]) as Prop
		var red_stand: Vector3 = world.arena.flag_pos(Game.TEAM_RED)
		var before_score: int = world.team_scores.get(Game.TEAM_RED, 0)
		blue.global_position = red_stand + Vector3(0.5, 1.25, 0)
		blue.linear_velocity = Vector3.ZERO
		await ticks(10)
		check("ctf capture", world.team_scores.get(Game.TEAM_RED, 0) == before_score + 1, "red score %d" % world.team_scores.get(Game.TEAM_RED, 0))
		check("ctf flag returned home", blue.global_position.distance_to(world.arena.xf_world(blue.home_transform).origin) < 1.0, "flag at %s" % blue.global_position.snapped(Vector3.ONE * 0.1))

	# 13. Props shatter: a crate hurled at a wall bursts into board fragments. Count only
	# fragments newer than the crate (the debris cap may remove older ones meanwhile).
	var box: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(-58, 2.0, 30)))
	var box_id := box.prop_id
	await ticks(2)
	box.linear_velocity = Vector3(-40, 0, 0)
	await ticks(30)
	var boards := 0
	for p: Prop in world.props.values():
		if is_instance_valid(p) and p.kind == "shard" and p.prop_id > box_id:
			boards += 1
	check("crate shatters into boards", world.get_prop(box_id) == null and boards > 0, "crate gone: %s, new board props %d" % [world.get_prop(box_id) == null, boards])

	await _water_tests()
	_controls_test()


## Rebinding: swap the mouse buttons, save, reset, load back (a scratch ConfigFile, so the
## player's own settings are never touched).
func _controls_test() -> void:
	var grab0 := Controls.key_of("gun_grab")
	var throw0 := Controls.key_of("gun_throw")
	Controls.swap_mouse_buttons()
	var cfg := ConfigFile.new()
	Controls.save(cfg)
	Controls.reset_all()
	var reset_ok := Controls.key_of("gun_grab") == grab0
	Controls.init(cfg)
	var swapped := Controls.key_of("gun_grab") == throw0 and Controls.key_of("gun_throw") == grab0
	var k := InputEventKey.new()
	k.physical_keycode = KEY_G
	Controls.rebind("freeze_prop", k)
	var rebound := Controls.key_of("freeze_prop") == "G" and Controls.pad_of("freeze_prop") != "-"
	Controls.reset_all()
	check("controls: swap, save, reset, load, rebind", reset_ok and swapped and rebound, "grab %s -> %s, freeze rebound to G: %s" % [grab0, throw0, rebound])


## A concrete tub of water (surface at y -0.4, floor at -3) off to the side of the map.
func _build_pool(c: Vector3) -> Liquid:
	var arena: Arena = world.arena
	arena.box(c + Vector3(0, -3.5, 0), Vector3(16, 1, 12), Color.GRAY)
	arena.box(c + Vector3(-8.5, -1.5, 0), Vector3(1, 5, 12), Color.GRAY)
	arena.box(c + Vector3(8.5, -1.5, 0), Vector3(1, 5, 12), Color.GRAY)
	arena.box(c + Vector3(0, -1.5, -6.5), Vector3(18, 5, 1), Color.GRAY)
	arena.box(c + Vector3(0, -1.5, 6.5), Vector3(18, 5, 1), Color.GRAY)
	var l := Liquid.create("water", c + Vector3(0, -0.4, 0), Vector3(16, 3.2, 12))
	arena.add_child(l)
	return l


func _water_tests() -> void:
	var pool := _build_pool(Vector3(300, 0, 0))
	await ticks(5)

	# 14. Swimming: idle in deep water you float with your head out; holding jump rises.
	await reset(Vector3(300, -2.6, 0), 0.0)
	await ticks(240)
	var surf := pool.height_at(pl.global_position.x, pl.global_position.z)
	var eye_above := pl.eye_position().y - surf
	check("player floats in water", eye_above > -0.2 and eye_above < 0.9 and absf(pl.velocity.y) < 2.0, "eyes %.2f m above the surface, vy %.1f" % [eye_above, pl.velocity.y])
	await reset(Vector3(300, -2.6, 0), 0.0)
	pl.cmd.jump = true
	var y0 := pl.global_position.y
	await ticks(30)
	pl.cmd.jump = false
	check("hold jump to swim up", pl.global_position.y > y0 + 0.6, "rose %.2f m in 0.5 s" % (pl.global_position.y - y0))

	# 15. Water jump: swim at the surface into the pool wall and climb out.
	await reset(Vector3(300, -2.6, 0), -PI * 0.5) # facing +x, wall at x = 307.5
	await ticks(120)
	pl.cmd.move = Vector2(0, 1)
	pl.cmd.jump = true
	var out := false
	for i in 300:
		await ticks(1)
		if pl.global_position.y > 0.9 and pl.is_on_floor():
			out = true
			break
	pl.cmd.move = Vector2.ZERO
	pl.cmd.jump = false
	check("climb out of a pool", out, "ended at %s" % pl.global_position.snapped(Vector3.ONE * 0.1))

	# 16. Props: wood and rubber float, metal sinks.
	var crate: Prop = world.server_spawn_prop("crate", Transform3D(Basis.IDENTITY, Vector3(297, 1.5, -2)))
	var ball: Prop = world.server_spawn_prop("beachball", Transform3D(Basis.IDENTITY, Vector3(300, 1.5, -3)))
	var anvil: Prop = world.server_spawn_prop("anvil", Transform3D(Basis.IDENTITY, Vector3(303, 1.5, 3)))
	await ticks(300)
	var cy := crate.global_position.y - pool.height_at(crate.global_position.x, crate.global_position.z)
	var by := ball.global_position.y - pool.height_at(ball.global_position.x, ball.global_position.z)
	check("crate floats", absf(cy) < 0.6, "crate centre %.2f m from the surface" % cy)
	check("beach ball floats", by > -0.4 and by < 0.8, "ball centre %.2f m from the surface" % by)
	check("anvil sinks", anvil.global_position.y < -2.5, "anvil at y %.2f (pool floor -3)" % anvil.global_position.y)

	# 17. The open ocean is too rough to swim: you sink and drown.
	var sea := Liquid.create("water", Vector3(-300, 0, 0), Vector3(40, 40, 40))
	sea.ocean = true
	world.arena.add_child(sea)
	await ticks(5)
	var deaths := pl.deaths
	await reset(Vector3(-300, -1.0, 0), 0.0)
	var drowned := false
	for i in 600:
		await ticks(1)
		if not pl.is_alive():
			drowned = true
			break
	check("drown in the ocean", drowned and pl.deaths == deaths + 1, "alive %s, depth %.1f m" % [pl.is_alive(), -pl.global_position.y])
