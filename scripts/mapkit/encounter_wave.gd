class_name EncounterWave
extends Resource
## One wave of an Encounter: how many of what come through its rifts. The next wave comes once
## they're all dead.

## How many of each built-in kind.
@export_range(0, 200) var shamblers := 0
## Fast, and they fall apart.
@export_range(0, 200) var runners := 0
## Huge and slow; too heavy to grab.
@export_range(0, 50) var brutes := 0
## Drift through walls; only light and fire hurt them.
@export_range(0, 100) var ghosts := 0
## Climb any wall in the way.
@export_range(0, 100) var climbers := 0
## Run at Yeets with a powder keg.
@export_range(0, 100) var bombers := 0
## A boss leading this wave in: the Siege Golem, or the Wrecking Ram.
@export_enum("none", "golem", "ram") var boss := "none"
## The boss's hit points (more with more Yeets playing).
@export_range(100.0, 50000.0, 50.0) var boss_health := 1500.0
## Monsters of your own (MonsterType files; their From Wave and Share are for MegaYeet).
@export var own_monsters: Array[MonsterType] = []
## How many of each of your own come.
@export_range(0, 200) var own_count := 0
## Seconds between one monster coming through and the next.
@export_range(0.05, 10.0, 0.05) var spawn_gap := 0.5


## Everything that isn't the boss, as kind names ("custom" ones through own_kind), in no order.
func plan(own_kind: Callable) -> Array[String]:
	var out: Array[String] = []
	var counts := {"shambler": shamblers, "runner": runners, "brute": brutes, "ghost": ghosts, "climber": climbers, "bomber": bombers}
	for k: String in counts:
		for i in counts[k]:
			out.append(k)
	for t in own_monsters:
		if t == null:
			continue
		var kind: String = own_kind.call(t)
		for i in own_count:
			out.append(kind)
	return out


## How many monsters it brings, the boss too (0: an empty wave, which the map check notes).
func total() -> int:
	var own := 0
	for t in own_monsters:
		if t != null:
			own += own_count
	return shamblers + runners + brutes + ghosts + climbers + bombers + own + (0 if boss == "none" else 1)
