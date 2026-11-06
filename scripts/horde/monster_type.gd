@tool
class_name MonsterType
extends Resource
## MegaYeet: your own monster, joining the waves beside the built-in ones. It behaves like the
## built-in kind you pick (Behaves Like: a runner sprints, a brute smashes gates, a ghost
## drifts through walls, a climber scales them, a bomber blows up) with your model and your
## numbers. Make one: right-click a folder > Create New > Resource > MonsterType, save it next
## to your model, fill it in, and add it to the map's FortressHeart (Monster Types).
## - Model: facing -Z (Blender: +Y, like the Yeets), its feet at the origin, about a Yeet's
##   height (1.8 m; Size scales it). Made of parts named Torso, Leg_L, Leg_R, Arm_L, Arm_R and
##   Head, each with its origin at its joint (the hip, the shoulder, the neck): the game swings
##   them the way it swings the built-in monsters (a lurching walk, reaching arms, flailing
##   when thrown, a lolling head). Anything else rides on the torso (or on the part it's
##   inside). "Glow" in a part's or a material's name makes it glow.
## - Everything at 0 is the built-in kind's.

## Its name in the game (the wave announcement).
@export var display_name := ""
## The built-in monster it acts like: how it moves, what it can do.
@export_enum("shambler", "runner", "brute", "ghost", "climber", "bomber") var behaves_like := "shambler"
## Your model: parts named Torso, Leg_L, Leg_R, Arm_L, Arm_R, Head, each with its origin at
## its joint.
@export var model: PackedScene
## Hit points (0: the built-in kind's: a shambler 40, a runner 20, a brute 320).
@export_range(0.0, 5000.0, 1.0) var hit_points := 0.0
## Metres a second (0: the built-in kind's: a shambler 1.7, a runner 4).
@export_range(0.0, 10.0, 0.05) var speed := 0.0
## What a bite takes off a Yeet (0: the built-in kind's: a shambler 7, a brute 24).
@export_range(0.0, 200.0, 0.5) var bite := 0.0
## What a hit takes off a gate (0: the built-in kind's: a shambler 22, a brute 110).
@export_range(0.0, 1000.0, 1.0) var bash := 0.0
## How big it's drawn and how big it is (1: a Yeet's height; 0: the built-in kind's).
@export_range(0.0, 4.0, 0.05) var size := 0.0
## How hard fire hurts it (1 as a shambler; 0: the built-in kind's).
@export_range(0.0, 5.0, 0.05) var burns := 0.0
## What it leaves when it dies: a body (and blood, by the gore setting), or a puff of dust and
## nothing else.
@export_enum("a body", "dust") var remains := "a body"
## Whether the gravity gun can grab it ("as it": like the kind it behaves like).
@export_enum("as it", "yes", "no") var grabbable := "as it"
@export_group("In the waves")
## It comes from this wave on.
@export_range(1, 50) var from_wave := 1
## How much of each wave it is from then on (0.2: a fifth).
@export_range(0.0, 1.0, 0.01) var share := 0.2
## Shown the first time it comes (empty: "<NAME>S!").
@export var announce := ""


## Its numbers and what it does, like Horde.KINDS' (the built-in kind's, with this one's own).
func def() -> Dictionary:
	var d: Dictionary = Horde.KINDS[behaves_like].duplicate()
	d.like = behaves_like
	if hit_points > 0.0:
		d.hp = hit_points
	if speed > 0.0:
		d.speed = speed
	if bite > 0.0:
		d.bite = bite
	if bash > 0.0:
		d.bash = bash
	if size > 0.0:
		d.radius = float(d.radius) * size / float(d.size)
		d.size = size
	if burns > 0.0:
		d.burn = burns
	if remains == "dust":
		d.dust = true
	if grabbable != "as it":
		d.grab = grabbable == "yes"
	d.name = display_name if display_name != "" else resource_path.get_file().get_basename().capitalize()
	return d


## What the wave announcement says the first time it comes.
func announcement() -> String:
	if announce != "":
		return announce
	return "%sS!" % def().name.to_upper()
