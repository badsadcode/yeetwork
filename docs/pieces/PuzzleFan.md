<!-- Made by tools/make_guide.gd from scripts/mapkit/puzzle_fan.gd: change the comments there and run it again, not this page. -->
# PuzzleFan

*Puzzles: a Map Kit piece (Add Child Node > PuzzleFan). Script: `scripts/mapkit/puzzle_fan.gd`.* [All the pieces](README.md)

A big industrial fan, placed here, blowing along this node's forward direction (-Z). The fan itself is a prop: players can grab it with the gravity gun, carry it and aim it, put it on a turntable, or block its wind with crates. It blows while its Inputs are on (always, without inputs). Light things fly, heavy ones barely move, and the Yeets get pushed too (someone will fly into a wall). It comes back home if lost, and a PuzzleReset puts it back.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Model** | (none) | Your own model for the fan (it's a prop: it keeps the built-in fan's size and weight); a part named "Rotor" spins. Or the map theme's fan. |
| **Strength** | `32` | Wind acceleration near the fan (m/s^2). Players: this times Player Push; props: more for light things (a beach ball ~2x), less for heavy ones (an anvil ~5%). Gravity is 24. *(1 to 120)* |
| **Reach** | `12` | How far it blows, metres. *(1 to 40)* |
| **Radius** | `1.2` | How wide its stream is, metres. *(0.3 to 4)* |
| **Player Push** | `1` | How hard it blows Yeets, times Strength. *(0 to 3)* |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Rotor` | spins while it blows | nothing spins |

## Start from

- [`custom/make_your_own/models/fan.glb`](../../custom/make_your_own/models/fan.glb): a fan, its Rotor named

## Used in

[Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [Test Chambers](../../maps/test_chambers.tscn)
