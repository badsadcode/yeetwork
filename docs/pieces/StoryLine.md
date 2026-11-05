<!-- Made by tools/make_guide.gd from scripts/mapkit/story_line.gd: change the comments there and run it again, not this page. -->
# StoryLine

*Adventure: a Map Kit piece (Add Child Node > StoryLine). Script: `scripts/mapkit/story_line.gd`.* [All the pieces](README.md)

A line of story: a speaker's name and their words as a subtitle for everyone, with Yeetish babble as the voice, when its Inputs come on (a StoryZone walked into, a note read, a door opened). It's on once it's finished, so a conversation is a chain: each line's Input is the line before it. Lines never talk over each other: they wait their turn. Nothing to see in the game. (A recording of your own: none yet; the babble is the voice.)

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Speaker** | (empty) | Who's talking (empty: no name, as a narrator). |
| **Text** | (empty) | What they say. |
| **Voice** | `talk` | How it's babbled: talk, excited, scared, tired; none for silence. Choices: `talk`, `excited`, `scared`, `tired`, `none`. |
| **Delay** | `0` | Seconds to wait after its Inputs come on. *(0 to 60)* |
| **Repeat** | off | Say it again each time its Inputs come back on (off: only ever once). |
