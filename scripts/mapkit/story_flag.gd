@tool
class_name StoryFlag
extends PuzzleNode
## A story's memory, across an Adventure's chapters: "found the diary", "met Bob". remember sets
## its flag when its Inputs come on; check is on when the flag is set, even from an earlier
## chapter, so a later map can react to what you did: a line, a door, a Talking Yeet. Flags are
## saved with the adventure. Outside the Adventure mode they last for the one level. Nothing to
## see in the game.

## The flag's name (the same on both sides: spelled the same, in any chapter).
@export var flag := ""
## remember: set the flag when Inputs come on. check: on when the flag is set.
@export_enum("remember", "check") var action := "remember"


func evaluate() -> bool:
	if action == "remember" and inputs_on() and not world.story_flag(flag):
		world.server_set_story_flag(flag)
	return world.story_flag(flag)


func problems() -> Array[String]:
	var out := super.problems()
	if flag.strip_edges() == "":
		out.append("%s: it has no flag name." % name)
	if action == "remember" and inputs.is_empty():
		out.append("%s: it remembers nothing without Inputs." % name)
	return out
