# Make your own: every game object, your model, no code

Tomek's goal: every object in the game can get a new version with his own model and textures,
built in the Godot editor, without touching code. The old version stays; the new one sits next
to it. Every map can be rebuilt (and new ones made) from these pieces, and a guide explains how.

This is the plan. When each part is built, its recipe moves into `docs/MAPPING.md` (the
reference) and `docs/CUSTOM_MAPS_GUIDE.md` (step by step). **Phase 1 is done** (2026-11-01):
markers, your own pipes, drains, traps and props, starter models, the Make Your Own
Workshop. **Phase 2 is done** (2026-11-01): your own pickups (PickupType), Model slots on
flag stands and the big fan, breakable walls in your material, the map check's notes on
markers.

## The idea in one paragraph

You make a model in Blender. Inside it, you put **markers**: empties (or any object) with
agreed names. They tell the game where things happen ("Spout": the water comes out here)
and which bits move ("Boom": this part tilts). You drop the model on a game object's
**Model** slot, set its **settings** in the Inspector (how much water, how fast), and save it
as **your own version**. From then on it's a new object you can place anywhere, as often as
you like.

## Two kinds of game object

| Kind | Examples | Your new version is... |
|---|---|---|
| **Pieces**: placed in a map, stay where you put them | pipes, drains, traps, cranes, jump pads, doors, buttons, lights, machines, the Heart, goals, hoops, flag stands | a **scene**: place the piece, set its Model and settings, right-click > *Save Branch as Scene* (`my_pipe.tscn`). Drag that scene into any map. |
| **Things**: the game makes them, they fly about | crates, barrels, balls, pickups, monsters, boulders | a **type file** (`.tres`): New Resource > *PropType* (or *PickupType*, *MonsterType*); pick which built-in one it behaves like, then your model and numbers. Spawn pieces and the sandbox list take it; a type file in a map's folder is found by itself. |

Characters (the Yeets) and the gravity gun come last: their models move with animations, so
they need their own rules (see Phase 5).

## Markers: how the game finds things in your model

One list of names for the whole game, the same in every object (any depth in the model;
Blender empties become empty nodes when the model is imported, so they keep their name and
place). An object missing a marker uses its built-in spot (the node's origin, say), and the
map check (`--validate`) lists what it didn't find, so nothing silently breaks.

**Where things happen** (empties; "pointing" means the way an empty's arrow points, and the
guide will show how to turn it in Blender):

| Name | Used by | Means |
|---|---|---|
| `Spout` | pipes (Flood Valve), fountains | water comes out here, pointing its way |
| `Intake` | drains | water goes in here |
| `Emitter` | machines, chimneys, broken things | steam, smoke, sparks, drips come from here (exists: Fixture) |
| `Light` | lamps, machines, the Heart | the glow is here (exists: MapLight, Fixture) |
| `Use` | anything with Use (buttons, crane cab, the Heart, gates) | where the Use prompt shows and what you look at |
| `Seat` / `Stand` | crane cab, ship's wheel | where a Yeet stands to drive it |
| `Hook` | cranes, winches | the end of the cable: what it lifts hangs here |
| `Muzzle` | cannons, launchers, the gravity gun | shots and the beam start here |
| `Spawn` | rifts, chutes, pipes that drop props | things appear here |
| `Exit` / `Launch` | jump pads, lifts, slides | where you leave it, and which way |

**What moves** (exists for some pieces already: Cap, Plate, Wheel, Float, Plank, Net, Rotor,
Spin):

| Name | Means |
|---|---|
| `Spin` | turns all the time (fans, wheels, radar) at the object's speed setting |
| `Wheel` | turns while it's working (valves, winches) |
| `Turret` | turns left and right (crane top, cannon) |
| `Boom` | tilts up and down (crane arm) |
| `Cap` / `Plate` / `Float` / `Plank` / `Net` | as now (button, plate, float switch, seesaw, net) |
| `Door` / `Lid` / `Hatch` | opens (slides or swings: a setting) |

**Collision**: the piece keeps its own simple shape (a box of its Size) unless your model has
a mesh named `Collision` (or ending in `-col`, Godot's import rule): then that's what Yeets
bump into. For things that fly (props), it's turned into a convex shape automatically; keep
it simple (a few boxes).

**Textures and materials** come with your model (the `.glb` carries them). The map's walls
and floors (ArenaBlocks) already take any Godot material (**Custom Material**, with
**Texture Size**), so a brick wall can use your brick texture.

## Every object, where it stands today, what it needs

Legend: OK = works now; slot = needs a Model slot; markers = needs named parts; numbers =
its behaviour's numbers need to be settings; piece = must become a Map Kit piece first.

**Map Kit pieces (27 have a Model slot):** jump pad, lift, grapple point, rope anchor,
button, pressure plate, door, target, receptacle, exit, checkpoint, reset post, seesaw,
turntable, pulley, magnet, valve (pipe: `Spout`), drain (`Intake`), float switch, beacon,
contacts, goal, volley net, the Heart, lights, machines (Fixture), trap spots: **OK**.

| Object | Today | Needs |
|---|---|---|
| Trap spots (spikes, fire, mine) | done (Phase 1): Model, name, damage, slowing, burn, blast | |
| Pickups (first aid, power-ups) | done (Phase 2): PickupType files | |
| Props (crate, barrel, ball... 31 kinds) | done (Phase 1): PropType files | (later: in the sandbox's spawn list) |
| Flag stand, hoop, big fan | done (Phase 2): Model slots (fan: `Rotor`) | |
| Spinners, ball spots | spinner: put your model under it; ball spot: invisible | nothing |
| Fuse lines | the cord is drawn by the game | (a cord material, if wanted) |
| Walls, floors (ArenaBlock), breakable walls (BreakableSlab) | Custom Material (textures): OK | |
| Ship (rolls on the swell), the sea | High Seas code | piece |
| Crane, ship's horn, ladders, cargo containers | High Seas code | piece, slot, markers (`Turret`, `Boom`, `Hook`, `Seat`) |
| Monsters (7 kinds, the boss) | built-in looks | type files; models with animations (Phase 5) |
| Yeets, the gravity gun | built-in | Phase 5 (animations) |
| Shop pictures | rendered from the object's model | OK: your model shows up by itself |

## Phases

1. **The convention, and the things you asked about first.** The marker names above in one
   place in the code (so every object reads them the same way); `Spout` and `Intake` for
   pipes and drains; **PropType** files (new crates, barrels, anything that flies); trap
   spots with a Model slot and their numbers as settings; a guide chapter, *Make your own
   versions*, with three recipes: a pipe, spikes, a barrel (with a Blender file for each,
   markers already named, in `templates/`).
2. **Every remaining piece gets a slot and its markers**: pickups as type files, flag
   stands, hoops, fans, spinners, fuse lines; a Material slot on walls and floors; the map
   check reporting missing markers; a check that every object takes a model.
3. **High Seas as pieces**: the ship (a moving deck anything can ride), the sea, ladders, the
   crane (your own crane anywhere: a dock, a building site), the horn, containers. Then High
   Seas itself rebuilt as a Map Kit scene, so it's editable like the others.
4. **The guide**: a walkthrough that rebuilds one real map from scratch, and one that makes a
   brand-new map using a bit of everything; a page per object (what it does, its settings,
   its markers, a template model).
5. **Things that animate**: monsters as type files with your rigged models (which animation
   plays when: walk, hit, fall, climb), then the Yeets and the gravity gun (an art pack).
