<!-- Made by tools/make_guide.gd from scripts/mapkit/trap_spot.gd: change the comments there and run it again, not this page. -->
# TrapSpot

*MegaYeet: a Map Kit piece (Add Child Node > TrapSpot). Script: `scripts/mapkit/trap_spot.gd`.* [All the pieces](README.md)

MegaYeet: a place for a trap (a box, Size, its bottom on the node). Between waves a Yeet builds it with Use (or from the shop), paying its Cost out of the Fortress meter (or their Y$, by the match's Economy); built, it works on every monster that walks into it until the fortress falls:

- spikes: monsters crossing them are hurt and slowed.
- fire: a burning grate; monsters crossing catch fire.
- mine: blows up under the first monsters to step on it (then it's gone: build it again).

Put them where monsters will come: behind a gate, in a passage. Not built, it shows as a faint outline. (On or off like any puzzle piece: on while built.) Your own trap (Your Own Trap): your model for it built, its name (the Use prompt, the shop), and what it does to a monster in it: damage a second, how fast it lets one cross, how long it sets one alight, how big a blast it goes off with (then it's gone). Kind gives the numbers you leave at -1. Save the spot as a scene (right-click > Save Branch as Scene) and it's a new trap you can put anywhere; the shop lists it apart, with your model.

It has every [PuzzleNode](PuzzleNode.md) setting too (they're listed there).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `spikes` | What it is once built: spikes, fire (a grate that sets monsters alight) or mine (goes off once). Choices: `spikes`, `fire`, `mine`. |
| **Size** | `(4, 1, 4)` | Its box, metres (on the ground). |
| **Cost** | `0` | What it costs from the Fortress meter (0: the kind's usual: spikes 80, fire 120, mine 60). *(0 to 2000)* |

### Your own trap

| Setting | Default | What it does |
|---|---|---|
| **Trap Name** | (empty) | Its name (empty: the kind's). |
| **Model** | (none) | Your model for it, built (its origin in the middle of the spot, on the ground). |
| **Damage** | `-1` | Hurt a second (-1: the kind's: spikes 30). *(-1 to 1000)* |
| **Slows To** | `-1` | How fast a monster crosses it, 1 full speed (-1: the kind's: spikes 0.4). *(-1 to 1)* |
| **Burn** | `-1` | Sets them alight for this many seconds (-1: the kind's: fire 4). Fire hurts ghosts too. *(-1 to 30)* |
| **Blast** | `-1` | Goes off under the first one with a blast this big (metres; -1: the kind's: a mine 6), then it's gone (build it again). *(-1 to 20)* |

## Start from

- [`custom/make_your_own/thorn_trap.tscn`](../../custom/make_your_own/thorn_trap.tscn): a trap of your own (a thorn bed)
- [`custom/make_your_own/models/thorns.glb`](../../custom/make_your_own/models/thorns.glb): its model

## Used in

[Thorn Trap](../../custom/make_your_own/thorn_trap.tscn), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [The Fortress](../../maps/fortress.tscn) (8)
