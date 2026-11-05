<!-- Made by tools/make_guide.gd from scripts/mapkit/monster_spawn.gd: change the comments there and run it again, not this page. -->
# MonsterSpawn

*MegaYeet: a Map Kit piece (Add Child Node > MonsterSpawn). Script: `scripts/mapkit/monster_spawn.gd`.* [All the pieces](README.md)

Where monsters come from (a rift in the ground, Radius across). In MegaYeet: put several round the fortress, outside its walls; each wave's monsters share them out. For an Encounter: out of sight until the fight starts. From Wave: this one opens from that wave on (a surprise rift later on).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Radius** | `3` | How big the rift is, metres. |
| **From Wave** | `1` | It opens from this wave on (a surprise rift later in the game). *(1 to 50)* |

## Used in

[Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [The Fortress](../../maps/fortress.tscn) (6), [The Foundry](../../maps/foundry.tscn) (5)
