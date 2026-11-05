<!-- Made by tools/make_guide.gd from scripts/mapkit/story_note.gd: change the comments there and run it again, not this page. -->
# StoryNote

*Adventure: a Map Kit piece (Add Child Node > StoryNote). Script: `scripts/mapkit/story_note.gd`.* [All the pieces](README.md)

A thing to read: a note, a diary, a sign, a clue. Walk up and press Use: your text opens on the reader's screen (and a picture, if it has one). It's on once someone's read it, so it can open a door, count as a clue found, or set off what comes next. With Inputs, it can only be read once they're on (it isn't there until then). The built-in look is a page on a stand.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Title** | `Note` | Its name: the Use prompt ("Read <Title>") and the top of the page. |
| **Text** | (empty) | What it says. |
| **Picture** | (none) | A picture on the page (a drawing, a photo, a map), if any. |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's `story_note`. Its origin is on the ground. |
