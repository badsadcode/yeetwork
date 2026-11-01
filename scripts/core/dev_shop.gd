extends Node
## Developer look at MegaYeet's shop window: personal Y$, a break, every tab in turn (and at
## the Steam Deck's 1280 x 800); screenshots of each. Exits 1 if a tab shows no cards.
## Usage: godot -- --host --map res://maps/fortress.tscn --mode megayeet --bots 0 --port 24793 --tour <dir> --tour-mode shop

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		print("SHOP CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var mode := world.mode_logic as ModeMegaYeet
	var pl: Player = world.local_player
	pl.is_bot = true # (held still: no player input)
	mode.personal = true
	mode.cash[pl.player_id] = 230
	mode.phase_end = world.now() + 999.0
	mode.meter = mode.max_meter * 0.6
	mode._send_state()
	await _wait(0.3)
	world.hud.open_shop()
	var win: ShopWindow = world.hud._shop
	for size in [Vector2i(1600, 900), Vector2i(1280, 800)]:
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(size)
		for t in ModeMegaYeet.TABS.size():
			win._set_tab(t)
			await _wait(0.5)
			if win._cards.is_empty():
				print("FAIL  the %s tab shows cards" % ModeMegaYeet.TABS[t])
				_failed += 1
			await _shot("shop_%d_%s" % [size.x, String(ModeMegaYeet.TABS[t]).to_lower().replace("-", "")])
	print("SHOP CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless" or out_dir == "" or out_dir == "x":
		return
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
