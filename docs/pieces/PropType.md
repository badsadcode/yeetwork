<!-- Made by tools/make_guide.gd from scripts/props/prop_type.gd: change the comments there and run it again, not this page. -->
# PropType

*Things in it: a type file (Create New > Resource > PropType). Script: `scripts/props/prop_type.gd`.* [All the pieces](README.md)

Your own prop, next to the built-in ones: a new crate, barrel, ball... It behaves like the built-in prop you pick (Behaves Like: a crate breaks into boards, a boom barrel blows up, a beach ball floats down, a battery powers a socket) with your model and your numbers. Make one: right-click a folder > Create New > Resource > PropType, save it next to your model, fill it in, and put it on a Prop Spawn's Type slot.

- Model: its origin in the middle of the prop (where it turns about).
- Size: the box it fills, in metres (0: the built-in one's); its collision is that box, a ball or a cylinder (Shape), or a mesh named "Collision" in your model (hidden in the game, made convex: keep it to a simple shape).
- Everything at 0 (or -1) is the built-in one's.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Display Name** | (empty) | Its name in the game (the shop, the HUD). |
| **Behaves Like** | `crate` | The built-in prop it acts like: how it breaks, blows up, floats, powers sockets. Choices: `crate`, `crate_big`, `barrel`, `boom_barrel`, `ball`, `beachball`, `anvil`, `plank`, `couch`, `tire`, `cone`, `fuse`, `boulder`, `platform`, `battery`, `gravestone`, `coffin`, `pumpkin`, `iron_ball`. |
| **Model** | (none) | Your model (origin in its middle). A mesh named "Collision" in it is its shape (made convex, hidden). |
| **Size** | `(0, 0, 0)` | The box it fills, metres (0: the built-in one's). |
| **Shape** | `auto` | auto: the "Collision" mesh in your model if it has one, otherwise the built-in one's shape. Choices: `auto`, `box`, `ball`, `cylinder`. |
| **Mass** | `0` | Kilograms (a crate 25, a barrel 40, an anvil 300; one gun lifts up to about 400). *(0 to 3000)* |
| **Bounce** | `-1` | 0 dead, 1 a superball (-1: the built-in one's). *(-1 to 1)* |
| **Toughness** | `0` | How hard a hit it takes to break it (impact energy, joules: a crate 9000, a barrel 15000); only for props that break (crates, barrels, planks, pumpkins, gravestones, coffins). *(0 to 100000)* |
| **Unbreakable** | off | Nothing breaks it. |
| **Breaks Into Parts** | off | When it breaks, it comes apart into its model's parts (each object in it: a plank, a pane, a hinge, named for what they're made of like a BreakableModel's: "Glass_", "Wood_", "Metal_"...): each flies off whole (a prop), glass shatters; instead of the built-in one's way of breaking. Behaves Like has to be a prop that breaks (a crate, a plank...). |
| **Color** | `Color(0, 0, 0, 0)` | The colour of what it breaks into, and of the built-in look if there's no model. |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Collision` | a mesh that is its shape (made convex, hidden in the game) | nothing is missed |

## Start from

- [`custom/make_your_own/oil_drum.tres`](../../custom/make_your_own/oil_drum.tres): an oil drum (with a Collision mesh)
- [`custom/make_your_own/models/drum.glb`](../../custom/make_your_own/models/drum.glb): its model
- [`custom/make_your_own/glass_cabinet.tres`](../../custom/make_your_own/glass_cabinet.tres): a glass cabinet that breaks into its parts
- [`custom/make_your_own/models/cabinet.glb`](../../custom/make_your_own/models/cabinet.glb): its model, parts named for their material

## Used in

[Glass Cabinet](../../custom/make_your_own/glass_cabinet.tres), [Oil Drum](../../custom/make_your_own/oil_drum.tres)
