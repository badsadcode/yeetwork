<!-- Made by tools/make_guide.gd from scripts/mapkit/crane.gd: change the comments there and run it again, not this page. -->
# Crane

*Things in it: a Map Kit piece (Add Child Node > Crane). Script: `scripts/mapkit/crane.gd`.* [All the pieces](README.md)

A crane (a dock, a building site, a ship's deck): it slews to and fro on its own, a load hanging from its jib on a cable. The load is solid: ride it, or get swept off a roof when it comes round. Every player sees the same crane with nothing sent (it runs off the match clock). Put the node on the ground (or a deck) where its pedestal stands.

- Heading: where the jib points in the middle of its sweep (degrees round from the node's +X), Sweep: how far either side it goes, Period: seconds there and back.
- Model: your own crane: a part named "Turret" slews (its jib along the Turret's +X) and an empty "Hook" on it is where the cable hangs. Load Model: what hangs (in a Load Size box, its origin in the middle). The pedestal's collision is a Pedestal Size box either way.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Height** | `12` | How high its jib is, metres. *(2 to 60)* |
| **Jib** | `14` | How long its jib is, metres (the cable hangs from its end). *(3 to 60)* |
| **Cable** | `3` | How far the load hangs below the jib, metres. *(0.5 to 30)* |
| **Heading** | `180` | Where the jib points in the middle of its sweep: degrees round from the node's +X. *(-180 to 180)* |
| **Sweep** | `69` | How far it slews either side of Heading, degrees. *(0 to 180)* |
| **Period** | `48` | Seconds to slew there and back. *(4 to 300)* |
| **Load Size** | `(6.1, 2.6, 2.44)` | The load's box, metres (it's solid: ride it). |
| **Load Color** | `Color(0.95, 0.55, 0.1)` | The built-in load's colour. |
| **Pedestal Size** | `(2, 0, 2)` | The pedestal's box, metres (its collision; height 0: up to Height). |
| **Model** | (none) | Your own crane: a part named "Turret" slews (its jib along the Turret's +X), an empty "Hook" is where the cable hangs. |
| **Load Model** | (none) | Your own load (its origin in its middle), in a Load Size box. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Turret` | slews (its jib along its +X) | the crane stands still (only its cable sways) |
| `Hook` | where the cable hangs (an empty at the jib's end) | the cable hangs from where the built-in jib would end |

## Start from

- [`custom/make_your_own/models/crane.glb`](../../custom/make_your_own/models/crane.glb): a crane, Turret and Hook named
- [`custom/make_your_own/models/crate_load.glb`](../../custom/make_your_own/models/crate_load.glb): a load for it

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn), [Make Your Own Boat](../../custom/make_your_own/boat.tscn), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [High Seas](../../maps/high_seas.tscn)
