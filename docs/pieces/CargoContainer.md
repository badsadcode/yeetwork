<!-- Made by tools/make_guide.gd from scripts/mapkit/cargo_container.gd: change the comments there and run it again, not this page. -->
# CargoContainer

*Things in it: a Map Kit piece (Add Child Node > CargoContainer). Script: `scripts/mapkit/cargo_container.gd`.* [All the pieces](README.md)

A 40 ft shipping container (12.2 x 2.6 x 2.44 m: its bottom on the node, its length along X), in its company's paint:

- closed: solid; stack them.
- Lashed (on a Vessel: High Seas' top containers): its lashings can give (blasts, pushes, lightning, a storm's rolling wear them down; it creaks, then breaks loose as a heavy prop that slides about the deck). Yellow rods brace its ends.
- Open: hollow, its doors swung wide at one end (Doors Aft: the -X end, else +X), a lamp inside; Pickup: a pickup waits in it (a random power-up). A hideout.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Color** | `Color(0.12, 0.38, 0.75)` | Its paint. |
| **Lashed** | off | On a ship: its lashings wear down under blasts, pushes, lightning and a storm's rolling until it breaks loose as a heavy prop that slides about. |
| **Open** | off | Hollow, its doors swung wide at one end (go inside; a lamp hangs in it). |
| **Doors Aft** | off | Open: the doors are at its -X end (off: +X). |
| **Pickup** | off | Open: a random power-up waits inside. |

## Used in

[High Seas](../../maps/high_seas.tscn) (94)
