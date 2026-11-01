<!-- Made by tools/make_guide.gd from scripts/mapkit/contacts.gd: change the comments there and run it again, not this page. -->
# Contacts

*Puzzles: a Map Kit piece (Add Child Node > Contacts). Script: `scripts/mapkit/contacts.gd`.* [All the pieces](README.md)

Two copper pads Gap apart (along local X): on while they're powered (their inputs are on, or always with no inputs) and something conductive bridges them. A metal prop lying across both (a barrel, an anvil, a battery), water over both (a flood, a pool), or a Yeet standing between them, who gets zapped for it (a jolt and a hop, again and again). The classic: close the circuit to open the door.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Gap** | `1.4` | How far apart the two pads are, metres. *(0.6 to 6)* |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |

## Used in

[The Scrapyard](../../maps/scrapyard.tscn)
