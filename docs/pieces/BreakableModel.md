<!-- Made by tools/make_guide.gd from scripts/mapkit/breakable_model.gd: change the comments there and run it again, not this page. -->
# BreakableModel

*Building: a Map Kit piece (Add Child Node > BreakableModel). Script: `scripts/mapkit/breakable_model.gd`.* [All the pieces](README.md)

Your own model, breakable: a door of planks, a window (frame, glass, bars), a fence. Every separate part of it (every object in Blender: a plank, a pane, a post, a knob) breaks on its own, and how it breaks comes from its name:

- What it's made of: "glass", "wood", "metal", "stone", "concrete", "brick", "plaster" or "ice" anywhere in its name ("Glass_Pane", "Wood_Plank3"): how tough, how it shatters (glass into thin shards, wood into splinters along the part's longest side), its sound. A part named none of them: Material below.
- "Fixed" in its name ("Fixed_Frame"): it never breaks (and holds up what touches it).
- "Collision": hidden (use it in a prop, not here).

Parts hold onto the fixed parts, the ground (the model's lowest parts, with Anchor To Ground) and each other; a part left holding onto nothing falls off whole (a prop: grab it, throw it). A small part (under 0.3 m: a knob, a hinge) comes off whole when hit. The pieces of a broken part are cut from its own shape, from the hit outward, in its own material. Works like a BreakableSlab: everyone sees the same, monsters batter it (a MegaYeet gate), the shop repairs it, wood burns. Tear Off: the gravity gun rips it off (a door off its hinges): its loose parts (not the Fixed ones) come away together as one prop to carry and throw, and thrown hard it comes apart into its parts.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Model** | (none) | Your model (.glb, .blend, .tscn): every separate part breaks on its own, named for what it's made of (see above). |
| **Material** | `wood` | What a part with no material in its name is made of. Choices: `wood`, `glass`, `metal`, `concrete`, `brick`, `plaster`, `ice`. |
| **Hp Scale** | `1` | Toughness: multiplies every part's material (0.5 half as tough, 10 ten times). *(0.1 to 50, or more)* |
| **Anchor To Ground** | on | Its lowest parts stand on the ground and hold up the rest (a fence's posts, a door's frame); off: only the Fixed parts hold it (a sign hanging from a fixed bracket). |
| **Tear Off** | off | The gravity gun can rip it off: its loose parts come away together as one prop. |
| **Color** | `Color(0.6, 0.45, 0.3)` | The dust when a part breaks, and the colour fire and fragments fall back to. |

## Start from

- [`custom/make_your_own/models/door.glb`](../../custom/make_your_own/models/door.glb): a door of planks in a Fixed frame
- [`custom/make_your_own/models/window.glb`](../../custom/make_your_own/models/window.glb): a window: a Fixed frame, glass, a wooden mullion
- [`custom/make_your_own/models/fence.glb`](../../custom/make_your_own/models/fence.glb): a fence: posts and rails

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn), [Make Your Own Boat](../../custom/make_your_own/boat.tscn), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn) (4)
