<!-- Made by tools/make_guide.gd from scripts/mapkit/defense_zone.gd: change the comments there and run it again, not this page. -->
# DefenseZone

*MegaYeet: a Map Kit piece (Add Child Node > DefenseZone). Script: `scripts/mapkit/defense_zone.gd`.* [All the pieces](README.md)

MegaYeet: a zone of the fortress (a box, Size, its bottom on the node). Every monster inside drains the team's Fortress meter each second, more the deeper the zone: Level 1 the outer walls, 2 the courtyard, 3 the inner keep (where zones overlap, the deepest counts). The HUD names a zone when monsters get in (Zone Name). Shown in the editor as a tinted box; in the game a faint line on the ground marks its edge (Show Edge).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Level** | `1` | How deep in the fortress it is: 1 the outer walls, 2 the courtyard, 3 the inner keep. Deeper zones drain the meter faster. *(1 to 3)* |
| **Size** | `(40, 8, 40)` | The zone's box, metres (its bottom on the node). |
| **Zone Name** | (empty) | What the HUD calls it when monsters get in ("the gatehouse"). |
| **Drain** | `0` | Meter points a monster inside drains each second (0: the level's usual: 1, 3, 6). |
| **Show Edge** | on | A faint line on the ground marks its edge in the game. |

## Used in

[The Fortress](../../maps/fortress.tscn) (3)
