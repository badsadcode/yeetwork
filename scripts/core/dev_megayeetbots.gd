extends Node
## Developer check for MegaYeet with a full house of bots (11) and a big wave: how long the
## server's frames take (the bots share one map, BotField: no path search each). Fails if
## they average over 16 ms (a frame at 60 FPS). Prints the numbers.
## Usage: godot -- --host --map res://maps/fortress.tscn --mode megayeet --bots 11 --tour x --tour-mode megayeetbots

var world: Node
var out_dir := ""


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func():
		print("MEGAYEET BOTS CHECK FAILED (timed out)")
		get_tree().quit(1))
	var mode := world.mode_logic as ModeMegaYeet
	await get_tree().create_timer(1.5).timeout
	var horde: Horde = world.horde
	for k in 150:
		var a := randf() * TAU
		horde.server_spawn(Vector3(cos(a), 0, sin(a)) * randf_range(26.0, 60.0), ["shambler", "runner", "shambler", "climber"][k % 4])
	mode.phase = ModeMegaYeet.Phase.WAVE
	mode._to_spawn = 0
	await get_tree().create_timer(4.0).timeout # (settled: the bots' map made, the bots under way)
	var frames := 0
	var total := 0.0
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < 10000:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		frames += 1
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		worst = maxf(worst, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var bots: int = world.players.values().filter(func(q): return q.is_bot).size()
	var avg := total / maxf(frames, 1)
	print("MEGAYEET BOTS: %d bots, %d monsters, physics %.2f ms a frame (worst %.1f), %d frames in 10 s" % [bots, horde.count(), avg, worst, frames])
	var ok: bool = bots >= 11 and avg < 16.0
	print("%s  11 bots and a big wave: the server's frames stay quick  (%.2f ms)" % ["PASS" if ok else "FAIL", avg])
	print("MEGAYEET BOTS CHECK ", "OK" if ok else "FAILED (1)")
	get_tree().quit(0 if ok else 1)
