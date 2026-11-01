<!-- Made by tools/make_guide.gd from scripts/mapkit/flood_zone.gd: change the comments there and run it again, not this page. -->
# FloodZone

*Water and ships: a Map Kit piece (Add Child Node > FloodZone). Script: `scripts/mapkit/flood_zone.gd`.* [All the pieces](README.md)

Flood water for puzzles: a 2.5D water grid over the box (Size, standing on this node; keep it unrotated). Every 0.5 m column holds a water depth; water runs toward lower water ("virtual pipes" shallow water, the model from GangTheGame), so it fills rooms, pours through holes smashed in walls, piles up behind closed doors and drains away. The floor under each column is what the level's collision says (rescanned all the time, so doors and broken walls count). Where the floor falls away below the box (a pit), water pours out and is gone. Valves (FloodValve) pour water in, drains (FloodDrain) take it out, and a FloatSwitch turns on when the water reaches it. Yeets swim in it, wood floats, the current carries things along and fire goes out. The host runs it and sends the changes to everyone. Limits: one floor per column (no water on two levels of the same box), no water in the air.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(16, 6, 16)` | The box the water can be in, metres (standing on the node; not rotated). Keep it under about 25 x 25 m. |
| **Start Level** | `0` | Water already there at the start, up to this height above the node (0: dry). *(0 to 20)* |

## Used in

[Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [The Pump House](../../maps/pump_house.tscn) (3)
