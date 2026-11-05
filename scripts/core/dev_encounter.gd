extends Node
## Developer check for Encounter (a set-piece fight), on the test adventure The Cellar: nothing
## until a Yeet walks in; the rifts open, the monsters come and hunt them and bite; a fallen Yeet is
## out for longer; everyone down: back at the start, the monsters gone, the rifts shut, and it can
## be set off again by walking in; waves one after another; on once they're all dead, opening the
## door. The second fight: a checkpoint; monsters let out of a cage by a door that opens after the
## fight's map was made; heading for a Goal and waiting there, chasing only Yeets they can see;
## a boss and its bar; monsters of the map's own; one with nowhere to go doesn't hold it up; down
## here, back at the checkpoint and it starts by itself. With --with-client: the same over the
## network (run dev_encounterclient on each of two clients, the second joining mid-fight).
## Screenshots. Exits 1 if a step fails.
## Usage: godot -- --host --map res://adventures/the_cellar.adventure.tres --mode adventure --spooky off --tour <dir> --tour-mode encounter

var world: Node
var out_dir := ""
var _failed := 0
var _top_up := false


func _ready() -> void:
	get_tree().create_timer(140.0).timeout.connect(func():
		print("ENCOUNTER CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	if OS.get_cmdline_user_args().has("--with-client"):
		await _with_client(pl)
		return
	_map_check()
	var mode := world.mode_logic as ModeAdventure
	var fight: Encounter = _named("Fight")
	var horde: Horde = world.horde
	var north: MonsterSpawn = _spawn("RiftNorth")
	await _wait(0.5)
	_check("a level with a fight has monsters to run, and flashlights", horde != null and world.arena.flashlights, "")
	_check("nothing yet: no fight, no monsters, the rifts out of sight, the door shut", mode._fight == null and horde.count() == 0 and not north.visible and not _named("WayOn").active, "")
	await _wait(3.5)
	await _shot("e01_before")
	# In it comes.
	_put(pl, _named("TheyWake").global_position + Vector3.UP * 0.2, PI * 0.5)
	await _until(func(): return mode._fight == fight and north.visible, 2.0)
	_check("a Yeet walks in: the fight's on, on every screen, its rifts open", mode._fight == fight and north.visible and int(world.mode_state.get("fight", -1)) == fight.puzzle_index, "%s" % [world.mode_state])
	_check("... a fallen Yeet's out for longer while it's on", is_equal_approx(mode.respawn_scale() * World.RESPAWN_TIME, fight.respawn_after), "%.1f" % mode.respawn_scale())
	await _until(func(): return horde.count() >= 3, 6.0)
	_check("... the monsters come through", horde.count() >= 3, "%d" % horde.count())
	await _wait(0.1)
	_check("... the HUD says how many", world.hud._objective_plate.visible and world.hud._objective.text.contains("left"), world.hud._objective.text)
	var hp0: float = pl.hp
	await _until(func(): return pl.hp < hp0, 14.0)
	_check("... they hunt the Yeet down and bite", pl.hp < hp0, "hp %d" % pl.hp)
	await _shot("e02_fight")
	# Everyone down.
	world.server_damage_player(pl, 9999.0, 0, "monster", pl.body_center(), Vector3.UP)
	await _wait(0.3)
	_check("everyone down: not over till it's said so", not pl.is_alive() and mode._wiped_at >= 0.0, "")
	await _until(func(): return mode._fight == null and pl.is_alive(), 5.0)
	await _wait(0.4)
	_check("... back at the start, alive, the monsters gone, the rifts shut", pl.is_alive() and pl.global_position.x < -8.0 and horde.count() == 0 and not north.visible and mode._fight == null, "%s, %d monsters" % [pl.global_position, horde.count()])
	_check("... the zone that set it off is off, and the fight isn't won", not _named("TheyWake").active and not fight.active, "")
	await _wait(fight.restart_after + 1.0)
	_check("... nobody in the zone, it doesn't start again", mode._fight == null, "")
	_put(pl, _named("TheyWake").global_position + Vector3.UP * 0.2, PI * 0.5)
	await _until(func(): return mode._fight == fight and horde.count() >= 2, 5.0)
	_check("... walk in again: it starts again, from the first wave", mode._fight == fight and fight.wave == 1, "wave %d" % fight.wave)
	# A real kill, then through the waves.
	_top_up = true
	_keep_alive(pl)
	var m0: int = mode._monsters
	var one = horde.monsters[0]
	world.server_explode_at(one.pos + Vector3.UP * 0.5, 2.5, pl.player_id)
	await _wait(0.5)
	_check("a blast kills them, and it's counted", mode._monsters > m0, "%d" % mode._monsters)
	await _until(func():
		if fight.wave == 2: # (before finishing anything off: it may be the second wave's first)
			return true
		_finish_off(horde)
		return false, 12.0)
	_check("wave one dead: the second comes", fight.wave == 2 and not fight.active and int(world.mode_state.get("wave", 0)) >= 1, "wave %d" % fight.wave)
	# A ghost goes through anything to get to you: walled off from it, it still comes.
	await _until(func(): return horde.monsters.any(func(m): return m.def.has("ghost")), 6.0)
	var ghosts: Array = horde.monsters.filter(func(m): return m.def.has("ghost"))
	var ghost = ghosts[0] if not ghosts.is_empty() else null
	_check("a ghost in the second wave", ghost != null, "")
	if ghost:
		_put(pl, Vector3(15, 0.2, 5), 0.0) # (the next room, the door shut; clear of its zone)
		await _wait(1.5)
		var d0: float = ghost.pos.distance_to(pl.global_position)
		await _until(func(): return ghost.pos.distance_to(pl.global_position) < d0 - 3.0, 6.0)
		_check("... it comes through the wall for the Yeet", ghost.pos.distance_to(pl.global_position) < d0 - 3.0, "%.1f m, then %.1f" % [d0, ghost.pos.distance_to(pl.global_position)])
		_put(pl, _named("TheyWake").global_position + Vector3.UP * 0.2, PI * 0.5)
	await _until(func():
		_finish_off(horde)
		return fight.active, 15.0)
	_check("all dead: it's on, the fight's over", fight.active and mode._fight == null, "")
	await _wait(1.5)
	_check("... the door it was wired to opens, the rifts shut, the HUD clear", _named("WayOn").active and not north.visible and not world.hud._objective.text.contains("left"), world.hud._objective.text)
	# The second fight.
	var boss_fight: Encounter = _named("BossFight")
	_put(pl, _named("HalfWay").global_position + Vector3.UP * 0.2, PI * 0.5)
	await _until(func(): return _named("HalfWay").active and mode._fight == boss_fight, 3.0)
	_check("the next room: a checkpoint, and the second fight", _named("HalfWay").active and mode._fight == boss_fight, "")
	_put(pl, Vector3(2.5, 0.2, -6.5), 0.0) # (behind a wall: out of sight, not in line with the door for the Ram)
	var cage: MonsterSpawn = _spawn("RiftCage")
	await _until(func(): return boss_fight.boss != null and horde.count() >= 3, 8.0)
	_check("... a boss, with the health the wave gives it", boss_fight.boss != null and is_equal_approx(boss_fight.boss.max_hp, 450.0), "%s" % [boss_fight.boss.max_hp if boss_fight.boss else 0.0])
	_check("... monsters of the map's own come too", horde.monsters.any(func(m): return horde.types.has(m.kind) and (horde.types[m.kind] as MonsterType).display_name == "Dust Bunny"), "%s" % [horde.types.keys()])
	await _wait(0.6)
	_check("... the HUD shows the boss", world.hud._boss_bar.visible and world.hud._boss_label.text.contains("WRECKING RAM"), world.hud._boss_label.text)
	var spot: Vector3 = (world.arena.get_node("TheCellar/WhereTheyGo") as Node3D).global_position if world.arena.has_node("TheCellar/WhereTheyGo") else boss_fight._goal_node().global_position
	var at_goal := func() -> bool:
		for m in horde.monsters:
			if horde.types.has(m.kind) and Vector2(m.pos.x - spot.x, m.pos.z - spot.z).length() < 3.0:
				return true
		return false
	await _until(at_goal, 20.0)
	_check("... let out of the cage by a door opened after the map was made, they make for the Goal", at_goal.call() and cage.visible, "%s" % [horde.monsters.map(func(m): return m.pos)])
	var waiting: int = horde.count()
	await _wait(1.5)
	_check("... and wait there: getting there doesn't use them up", horde.count() >= waiting and boss_fight.boss.hp > 0.0, "%d, then %d" % [waiting, horde.count()])
	# Behind a wall they don't see you; in the open they do.
	await _wait(0.1)
	var seers: Array = horde.monsters.filter(func(m): return horde.types.has(m.kind))
	var seer = seers[0] if not seers.is_empty() else null
	# (from the Goal: one that's wandered to the open door really can see them)
	var seen := true
	if seer:
		var was: Vector3 = seer.pos
		seer.pos = spot
		seen = horde._can_see(seer, pl)
		seer.pos = was
	_check("... a Yeet behind a wall isn't seen", seer != null and not seen, "seer %s, Yeet at %s, from %s" % [seer != null, pl.global_position, spot])
	_put(pl, spot + Vector3(-2.5, 0.2, 2.5), 0.0)
	await _until(func(): return horde.monsters.any(func(m): return m.chase == pl), 2.0)
	_check("... one in the open is, and gets chased", horde.monsters.any(func(m): return m.chase == pl), "")
	await _shot("e03_boss")
	# One with nowhere to go can't hold the fight up.
	var stray: Variant = horde.server_spawn(Vector3(25, 0, 0), "shambler")
	stray.pos = Vector3(25, 0, 0)
	stray.lost = Horde.LOST_AFTER - 1.5
	await _until(func(): return horde.get_monster(stray.id) == null, 4.0)
	_check("one shut in with no way out goes in the end", horde.get_monster(stray.id) == null, "")
	# Down here: back at the checkpoint, and it starts by itself (the zone's where they land).
	_top_up = false
	await _wait(0.1)
	world.server_damage_player(pl, 9999.0, 0, "monster", pl.body_center(), Vector3.UP)
	await _until(func(): return mode._fight == null and pl.is_alive(), 5.0)
	var by: float = pl.global_position.distance_to(_named("HalfWay").global_position)
	_check("everyone down after a checkpoint: back at the checkpoint", pl.is_alive() and by < 5.0 and horde.count() == 0, "%.1f m away" % by)
	await _until(func(): return mode._fight == boss_fight, boss_fight.restart_after + 3.0)
	_check("... standing in its zone, it starts again by itself", mode._fight == boss_fight, "")
	_top_up = true
	_keep_alive(pl)
	await _until(func():
		_finish_off(horde)
		return boss_fight.active, 15.0)
	_check("the last of them: it's on, the way out opens", boss_fight.active, "")
	await _wait(2.0)
	_check("... the way out's open", _named("WayOut").active, "")
	var exit: PuzzleExit = _named("Exit")
	_put(pl, exit.global_position + Vector3.UP * 0.2, 0.0)
	await _until(func(): return world.hud._results != null, 4.0)
	var beaten: Array = mode.results(1.0).stats.filter(func(s): return s[0] == "Monsters beaten")
	_check("the end screen counts them", world.hud._results != null and not beaten.is_empty(), "%s" % [beaten])
	print("ENCOUNTER CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## What the map check says about a badly made one.
func _map_check() -> void:
	var e := Encounter.new()
	e.name = "Bad"
	var says := e.problems()
	_check("the map check: no waves", says.any(func(s): return s.contains("no waves")), "%s" % [says])
	var w := EncounterWave.new()
	e.waves = [w]
	says = e.problems()
	_check("... a wave that brings nothing", w.total() == 0 and says.any(func(s): return s.contains("brings nothing")), "%s" % [says])
	e.free()
	var fine: Array = (_named("Fight") as Encounter).problems() + (_named("BossFight") as Encounter).problems()
	_check("... and nothing to say about The Cellar's", fine.is_empty(), "%s" % [fine])


## The host's side of the network check.
func _with_client(pl: Player) -> void:
	for k in 300:
		await _wait(0.1)
		if world.players.size() >= 2:
			break
	await _wait(1.5)
	var mode := world.mode_logic as ModeAdventure
	var fight: Encounter = _named("Fight")
	var horde: Horde = world.horde
	_top_up = true
	_keep_alive(pl)
	_put(pl, _named("TheyWake").global_position + Vector3.UP * 0.2, 0.0)
	await _until(func(): return horde.count() >= 3, 8.0)
	await _wait(2.0) # (the client looks)
	_top_up = false
	await _wait(0.1)
	world.server_damage_player(pl, 9999.0, 0, "monster", pl.body_center(), Vector3.UP)
	await _wait(0.4)
	_check("one down, a friend still up: the fight goes on", mode._fight == fight and mode._wiped_at < 0.0, "")
	for q: Player in world.players.values():
		if q.is_alive():
			world.server_damage_player(q, 9999.0, 0, "monster", q.body_center(), Vector3.UP)
	await _until(func(): return mode._fight == null, 5.0)
	await _wait(0.5)
	_check("the friend down too: both back, the monsters gone", mode._fight == null and horde.count() == 0 and world.players.values().all(func(q): return q.is_alive()), "%d" % horde.count())
	await _wait(fight.restart_after + 0.5)
	_top_up = true
	_keep_alive(pl)
	_put(pl, _named("TheyWake").global_position + Vector3.UP * 0.2, 0.0)
	await _until(func(): return mode._fight == fight and horde.count() >= 2, 6.0)
	_check("walked into again, it starts again", mode._fight == fight, "")
	# The first client goes, the second joins with the fight on (at least one monster stays).
	for pass_n in 2:
		for k in 400:
			await _wait(0.1)
			if world.players.size() == (1 if pass_n == 0 else 2):
				break
	await _wait(3.0)
	await _until(func():
		_finish_off(horde)
		return fight.active, 15.0)
	_check("won with the late joiner there", fight.active, "")
	for k in 200:
		await _wait(0.1)
		if world.players.size() == 1:
			break
	print("ENCOUNTER HOST ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Puts the check's Yeet somewhere, alive. (It may have just been killed, by a barrel going off after
## a fight, say: being put back here mustn't leave the game's respawn timer running, which would
## move them to the checkpoint in the middle of the next step.)
func _put(pl: Player, pos: Vector3, yaw: float) -> void:
	world._respawn_at.erase(pl.player_id)
	pl.respawn(pos, yaw)


func _finish_off(horde: Horde) -> void:
	for m in horde.monsters.duplicate():
		if m.hp > 0.0 and m.state != Horde.State.HELD:
			horde._damage(m, 99999.0, "fire")


## (a check's Yeet standing there is bitten: not to death, while it's up to something else)
func _keep_alive(pl: Player) -> void:
	while _top_up and is_inside_tree():
		if pl.is_alive():
			world.server_set_hp(pl, 100.0)
		await _wait(0.25)


func _until(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return
		await _wait(0.1)
		t += 0.1


func _named(n: String) -> Variant:
	for p in world.arena.puzzle:
		if String(p.name) == n:
			return p
	return null


func _spawn(n: String) -> MonsterSpawn:
	for s in world.arena.monster_spawns:
		if String(s.name) == n:
			return s
	return null


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
