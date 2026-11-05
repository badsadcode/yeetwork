<!-- Made by tools/make_guide.gd from scripts/mapkit/talking_yeet.gd: change the comments there and run it again, not this page. -->
# TalkingYeet

*Adventure: a Map Kit piece (Add Child Node > TalkingYeet). Script: `scripts/mapkit/talking_yeet.gd`.* [All the pieces](README.md)

A Yeet who stands there and talks: walk up and press Use, and they say their next line as a subtitle for everyone, with Yeetish babble as the voice; at the last one they keep repeating it. They look at whoever's nearest. On once they've said everything, so talking to them can open a door or set a StoryFlag. With Inputs, they only talk once those are on.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Display Name** | `Yeet` | Their name: the Use prompt ("Talk to <Name>") and the subtitle. |
| **Lines** | (none) | What they say, in turn, a line per press. |
| **Voice** | `talk` | How it's babbled: talk, excited, scared, tired; none for silence. Choices: `talk`, `excited`, `scared`, `tired`, `none`. |
| **Shirt** | `Color(0.3, 0.6, 0.9)` | Their shirt. |
| **Hat** | `0` | Their hat, by number (0: the first built-in hat; the Character menu's order). |
| **Face** | `0` | Their head extra, by number (0: nothing; the Character menu's order). |
| **Character** | `Classic Yeet` | Which Yeet: a Classic Yeet, or Noor. Choices: `Classic Yeet`, `Noor`. |
