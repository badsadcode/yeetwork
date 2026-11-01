<!-- Made by tools/make_guide.gd from scripts/mapkit/prop_spawn.gd: change the comments there and run it again, not this page. -->
# PropSpawn

*Things in it: a Map Kit piece (Add Child Node > PropSpawn). Script: `scripts/mapkit/prop_spawn.gd`.* [All the pieces](README.md)

A physics prop placed in the map. Map props respawn at this spot after they are destroyed or fall out of the world. Type: your own prop (a PropType: your model and numbers on a built-in one's behaviour) in place of Kind.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `crate` | Which built-in prop. Choices: `crate`, `crate_big`, `barrel`, `boom_barrel`, `ball`, `beachball`, `anvil`, `plank`, `couch`, `tire`, `cone`, `fuse`, `lost_yeet`, `boulder`, `platform`, `battery`, `gravestone`, `coffin`, `pumpkin`, `iron_ball`. |
| **Key Prop** | off | A prop a puzzle needs: comes back here 2.5 s after it's destroyed or falls out of the level (other map props take 10-25 s), and a PuzzleReset puts it back home. |
| **Type** | (none) | Your own prop (a PropType file) in place of Kind. |

## Start from

- [`custom/make_your_own/oil_drum.tres`](../../custom/make_your_own/oil_drum.tres): a prop of your own for its Type slot (see PropType)

## Used in

[Example Garden](../../custom/example_garden/example_garden.tscn) (4), [Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (12), [Make Your Own Boat](../../custom/make_your_own/boat.tscn) (8), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn) (8), [Courtyard](../../maps/courtyard.tscn) (28), [Facing Yeets](../../maps/facing.tscn) (45), [The Fortress](../../maps/fortress.tscn) (42), [Haunted Yard](../../maps/haunted_yard.tscn) (40), [High Seas](../../maps/high_seas.tscn) (22), [Lagoon](../../maps/lagoon.tscn) (22), [Moving Day](../../maps/moving_day.tscn) (22), [Yeetwork Prime](../../maps/prime.tscn) (75), [The Pump House](../../maps/pump_house.tscn) (12), [The Scrapyard](../../maps/scrapyard.tscn) (18), [Test Chambers](../../maps/test_chambers.tscn) (43), [The Warehouse](../../maps/warehouse.tscn) (23)
