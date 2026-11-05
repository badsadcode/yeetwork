@tool
class_name StoryLine
extends PuzzleNode
## A line of story: a speaker's name and their words as a subtitle for everyone, with Yeetish
## babble as the voice, when its Inputs come on (a StoryZone walked into, a note read, a door
## opened). It's on once it's finished, so a conversation is a chain: each line's Input is the
## line before it. Lines never talk over each other: they wait their turn. Nothing to see in the
## game. (A recording of your own: none yet; the babble is the voice.)

const VOICES := {"talk": "taunt", "excited": "cheer", "scared": "gasp", "tired": "effort"}

## Who's talking (empty: no name, as a narrator).
@export var speaker := ""
## What they say.
@export_multiline var text := ""
## How it's babbled: talk, excited, scared, tired; none for silence.
@export_enum("talk", "excited", "scared", "tired", "none") var voice := "talk"
## Seconds to wait after its Inputs come on.
@export_range(0.0, 60.0, 0.1) var delay := 0.0
## Say it again each time its Inputs come back on (off: only ever once).
@export var repeat := false

var _start_at := -1.0 # (server: when to say it)
var _done_at := -1.0 # (server: when it's finished)


## How long it's on the screen.
static func seconds_for(words: String) -> float:
	return maxf(2.0, 1.0 + words.length() * 0.055)


func evaluate() -> bool:
	var now: float = world.now()
	if not inputs_on():
		if repeat:
			_start_at = -1.0
			_done_at = -1.0
		elif _done_at < 0.0:
			_start_at = -1.0 # (it hadn't been said: start the wait again)
		return _done_at >= 0.0 and now >= _done_at
	if _done_at < 0.0:
		if _start_at < 0.0:
			_start_at = now + delay
		if now >= _start_at:
			_done_at = now + seconds_for(text)
			world.server_story_speak(puzzle_index, 0)
	return _done_at >= 0.0 and now >= _done_at


## Every peer: say it.
func speak(_i: int) -> void:
	world.hud.show_story_line(speaker, text, voice, Vector3.INF)


func problems() -> Array[String]:
	var out := super.problems()
	if text.strip_edges() == "":
		out.append("%s: it has no text." % name)
	if inputs.is_empty():
		out.append("%s: it has no Inputs, so nothing sets it off." % name)
	return out
