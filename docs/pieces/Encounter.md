<!-- Made by tools/make_guide.gd from scripts/mapkit/encounter.gd: change the comments there and run it again, not this page. -->
# Encounter

*Adventure: a Map Kit piece (Add Child Node > Encounter). Script: `scripts/mapkit/encounter.gd`.* [All the pieces](README.md)

A set-piece fight, for the Adventure and Puzzle modes. When its Inputs come on (with none, as the level starts) its rifts (MonsterSpawn) open and its Waves come through, each once the one before is dead. On once they're all dead, so it can open the way on.
If everyone's down at once, they're all back at the last checkpoint and it starts again: a StoryZone that set it off can be walked into again (and a door it slammed opens again). If its Inputs are still on, it starts again by itself after Restart After.
One fight at a time: another whose Inputs come on waits for this one to end.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Waves** | (none) | What comes, in order (New EncounterWave for each). |
| **Rifts** | (none) | The MonsterSpawns they come through. Empty: every rift on the map. They only walk on ground from about the height of these and the Goal upward, so a fight can be up on a shelf or a balcony: one knocked off falls (hard), and doesn't climb back. |
| **Goal** | (none) | Where they head for until a Yeet's near: any node (a Marker3D). Empty: they hunt the Yeets, wherever they go. |
| **Start Delay** | `1` | Seconds from its Inputs coming on to the first monster. *(0 to 60)* |
| **Wave Gap** | `3` | Seconds between one wave dying and the next coming. *(0 to 60)* |
| **Chase Range** | `12` | How close a Yeet they can see has to be before they go straight for them, metres. *(2 to 60)* |
| **Max At Once** | `40` | The most monsters at once (the rest of a wave waits for room). Mind the Steam Deck. *(5 to 200)* |
| **Respawn After** | `15` | Seconds a fallen Yeet is out of it while the fight's on (back at the checkpoint after that). *(3 to 120)* |
| **Restart After** | `5` | Seconds after everyone's fallen before it can start again. *(1 to 120)* |

## Start from

- [`adventures/the_cellar/cellar.tscn`](../../adventures/the_cellar/cellar.tscn): two fights: one hunting you through two waves, then a boss let out of a cage, heading for a Goal
- [`adventures/grandmas_glasses/study.tscn`](../../adventures/grandmas_glasses/study.tscn): a fight up on a bookshelf: punt them off the edge
