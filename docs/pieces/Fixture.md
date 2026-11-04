<!-- Made by tools/make_guide.gd from scripts/mapkit/fixture.gd: change the comments there and run it again, not this page. -->
# Fixture

*Things in it: a Map Kit piece (Add Child Node > Fixture). Script: `scripts/mapkit/fixture.gd`.* [All the pieces](README.md)

Set dressing that does something: a model (yours, the map theme's fixture_<kind>, or a built-in placeholder) that can hum, buzz or crackle, spin a part, shake, sway, puff steam or smoke, spark, drip, glow, hurt whoever touches it (hot, electric), shake the camera nearby, break when hit hard (sparks, silence, smoke; it comes back), and switch on and off with puzzle wiring (it winds up and down). Everything is optional.

- Kind: a built-in placeholder look and its usual behaviour ("auto" settings below follow it): generator, engine, fan, pump, pipes, radio, or box (a plain block).
- Your model: parts named "Spin" (turns), "Emitter" (where steam, smoke... come from) and "Light" (where its glow is) are used if they're there.
- Inputs: on while its inputs are on ("power restored: the machines start up"); without inputs it's always on.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `generator` | The built-in look and its usual behaviour (what "auto" and -1 below mean): generator, engine, fan, pump, pipes, radio, or box (a plain block). Choices: `box`, `generator`, `engine`, `fan`, `pump`, `pipes`, `radio`. |
| **Model** | (none) | Your own model (a scene: an imported .glb...), instead of the built-in look and the theme's. |
| **Solid** | on | Players bump into it (a box round its look); off for things to walk through or past. |

### Sound

| Setting | Default | What it does |
|---|---|---|
| **Sound** | `auto` | A looping sound: auto (the kind's), none, or one of the game's ambient loops (a recording in assets/sounds/ named after it replaces it). Choices: `auto`, `none`, `hum`, `buzz`, `engine`, `fan`, `steam`, `radio`. |
| **Custom Sound** | (none) | Your own looping sound instead (an .ogg or .wav: set it to loop in its import settings). |
| **Volume Db** | `0` | How loud, decibels (0: as recorded; -6 about half). *(-30 to 12)* |
| **Reach** | `14` | How far it carries (metres). *(2 to 80)* |
| **Pitch** | `1` | Higher (above 1) or lower. *(0.3 to 3)* |
| **One Shot Sounds** | (none) | Now and then a one-off sound too: game sound names ("metal", "creak", "zap", "sizzle"...) or your own recordings, every few seconds (random within One Shot Every). |
| **One Shot Recordings** | (none) | Your own recordings for the one-off sounds. |
| **One Shot Every** | `(4, 10)` | Seconds between one-off sounds: at random between x and y. |

### Motion

| Setting | Default | What it does |
|---|---|---|
| **Spin Speed** | `-1` | Turns per second of the part named "Spin" (-1: the kind's). *(-1 to 20)* |
| **Spin Axis** | `(0, 0, 1)` | The axis the "Spin" part turns about (its own). |
| **Vibrate** | `-1` | Shaking, metres (-1: the kind's). *(-1 to 0.1)* |
| **Sway** | `0` | Swinging to and fro, degrees, and how fast (a hanging sign, a buoy). *(0 to 45)* |
| **Sway Speed** | `0.5` | Swings per second. *(0.05 to 4)* |

### Effect

| Setting | Default | What it does |
|---|---|---|
| **Effect** | `auto` | From the part named "Emitter" (or its top): auto, none, steam, smoke, sparks, drips. Choices: `auto`, `none`, `steam`, `smoke`, `sparks`, `drips`. |
| **Effect Rate** | `1` | How much of the effect: 1 the usual, 2 twice as much. *(0.1 to 4)* |

### Light

| Setting | Default | What it does |
|---|---|---|
| **Light Color** | `Color(0.5, 1.0, 0.6)` | Its glow's colour. |
| **Light Energy** | `-1` | A glow from the part named "Light" (-1: the kind's; 0: none). *(-1 to 8)* |
| **Light Pulse** | `0` | Pulses per second (0: steady). *(0 to 10)* |

### Breaking

| Setting | Default | What it does |
|---|---|---|
| **Breakable** | off | Breaks when something hits it hard (a flying prop, a blast, a push, lightning): sparks, it falls silent and smokes; back after Repair Time seconds (0: until a PuzzleReset over it). |
| **Repair Time** | `40` | Seconds until it's mended after breaking (0: until a PuzzleReset over it). *(0 to 600)* |

### Touch

| Setting | Default | What it does |
|---|---|---|
| **Hazard** | `none` | Hurts whoever comes within Hazard Radius (of its Emitter, or its middle) while it runs: hot (burns, sets alight) or electric (a zap and a jolt). Choices: `none`, `hot`, `electric`. |
| **Hazard Radius** | `1.2` | How close is too close, metres. *(0.3 to 6)* |
| **Shake** | `-1` | Shakes the camera of anyone nearby while it runs (-1: the kind's). *(-1 to 1)* |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Spin` | turns while it runs (about Spin Axis) | nothing is missed |
| `Emitter` | where steam, smoke, sparks and drips come from | nothing is missed |
| `Light` | where its glow is | nothing is missed |

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn), [The Foundry](../../maps/foundry.tscn) (11), [High Seas](../../maps/high_seas.tscn) (13), [The Pump House](../../maps/pump_house.tscn) (6)
