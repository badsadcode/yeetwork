# Co-op puzzle mode: design

**Status:** steps 1, 2 and 3 are built: plates, doors, logic (gate, window, sequence),
checkpoints, exit, buttons, targets, break sensors, key props that come back and the Reset
button; the mode with its clock and objective line; *Moving Day* rooms 1-3
(`maps/moving_day.tscn`) and the *Test Chambers* (`maps/test_chambers.tscn`: Heavy Decisions,
The Impossible Shot, Three Idiots One Door, Yeetapult, Windy Business); seesaws, turntables
and fans; the Use key (E) for buttons and Reset. The plan
below includes Tomek's answers and Noor's puzzle-mode notes (October 2026).

## The idea

A mode with **no bots and no frags**: 1–4 players get through a level together using the
physics they already have (the gravity gun, throwing, punting, gravity jumps, swimming,
fire and explosions), plus puzzle pieces built in the editor.

### Three rules (from Noor)

1. **No puzzle has only one solution.** If players find a ridiculous way through using the
   physics engine, *it counts*. Puzzles give players an interesting problem and the tools;
   they never check *how* it was solved, only that it was.
2. **Players never permanently break a puzzle.** Yeetwork is destructible, so someone will
   destroy the door, the target, the floor and probably their teammate. Important props come
   back when lost, rooms can be reset, and checkpoints are sensible.
3. **Celebrate ridiculous solutions.** The end screen cheers for chaos, not just speed.

Puzzles mix six kinds (Noor's categories), and later levels combine them:
logic (weights, switches, sequences), precision (throws, ricochets, moving targets),
construction (ramps, bridges, towers), destruction (collapse something just right),
chaos (chain reactions), and co-op (two or more Yeets have to work together).

## Building blocks

Everything is a Map Kit node with inspector settings, so new puzzles are level design, not
new code.

| Piece | Does | Status |
|---|---|---|
| **PressurePlate** | on while the weight on it reaches a mass (it really weighs: a big lump of rubble can solve it) | built |
| **PuzzleDoor** | slides open from inputs; can't be broken; also bridges and moving platforms | built |
| **PuzzleLogic** | AND / OR / invert / hold time | built |
| **Checkpoint**, **PuzzleExit** | respawn point, level end | built |
| **Target** | hit it with a thrown thing (optionally: of a kind, faster than a speed); stays on for a while or for good | built |
| **Button** | on while touched or pushed by anything (a prop, a punt, a thrown Yeet) | built |
| **Logic: time window / sequence** | "all three targets within 3 s", "in this order" | built |
| **Breakable as input** | a BreakableSlab that counts as "on" once broken (BreakSensor) | built |
| **Key props and reset** | important props respawn at home when they fall out of the level or get destroyed; a big red **Reset** button restores a room's props | built |
| **Seesaw** ("Yeetapult") | a physics plank on a hinge: drop something heavy on one end, launch the Yeet on the other | built |
| **Fan** | a wind cone players can grab and turn; blows props and Yeets (someone will fly into a wall) | built |
| **Rotating platform** | turntables (always or while switched on) | built |
| **Launchers** | springs, cannons (jump pads exist) | later |
| **Receptacle**, **collectible**, **fragile package** | deliver and collect objectives | after |
| **Magnets**, **ropes and pulleys**, **electricity / ice** | Noor's later mechanics | later |

Already there and useful: jump pads, lifts, wind volumes, water (floating props, putting
out fires), fire (burning wood, burning boom barrels), explosions, breakable slabs, the gun's
freeze (a frozen crate is a platform).

## Test chambers

Noor's suggestion: six small chambers, one mechanic each, then combine them.

1. **Heavy Decisions**: a door needs 100 kg on a plate. Barrels, crates, a couch, a breakable
   statue whose rubble is heavy, or just stand on it together.
2. **The Impossible Shot**: a target behind obstacles. Bank a ball off angled walls, or
   punch through the (breakable) walls. Both count.
3. **Yeetapult**: a seesaw; one Yeet stands on one end, another drops an anvil on the other.
   The flyer lands on a ledge and lowers a bridge for everyone.
4. **Windy Business**: a big fan across the room; turn it, block it with crates, or ride it.
5. **Structural Engineering (Gone Wrong)**: a platform on breakable pillars holds a heavy
   ball; break the right pillars to roll the ball into the goal.
6. **Hot Potato**: carry one burning thing through a course to light a beacon. Wood catches,
   water puts it out, boom barrels are everywhere.

Later combinations: **Three Idiots, One Door** (three targets within a short window: easy
with three players, possible for one clever player with a ricochet), **Yeet Bowling**
(knock a pile into a chain reaction), **Pass the Yeet** (throw a lit boom barrel through a
hatch, passing it between players before it goes off), **The Great Escape** (counterweights
and ropes, once ropes exist).

## Linear and open levels (Tomek)

Both:
- **Linear** levels are a chain of rooms (Moving Day, the test chambers). Good for learning.
- **Open** levels are a hub with several objectives at once, so the team has to split up:
  for example a warehouse whose main gate needs three fuses, one in each wing, and one wing
  needs two people (two plates far apart, or a seesaw). Objectives can be done in any order;
  the HUD lists all of them ("Fuses 1/3", "Gate"). Built with the same pieces (a fuse is a
  key prop dropped in a receptacle).

## Scoring (approved by Tomek)

All optional for the players:
- **Time**, with a bronze / silver / gold target time set per level in MapSettings.
- **End screen** with fun stats: time, props destroyed, times a friend yeeted you, deaths,
  the longest throw.
- **Awards** that celebrate *how* it went (Noor's list, no effect on score):
  - *Big Brain Yeet*: solved it with the level's own mechanisms (every plate, target and
    door on the way was used).
  - *Structural Disagreement*: destroyed most of the breakable stuff on the way.
  - *Unscheduled Flight*: a Yeet was thrown or launched into the exit or a checkpoint.
  - *Task Failed Successfully*: an objective switched on within a few seconds of an
    explosion or a chain of falling things.
  - *Certified Yeet Engineer*: reached the exit without switching a mechanism on (went over,
    around or through instead).

The game can detect all of these from what it already tracks (puzzle states, breaks,
explosions, throws).

## Rules and flow

- Mode `Puzzle (co-op)`. Bots never join. One team: friends can't hurt each other with
  props or bumps; falls, fire, acid and explosions still count. Death respawns you at the
  last checkpoint after 3 s.
- HUD: the clock and the current objective (several for open levels).
- Server-authoritative: pieces run on the host and sync their state; clients animate. Late
  joiners get the current state.

## Moving Day (the first level)

Built: room 1 (a crate on a plate), room 2 (two heavy plates at once), room 3 (a moat:
float barrels, build a bridge, freeze a crate). To come: a delivery room and a finale.

## The Lost Yeet (approved by Tomek)

Yeets are a species in this world, and some of them get into trouble: a friendly, helpless
NPC Yeet stuck somewhere (in a cage, on an island, behind a wall, in a flooding room) that
the team frees and carries to the exit with the gravity gun, like escorting a VIP. Dropped
from too high it gets dizzy, not hurt; thrown, it screams happily. A level can have one to
rescue, or several as a bonus objective.

## Water and fire puzzles (Tomek's idea)

**Flood water**: a 2.5D flood simulation for puzzle areas (a Map Kit **FloodZone**). The area
is a grid of columns, each holding a water height; water flows to lower neighbours, walls
come from the level's collision. Much cheaper than true 3D voxel water and fast enough for
the Steam Deck (a 64x64 grid), and it covers almost everything:
- **Floods**: a valve (a puzzle output) fills a room; break a wall and the water pours out
  through the hole; drains empty it.
- **Flushing**: the flow has a speed and direction that carries Yeets and props along, through
  a gap or into a pit.
- **Floating**: rising water lifts crates and barrels toward ledges; a barrel raft rises with
  the flood.
- **Water levels as switches**: a float switch turns on when the water reaches it.
- The host runs it and sends the water heights a few times a second; everyone sees the same.
- Limits: no water on two floors of the same area, and no arcs of water through the air
  (waterfalls and pipe outflows between areas are drawn as effects).
- **Prior art: Tomek's GangTheGame** (`F:\Codex\GangTheGAME\Source\Water`, read only) has
  exactly this model working in C#: `WaterField` (virtual-pipes shallow water, mass
  conserved, only the wet area stepped, walls found by raycasting the level's collision),
  `WaterNode` (host steps at 60 Hz; changed 16x16 chunks sent as millimetre depths, zstd,
  5 Hz; full state to joiners; one surface mesh per chunk), `WaterWaves` (per-peer visual
  ripples and wakes fed to the shader as a texture), hydrants/taps/drains, current pushing
  floating props, bodies shoving bow waves, and hoses with jets. Port the ideas to GDScript;
  Yeetwork's own water look (liquid shaders) draws the surface.
- **Cost measured** (GDScript port of the flow step, the whole grid flowing, Tomek's PC):
  16x16 m at 0.5 m cells 0.66 ms per step, 24x24 m 1.5 ms, 32x32 m 2.6 ms; at 30 steps a
  second that's 2-8% of one core, host only. A Steam Deck host handles a 24 m flood room.

**Fire** (the fire system exists: burning, spreading, burning down, water puts it out):
- **Beacons and torches**: on when lit (carry fire to them).
- **Fuse lines**: burn from one end to the other, then trigger something.
- **Wooden barriers** that burn away.
- **Ice blocks** that melt near fire and become water in a FloodZone.
- Water and fire together: a flood puts fires out; a burning barrel floats across water still
  burning.

## Build order (revised)

1. ~~Plates, doors, logic, checkpoints, exit, the mode, Moving Day rooms 1-3.~~ Done.
2. ~~Never stuck, and more switches: key props, Reset, Target, Button, window and sequence
   logic, breakables as inputs; Test Chambers with Heavy Decisions, The Impossible Shot and
   Three Idiots One Door.~~ Done.
3. ~~Mechanisms: Seesaw, Fan, Turntable; Yeetapult and Windy Business in the Test Chambers.~~
   Done.
4. **Scoring**: end screen, medals, the awards.
5. **Lost Yeet** and an **open level**: the NPC to rescue, receptacles, collectibles, several
   objectives on the HUD, the warehouse.
6. **Water and fire**: FloodZone (flood, flush, float, float switches, valves and drains),
   beacons, fuse lines, burning barriers, ice. A flood chamber and a fire chamber.
7. Chambers 5 and 6, Moving Day rooms 4-5 (delivery and a Lost Yeet), Pass the Yeet.
8. Later: magnets, ropes and pulleys, electricity.

## Answered

Scoring: yes. Lost Yeet: yes. Levels: both linear and open. Water and fire puzzles: planned
(step 6; can move earlier).
