<!-- Made by tools/make_guide.gd from scripts/mapkit/map_light.gd: change the comments there and run it again, not this page. -->
# MapLight

*The map: a Map Kit piece (Add Child Node > MapLight). Script: `scripts/mapkit/map_light.gd`.* [All the pieces](README.md)

A light for dark maps (and any map): a bulb, a lamp post, a wall lamp, a candle, a torch, a spotlight or a neon tube, with its own little model and a light that can flicker. With Inputs it's a puzzle piece: on while its inputs are on ("restore the power and the lights come on"); without, it's always on.

- Lamp post: put the node on the ground. Wall lamp: on a wall, facing out (local +Z). Spotlight: it shines along local -Z (point it like a camera). Neon: a 1.2 m tube along X.
- A Model (or the map theme's light_<kind>) replaces the look; a child named "Light" in it is where the light shines from.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `bulb` | Its look and its light: bulb, lamp_post (on the ground), wall_lamp (on a wall, facing +Z), candle, torch, spotlight (shines along -Z), neon (a 1.2 m tube along X). Choices: `bulb`, `lamp_post`, `wall_lamp`, `candle`, `torch`, `spotlight`, `neon`. |
| **Color** | `Color(1.0, 0.82, 0.55)` | The light's colour. |
| **Energy** | `1` | Brightness (1 = the usual for its kind). *(0 to 8)* |
| **Reach** | `0` | How far it reaches, metres (0 = the usual for its kind). *(0 to 60)* |
| **Flicker** | `none` | none, candle (a gentle wobble), faulty (on, with sudden drop-outs), strobe, pulse (slow). Choices: `none`, `candle`, `faulty`, `strobe`, `pulse`. |
| **Shadows** | off | Cast shadows (lovely, costs more; only on High graphics in the game). |
| **Model** | (none) | Your own model for it (a scene: an imported .glb...), instead of the built-in look and the map theme's. |
| **Breakable** | on | Breaks when something hits it hard (a flying prop, a blast, a push, lightning): it goes dark with a burst of glass (a candle or a torch is blown out), and comes back on after Repair Time seconds (0: stays broken until a Puzzle Reset over it). |
| **Repair Time** | `40` | Seconds until it flickers back on after it's smashed (0: until a PuzzleReset over it). *(0 to 600)* |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Light` | where the light shines from | nothing is missed |

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (6), [Haunted Yard](../../maps/haunted_yard.tscn) (36)
