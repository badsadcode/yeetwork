extends Node
## TEMPORARY (an experiment on CI, to be removed): why Ship routes' climber sometimes walks
## past the lashing-bridge ladder on CI and never here. The climb at 24 points of the ship's
## roll, every physics tick of the approach logged: whether the ladder's trigger lists the
## player, the player's state, facing, on the floor, the ladder holding them.
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
	var misses := 0
	for k in 24:
		world._time_offset = k * 2.5
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
		print("PROBE %d %s, ended %s" % [k, "ok" if ok else "MISS", end])
		if not ok:
			misses += 1
			for s in _lines:
				print("  " + s)
	print("PROBE DONE: %d misses of 24" % misses)
	get_tree().quit(0)


func _physics_process(_delta: float) -> void:
	if not _log or _trig == null or _lines.size() > 40:
		return
	var l := ship.global_transform.affine_inverse() * pl.global_position
	var tl := _trig.global_transform.affine_inverse() * pl.global_position
	var facing := pl.aim_direction().slide(Vector3.UP).normalized().dot(-_trig.global_transform.basis.z.normalized())
	_lines.append("tick %d local %s in-trigger-local %s listed %s state %d facing %.2f floor %s held %s v %s" % [Engine.get_physics_frames(), l.snapped(Vector3.ONE * 0.01), tl.snapped(Vector3.ONE * 0.01), _trig.get_overlapping_bodies().has(pl), pl.state, facing, pl.is_on_floor(), Engine.get_physics_frames() - pl.ladder_frame <= 1, pl.velocity.snapped(Vector3.ONE * 0.01)])
