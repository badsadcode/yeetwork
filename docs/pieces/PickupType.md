<!-- Made by tools/make_guide.gd from scripts/world/pickup_type.gd: change the comments there and run it again, not this page. -->
# PickupType

*Things in it: a type file (Create New > Resource > PickupType). Script: `scripts/world/pickup_type.gd`.* [All the pieces](README.md)

Your own pickup, next to the built-in ones: a first aid kit or a power-up with your model, name and numbers. Gives: what it does (health heals; speed, super, feather, iron give that boost, see Pickups). Make one: right-click a folder > Create New > Resource > PickupType, fill it in, and put it on a PickupSpawn's Type slot.

- Model: what floats over the pad (its origin in its middle; about half a metre across).
- Everything at 0 is the built-in one's.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Display Name** | (empty) | Its name in the game. |
| **Gives** | `health` | health heals; speed, super, feather and iron give that boost. Choices: `health`, `speed`, `super`, `feather`, `iron`. |
| **Heal** | `0` | Health it gives back (health only; 0: 50). *(0 to 100)* |
| **Lasts** | `0` | Seconds the boost lasts (power-ups; 0: the boost's usual). *(0 to 120)* |
| **Respawn** | `0` | Seconds until it's back after someone takes it (0: the usual). *(0 to 300)* |
| **Model** | (none) | Your model: it floats over the pad (about half a metre across). |
| **Color** | `Color(0, 0, 0, 0)` | The glowing ring under it (and the HUD's colour for it; clear: the boost's). |

## Start from

- [`custom/make_your_own/energy_drink.tres`](../../custom/make_your_own/energy_drink.tres): an energy drink
- [`custom/make_your_own/models/can.glb`](../../custom/make_your_own/models/can.glb): its model

## Used in

[Energy Drink](../../custom/make_your_own/energy_drink.tres)
