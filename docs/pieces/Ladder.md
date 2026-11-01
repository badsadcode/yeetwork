<!-- Made by tools/make_guide.gd from scripts/mapkit/ladder.gd: change the comments there and run it again, not this page. -->
# Ladder

*Building: a Map Kit piece (Add Child Node > Ladder). Script: `scripts/mapkit/ladder.gd`.* [All the pieces](README.md)

A ladder up a wall (a building, a ship's side, out of a pool or the sea): walk up to it facing the wall and hold forward (or Jump) to climb, back (or Crouch) to go down, let go and you hang on; at the top it lifts you up and over the edge. Put the node at the ladder's foot against the wall, its blue arrow (+Z) pointing away from the wall, toward the climber. Bots in the sea swim to the ladders whose foot is in the water (MapSettings' ocean). Model: your own ladder (its origin at the foot, up along +Y, the wall behind it at -Z); climbing works the same whatever it looks like.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Height** | `4` | How tall, metres. Let it reach a little above what it climbs (a rail's top: about 40 cm more). *(1 to 40)* |
| **Over The Top** | `6` | How hard the top throws you on over the edge (m/s; 0: just up). A rail or a wide ledge at the top wants more. *(0 to 12)* |
| **Top Throw** | `(0, 0, 0)` | Instead of that, exactly how the top throws you (m/s, the ladder's own frame: x along the wall, y up, z out from it; zero: Over The Top). For a ladder that lets you off sideways. |
| **Model** | (none) | Your own model for it (instead of the built-in yellow rails, and the map theme's). |

## Start from

- [`custom/make_your_own/models/ladder.glb`](../../custom/make_your_own/models/ladder.glb): a wooden ladder

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (3), [Make Your Own Boat](../../custom/make_your_own/boat.tscn) (2), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn) (2), [High Seas](../../maps/high_seas.tscn) (20)
