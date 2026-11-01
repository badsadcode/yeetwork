extends Node
## TEMPORARY (an experiment on CI, to be removed): why Ship routes' climber sometimes walks
## past the lashing-bridge ladder on CI and never here. Round 1 caught a miss: the ladder held
## the climber all the way up; it goes wrong at the top. Round 2: the ladder's top throw as it
## is, (0, 2, -5), against a stronger one, (0, 4, -4.5), 32 climbs each; a miss logs the top
## of its climb, tick by tick.
## Usage: godot --headless -- --host --map highseas --bots 1 --tour x --tour-mode lashprobe

var world: Node
var out_dir := ""
var ship: Ship
var pl: Player
var _trig: TriggerVolume
var _log := false
var _lines: Array[String] = []


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	ship = world.arena.carrier
	pl = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	for q: Player in world.players.values(): # (the bot parked, brainless, as the real check has it)
		if q != pl and q.is_bot:
			q.bot_brain = null
			q.respawn(ship.global_transform * Vector3(30, MapHighSeas.DECK + 0.2, -14), 0.0)
	var deck := MapHighSeas.DECK
	var gx := (-20.7 + -5.5) * 0.5
	var best := INF
	for t: TriggerVolume in world.arena.find_children("*", "TriggerVolume", true, false):
		if t.kind == TriggerVolume.Kind.LADDER:
			var l := ship.global_transform.affine_inverse() * t.global_position
			var d := Vector2(l.x - gx, l.z + 13.6).length()
			if d < best:
				best = d
				_trig = t
	print("PROBE trigger %s at local %s (%.2f from the spot)" % [_trig, (ship.global_transform.affine_inverse() * _trig.global_position).snapped(Vector3.ONE * 0.01) if _trig else null, best])
	for throw in [Vector3(0, 2, -5), Vector3(0, 4, -4.5)]:
		_trig.launch_velocity = throw
		var m := await _round(gx, deck, 32)
		print("PROBE THROW %s: %d misses of 32" % [throw, m])
	get_tree().quit(0)


func _round(gx: float, deck: float, n: int) -> int:
	var misses := 0
	for k in n:
		world._time_offset = k * 1.9
		await get_tree().physics_frame # (the ship at its new pose first, then the player on it)
		await get_tree().physics_frame
		pl.respawn(ship.global_transform * Vector3(gx, deck + 0.2, -13.6), 0.0)
		pl.cmd.move = Vector2.ZERO
		_lines.clear()
		await get_tree().create_timer(0.4).timeout
		_log = true
		var ok := false
		for i in 80:
			var d := ship.global_transform.basis * Vector3(0, 0, 1)
			pl.yaw = atan2(-d.x, -d.z)
			pl.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			pl.cmd.move = Vector2(0, 1)
			await get_tree().create_timer(0.1).timeout
			var l := ship.global_transform.affine_inverse() * pl.global_position
			if absf(l.y - (deck + MapHighSeas.CONT.y * 2.0)) < 0.7 and absf(l.z) < 12.7 and pl.is_on_floor():
				ok = true
				break
		_log = false
		pl.cmd.move = Vector2.ZERO
		var end := (ship.global_transform.affine_inverse() * pl.global_position).snapped(Vector3.ONE * 0.01)
		if not ok:
			misses += 1
			print("PROBE %d MISS (throw %s), ended %s" % [k, _trig.launch_velocity, end])
			for s in _lines:
				print("  " + s)
	return misses


func _physics_process(_delta: float) -> void:
	if not _log or _trig == null or _lines.size() > 140 or Engine.get_physics_frames() % 4 != 0:
		return # (every 4th tick of the whole attempt)
	var l := ship.global_transform.affine_inverse() * pl.global_position
	var tl := _trig.global_transform.affine_inverse() * pl.global_position
	var facing := pl.aim_direction().slide(Vector3.UP).normalized().dot(-_trig.global_transform.basis.z.normalized())
	_lines.append("tick %d local %s in-trigger-local %s listed %s state %d facing %.2f floor %s held %s v %s" % [Engine.get_physics_frames(), l.snapped(Vector3.ONE * 0.01), tl.snapped(Vector3.ONE * 0.01), _trig.get_overlapping_bodies().has(pl), pl.state, facing, pl.is_on_floor(), Engine.get_physics_frames() - pl.ladder_frame <= 1, pl.velocity.snapped(Vector3.ONE * 0.01)])
