class_name MegaYeetUpgrades
extends PuzzleNode
## MegaYeet: team upgrades at the Heart (ModeMegaYeet.prepare_arena puts it there, on every
## peer). Between waves, Use on the Heart buys the next one for everyone, out of the Fortress
## meter or the Yeet's Y$ (ModeMegaYeet.UPGRADES, in order; until the fortress falls).

var heart: FortressHeart


func evaluate() -> bool:
	return false


func usable() -> bool:
	if heart == null or world == null:
		return false
	var s: Dictionary = world.mode_state
	return int(s.get("phase", -1)) == ModeMegaYeet.Phase.BREAK and int(s.get("ups", 0)) < ModeMegaYeet.UPGRADES.size()


func use_label() -> String:
	var up: Array = ModeMegaYeet.UPGRADES[int(world.mode_state.get("ups", 0))]
	return "Team upgrade: %s  (%s)\n%s" % [up[0], ModeMegaYeet.price_text(world, up[1]), up[2]]


func use_point() -> Vector3:
	return heart.global_position + Vector3.UP * 1.6


func server_used(pl: Player) -> void:
	var mode := world.mode_logic as ModeMegaYeet
	if mode:
		mode.buy_upgrade(pl)
