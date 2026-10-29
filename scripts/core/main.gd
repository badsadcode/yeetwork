extends Node
## Entry point: switches between the main menu and a running World, and owns the
## network peer.
##
## Command line (after `--`):  --host  --join <ip>  --mode sandbox|ctf|dodgeball
##   --bots <n>  --bot-skill 0|1|2  --port <n>  --name <name>  --autotest <seconds>  (quit after N seconds)
##   --screenshot <png> (save a screenshot after 2.5 s, then quit)
##   --map prime|facing|<map name in res://maps>  --validate (check a map, then quit)  --test (gameplay smoke tests)  --tour <dir> [--tour-mode destruction|charge|water]  (save screenshots from fixed viewpoints, then quit)
##   --graphics 0|1|2 (quality preset for this run: low / medium / high)

var menu: MainMenu
var world: World
var _autotest := -1.0
var _autotest_elapsed := 0.0
var _tour_dir := ""
var _tour_mode := ""
var _test := false
var _validate := false
var _shot_path := ""
var _shot_time := 0.0


func _ready() -> void:
	multiplayer.server_disconnected.connect(func(): leave("Disconnected from server"))
	multiplayer.connection_failed.connect(func(): leave("Could not connect"))
	multiplayer.connected_to_server.connect(_on_connected)
	if Game.autostart:
		# Playtest launched from a map scene (F6).
		Game.autostart = false
		_handle_cmdline(false)
		host()
	elif not _handle_cmdline():
		show_menu("")


func _handle_cmdline(execute := true) -> bool:
	var args := OS.get_cmdline_user_args()
	var action := ""
	var i := 0
	while i < args.size():
		var a := args[i]
		var next := args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--host":
				action = "host"
			"--join":
				action = "join"
				Game.join_address = next
				i += 1
			"--mode":
				Game.mode = {"sandbox": Game.Mode.SANDBOX, "ctf": Game.Mode.CTF, "dodgeball": Game.Mode.DODGEBALL, "pumpkin": Game.Mode.PUMPKIN}.get(next, Game.Mode.SANDBOX)
				i += 1
			"--spooky":
				Game.halloween = 2 if next != "off" else 0
				i += 1
			"--map":
				# Built-in key ("prime", "facing"), a map file name in res://maps, or a path.
				Game.map = next if next in ["prime", "facing"] or next.begins_with("res://") else "res://maps/%s.tscn" % next.trim_suffix(".tscn")
				i += 1
			"--bot-skill":
				Game.bot_skill = int(next)
				i += 1
			"--bots":
				Game.bot_count = int(next)
				i += 1
			"--port":
				Game.port = int(next)
				i += 1
			"--name":
				Game.player_name = next
				i += 1
			"--autotest":
				_autotest = float(next)
				i += 1
			"--test":
				_test = true
			"--validate":
				_validate = true
				action = "host"
			"--tour":
				_tour_dir = next
				i += 1
			"--screenshot":
				_shot_path = next
				i += 1
			"--tour-mode":
				_tour_mode = next
				i += 1
			"--graphics":
				# Quality preset for this run only (not saved): 0 low (Steam Deck), 1 medium, 2 high.
				Game.graphics = clampi(int(next), 0, 2)
				Game.apply_graphics()
				i += 1
		i += 1
	if not execute:
		return false
	match action:
		"host":
			host()
			return true
		"join":
			join()
			return true
	return false


func _process(delta: float) -> void:
	if _shot_path != "":
		_shot_time += delta
		if _shot_time > 2.5:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			print("Saved ", _shot_path)
			get_tree().quit()
	if _autotest > 0.0:
		_autotest_elapsed += delta
		if _autotest_elapsed >= _autotest:
			_autotest = -1.0
			_report_and_quit()


func _report_and_quit() -> void:
	if world:
		var alive := 0
		for p in world.players.values():
			if p.is_alive():
				alive += 1
		var broken := 0
		for d in world.arena.destructibles:
			broken += d.broken_cells.size()
		print("AUTOTEST server=%s players=%d alive=%d props=%d broken_cells=%d scores=%s" % [world.is_server, world.players.size(), alive, world.props.size(), broken, world.team_scores])
		for p in world.players.values():
			print("  %s hp=%.0f frags=%d deaths=%d score=%d pos=%s" % [p.display_name, p.hp, p.frags, p.deaths, p.score, p.global_position.snapped(Vector3.ONE * 0.1)])
	else:
		print("AUTOTEST no world")
	get_tree().quit()


func _run_validation() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var issues: Array[String] = world.arena.validate()
	var cells := 0
	for d in world.arena.destructibles:
		cells += d.cells.size()
	print("MAP VALIDATION: %s" % Game.map_display_name(world.map_key))
	print("  spawns any/red/blue: %d/%d/%d, flags: %d, props: %d, breakables: %d (%d cells), kill height: %.1f" % [
		world.arena.spawn_points[0].size(), world.arena.spawn_points[1].size(), world.arena.spawn_points[2].size(),
		world.arena.flag_stands.size(), world.arena.initial_props.size(), world.arena.destructibles.size(), cells, world.arena.kill_y])
	if issues.is_empty():
		print("  OK - no problems found")
	for i in issues:
		print("  WARNING: " + i)
	get_tree().quit(1 if not issues.is_empty() else 0)


func show_menu(status: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu == null:
		menu = MainMenu.new()
		add_child(menu)
		menu.host_pressed.connect(host)
		menu.join_pressed.connect(join)
		menu.quit_pressed.connect(func(): get_tree().quit())
	menu.visible = true
	menu.set_status(status)


func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Game.port, Game.MAX_PLAYERS)
	if err != OK:
		# Port busy: still let people play offline.
		print("Could not open port %d (%s); playing offline" % [Game.port, error_string(err)])
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	else:
		multiplayer.multiplayer_peer = peer
	_start_world(true)


func join() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(Game.join_address, Game.port)
	if err != OK:
		show_menu("Could not start client: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	if menu:
		menu.set_status("Connecting to %s:%d..." % [Game.join_address, Game.port])


func _on_connected() -> void:
	_start_world(false)


func _start_world(server: bool) -> void:
	if menu:
		menu.visible = false
	world = World.new()
	add_child(world)
	world.leave_requested.connect(func(): leave(""))
	world.start(server)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _validate:
		_run_validation.call_deferred()
	if _test:
		var t: Node = load("res://tests/test_runner.gd").new()
		t.set("world", world)
		add_child(t)
	if _tour_dir != "":
		var script_path := "res://scripts/core/dev_%s.gd" % _tour_mode if _tour_mode != "" else "res://scripts/core/dev_tour.gd"
		var tour: Node = load(script_path).new()
		tour.set("world", world)
		tour.set("out_dir", _tour_dir)
		add_child(tour)


func leave(status: String) -> void:
	if world:
		world.queue_free()
		world = null
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _autotest > 0.0 or DisplayServer.get_name() == "headless":
		print("Left match: %s" % status)
		get_tree().quit()
		return
	show_menu(status)
