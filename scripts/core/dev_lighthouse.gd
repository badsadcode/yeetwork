extends Node
## Developer check for Lighthouse Point (custom/lighthouse_point/, the map docs/MAKE_A_NEW_MAP.md
## builds): its routes work as the guide says. Up the tower's ladder to the gallery, the jump
## pads onto the gallery and the boathouse roof, out of the sea up the jetty's ladder, the
## boathouse door torn off with the gun, the crane's load over the middle. Exits 1 if a step
## fails.
## Usage: godot --headless -- --host --map res://custom/lighthouse_point/lighthouse_point.tscn --mode ctf --bots 0 --tour x --tour-mode lighthouse

const GALLERY_Y := 15.4
const ROOF_Y := 5.4

var world: Node
var out_dir := ""
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(80.0).timeout.connect(func():
		print("LIGHTHOUSE CHECK FAILED (timed out)")
		get_tree().quit(1))
	await _wait(1.0)
	var pl: Player = world.local_player
	pl.is_bot = true # (held still: no player input)
	var ladders := {}
	var pads := {}
	for n in world.arena.find_children("*", "", true, false):
		if n is Ladder:
			ladders[String(n.name)] = n
		elif n is JumpPadNode:
			pads[String(n.name)] = n
	# Up the tower.
	var tl: Ladder = ladders.get("TowerLadder")
	var top := await _climb(pl, tl, GALLERY_Y - 0.5)
	_check("up the tower's ladder onto the gallery", top > GALLERY_Y - 0.5, "at y %.1f" % top)
	# The jump pads.
	for p: Array in [["ToTheGallery", GALLERY_Y - 0.5], ["ToTheRoof", ROOF_Y - 0.5]]:
		var pad: JumpPadNode = pads.get(p[0])
		world.server_clear_buffs(pl)
		pl.respawn(pad.global_position + Vector3(0, 0.3, 0), 0.0)
		var landed := -10.0
		for k in 20:
			await _wait(0.2)
			if pl.is_on_floor() and k > 4:
				landed = pl.global_position.y
				break
		_check("the jump pad %s lands you up there" % p[0], landed > p[1], "landed at y %.1f" % landed)
	# Out of the sea at the jetty.
	var jl: Ladder = ladders.get("JettyLadder")
	var out := await _climb(pl, jl, -0.3)
	_check("out of the sea up the jetty's ladder", out > -0.3, "at y %.1f" % out)
	# The boathouse door: the gun rips it off.
	var door: ModelDestructible = null
	for d in world.arena.destructibles:
		if d is ModelDestructible and (d as ModelDestructible).tear_off:
			door = d
	pl.respawn(Vector3(14.5, 0, 0), 0.0)
	await _wait(0.5)
	var at := door.global_position + Vector3(0, 1.1, 0) if door else Vector3.ZERO
	var to := at - pl.eye_position()
	pl.yaw = atan2(-to.x, -to.z)
	pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	pl.gun.server_action(GravityGun.Action.GRAB_START, pl.eye_position(), to)
	await _wait(1.5)
	var held := world.get_prop(pl.gun.held_id) as Prop if pl.gun.held_kind == GravityGun.Kind.PROP else null
	_check("the boathouse door: the gun rips it off (in one piece)", door != null and held != null and held.extra.get("assembly", false), "")
	pl.gun.server_action(GravityGun.Action.GRAB_END, pl.eye_position(), Vector3.FORWARD)
	# The crane swings its load over the middle (south of it), not over the sea.
	var crane: Crane = world.arena.find_children("*", "Crane", true, false)[0] if not world.arena.find_children("*", "Crane", true, false).is_empty() else null
	var load_body := crane.find_children("*", "AnimatableBody3D", true, false) if crane else []
	var over := false
	for b: Node3D in load_body:
		over = over or b.global_position.z > crane.global_position.z + 4.0
	_check("the crane's load swings over the middle", over, "")
	print("LIGHTHOUSE CHECK ", "OK" if _failed == 0 else "FAILED (%d)" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


## Climbs a ladder from its foot (facing the wall, holding forward): the highest y reached
## standing on something above `want`, else the highest.
func _climb(pl: Player, l: Ladder, want: float) -> float:
	if l == null:
		return -100.0
	var out_dir := l.global_basis.z.normalized()
	world.server_clear_buffs(pl)
	pl.respawn(l.global_position + out_dir * 0.7 + Vector3(0, 0.6, 0), 0.0)
	await _wait(0.2)
	var top := -100.0
	for k in 80:
		var to := l.global_position - out_dir * 2.0 + Vector3(0, l.height, 0) - pl.eye_position()
		pl.yaw = atan2(-to.x, -to.z)
		pl.pitch = 0.4
		pl.cmd.move = Vector2(0, 1)
		await _wait(0.15)
		top = maxf(top, pl.global_position.y)
		if pl.global_position.y > want and pl.is_on_floor():
			break
	pl.cmd.move = Vector2.ZERO
	return pl.global_position.y if pl.is_on_floor() else top


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
