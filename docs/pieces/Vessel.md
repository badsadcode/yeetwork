<!-- Made by tools/make_guide.gd from scripts/mapkit/vessel.gd: change the comments there and run it again, not this page. -->
# Vessel

*Water and ships: a Map Kit piece (Add Child Node > Vessel). Script: `scripts/mapkit/vessel.gd`.* [All the pieces](README.md)

A ship, a boat, a raft: everything under this node rides the sea's swell together, heaving, pitching and rolling the way High Seas' ship does (the same on every player's screen, with nothing sent). Build it from any pieces as children of this node: blocks for its hull and deck, breakable walls, ladders, a crane, a horn, machines, pickups, props, spawn points. Players and props on it ride along; loose cargo slides when it tilts. Needs the map's ocean (MapSettings > Ocean); one Vessel a map.

- Put the node at the water's level (its origin on the waterline), bow along its +X (the red arrow).
- On a map with a Vessel, its spawn points, props and flag stands go on it (under this node): they're kept in the ship's own frame. The map check says if one is left off.
- Length and Beam: the hull it floats on (0: the size of its blocks), what the swell lifts.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Length** | `0` | Bow to stern, along +X (metres; 0: its blocks' length). *(0 to 400)* |
| **Beam** | `0` | Side to side (metres; 0: its blocks' width). *(0 to 100)* |
| **Roll** | `3.2` | How hard it rolls with the swell, and the most it leans over (degrees), and pitches. *(0 to 8)* |
| **Max Roll Degrees** | `16` | The most she rolls side to side in the biggest seas, degrees. *(0 to 45)* |
| **Max Pitch Degrees** | `6` | The most she pitches bow to stern, degrees. *(0 to 20)* |
| **Heave** | `0.8` | How much it rises and falls with the water (1: as much as the water). *(0 to 2)* |
| **Lag** | `0.8` | Seconds it lags behind the water (a big heavy ship: more). *(0 to 3)* |
| **High Seas Weather** | off | High Seas' own weather on it in a stormy sea: green water washing over the rail, rogue waves, spray off the hull (laid out for High Seas' ship: about 140 x 32 m, its deck 8 m up). |

## Start from

- [`custom/make_your_own/boat.tscn`](../../custom/make_your_own/boat.tscn): Make Your Own Boat: a boat beside an island

## Used in

[Make Your Own Boat](../../custom/make_your_own/boat.tscn), [High Seas](../../maps/high_seas.tscn)
