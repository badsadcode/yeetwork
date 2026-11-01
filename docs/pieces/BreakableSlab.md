<!-- Made by tools/make_guide.gd from scripts/mapkit/breakable_slab.gd: change the comments there and run it again, not this page. -->
# BreakableSlab

*Building: a Map Kit piece (Add Child Node > BreakableSlab). Script: `scripts/mapkit/breakable_slab.gd`.* [All the pieces](README.md)

A destructible wall, floor or bridge. In game it becomes an irregular fractured slab. WALL: the slab stands upright, width along local X, height along local Y, thickness along local Z. FLOOR: lies flat, length along local X, width along local -Z. The editor preview shows the fracture style (the in-game pattern is seeded per map).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Orientation** | `WALL` | WALL: upright (width X, height Y, thickness Z). FLOOR: flat (length X, width Z): a floor or a bridge. |
| **Size** | `(6, 3)` | Width x height (WALL) or length x width (FLOOR), meters. |
| **Thickness** | `0.6` | How thick it is, metres. *(0.05 to 3)* |
| **Material** | `plaster` | What it's made of: how tough it is and how it breaks (brick into bricks, wood into splinters along its length, glass into shards, ice cracks and melts; metal is very tough). Choices: `plaster`, `concrete`, `brick`, `wood`, `glass`, `metal`, `ice`. |
| **Color** | `Color(0.95, 0.86, 0.66)` | Its colour (and its pieces' and dust's). |
| **Anchor Bottom** | on | Edges attached to the world. Pieces cut off from every anchored edge fall/crumble. |
| **Anchor Top** | off | Its top edge is glued to the world (a window: all four; a bridge: Left and Right). |
| **Anchor Left** | off | Its left edge is glued to the world. |
| **Anchor Right** | off | Its right edge is glued to the world. |
| **Custom Material** | (none) | Your own material on its faces (a brick texture...): laid on by position, a repeat every Texture Size metres; the broken edges keep Material's look, and Material still says how it breaks (how tough, the size of its pieces, glass shatters, wood burns). Save it as a file (.tres) so its pieces look right for every player. |
| **Texture Size** | `2` | With a Custom Material: metres per repeat of its texture. *(0.1 to 20)* |
| **Hp Scale** | `1` | Toughness: multiplies the material's (0.5 half as tough, 10 ten times). MegaYeet's gates: how long they hold against the monsters battering them. *(0.1 to 50, or more)* |

## Start from

- [`custom/make_your_own/bricks.tres`](../../custom/make_your_own/bricks.tres): a brick material for Custom Material

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (3), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [Courtyard](../../maps/courtyard.tscn) (10), [Facing Yeets](../../maps/facing.tscn) (8), [The Fortress](../../maps/fortress.tscn) (12), [High Seas](../../maps/high_seas.tscn) (4), [Lagoon](../../maps/lagoon.tscn) (6), [Yeetwork Prime](../../maps/prime.tscn) (20), [The Pump House](../../maps/pump_house.tscn) (2), [Test Chambers](../../maps/test_chambers.tscn) (8), [The Warehouse](../../maps/warehouse.tscn) (2)
