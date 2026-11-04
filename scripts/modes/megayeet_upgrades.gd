class_name MegaYeetUpgrades
extends PuzzleNode
## MegaYeet: team upgrades at the Heart (ModeMegaYeet.prepare_arena puts it there, on every
## peer). Between waves, Use on the Heart opens the shop's Team tab: any of them, for everyone,
## out of the Fortress meter or the Yeet's Y$ (ModeMegaYeet.UPGRADES; until the fortress falls).

var heart: FortressHeart


func evaluate() -> bool:
	return false


func usable() -> bool:
	if heart == null or world == null:
		return false
	var s: Dictionary = world.mode_state
	return int(s.get("phase", -1)) == ModeMegaYeet.Phase.BREAK and int(s.get("ups", 0)) != (1 << ModeMegaYeet.UPGRADES.size()) - 1


func use_label() -> String:
	return "Team upgrades"


func use_point() -> Vector3:
	return heart.global_position + Vector3.UP * 1.6


func server_used(pl: Player) -> void:
	world.server_open_shop(pl, ModeMegaYeet.TABS.find("Team"))
