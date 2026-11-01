<!-- Made by tools/make_guide.gd from scripts/mapkit/pickup_spawn.gd: change the comments there and run it again, not this page. -->
# PickupSpawn

*Things in it: a Map Kit piece (Add Child Node > PickupSpawn). Script: `scripts/mapkit/pickup_spawn.gd`.* [All the pieces](README.md)

A pickup floating over a pad on the floor: walk through it to take it. It comes back after a while. First aid kits heal; power-ups give a boost for a few seconds (see Pickups for what each one does). Put the node on the floor: the item floats a metre up. The host can turn power-ups (or all pickups) off; the Puzzle mode has none. Type: a pickup of your own (a PickupType: your model, name and numbers) in place of Kind.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `health` | What it gives: health (+50), health_big (+100), speed, super, feather, iron, or random (a different power-up each time). Choices: `health`, `health_big`, `speed`, `super`, `feather`, `iron`, `random`. |
| **Respawn** | `0` | Seconds until it's back after someone takes it (0: the usual for its kind). *(0 to 300)* |
| **Type** | (none) | Your own pickup (a PickupType file) in place of Kind. |

## Start from

- [`custom/make_your_own/energy_drink.tres`](../../custom/make_your_own/energy_drink.tres): a pickup of your own for its Type slot (see PickupType)

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (6), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [Courtyard](../../maps/courtyard.tscn) (5), [Facing Yeets](../../maps/facing.tscn) (6), [Haunted Yard](../../maps/haunted_yard.tscn) (4), [Hoops Court](../../maps/hoops_court.tscn) (2), [Lagoon](../../maps/lagoon.tscn) (5), [Yeetwork Prime](../../maps/prime.tscn) (6), [Volley Beach](../../maps/volley_beach.tscn) (2), [Yeetball Stadium](../../maps/yeetball_stadium.tscn) (2)
