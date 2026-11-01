<!-- Made by tools/make_guide.gd from scripts/mapkit/beacon.gd: change the comments there and run it again, not this page. -->
# Beacon

*Puzzles: a Map Kit piece (Add Child Node > Beacon). Script: `scripts/mapkit/beacon.gd`.* [All the pieces](README.md)

A brazier: on while it burns. Light it with fire: carry a burning crate to it, walk up while burning yourself, burn a FuseLine into it, or switch it on with its inputs. Water (a flood up to the bowl) puts it out. A lit beacon sets alight whatever wooden thing (or Yeet) touches its flames, so one burning beacon can light the others. Start Lit: burning from the start (the level's source of fire). Burn Time: goes out after this long (0: never).

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Start Lit** | off | Burning from the start. |
| **Burn Time** | `0` | Seconds it burns once lit, then goes out (0: for ever). *(0 to 300)* |
| **Palette** | `orange` | The colour of its fire (magic fire: blue, green, gold, violet). Choices: `orange`, `blue`, `green`, `gold`, `violet`. |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[The Pump House](../../maps/pump_house.tscn) (4), [The Scrapyard](../../maps/scrapyard.tscn), [Test Chambers](../../maps/test_chambers.tscn) (3)
