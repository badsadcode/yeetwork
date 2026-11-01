class_name MegaYeetGate
extends PuzzleNode
## MegaYeet: a breakable wall's repair point (ModeMegaYeet.prepare_arena makes one for each, on
## every peer; nothing to see). Between waves, Use on a broken gate rebuilds it whole, paid
## out of the Fortress meter (or the Yeet's Y$): more the more of it is gone.

var wall: Destructible


func evaluate() -> bool:
	return false


func usable() -> bool:
	if wall == null or not is_instance_valid(wall) or world == null:
		return false
	return int(world.mode_state.get("phase", -1)) == ModeMegaYeet.Phase.BREAK and not wall.broken_cells.is_empty()


func price() -> float:
	return 10.0 + wall.broken_cells.size() * 3.0


func use_label() -> String:
	return "Repair the gate  (%s)" % ModeMegaYeet.price_text(world, price())


func use_point() -> Vector3:
	return wall.global_position


func server_used(pl: Player) -> void:
	var mode := world.mode_logic as ModeMegaYeet
	if mode and not wall.broken_cells.is_empty() and mode.buy(pl, price(), "repaired a gate"):
		world.server_restore_wall(wall.wall_id)
		if world.horde:
			world.horde.request_gate_refresh() # (whole again: the ways to the Heart change)
