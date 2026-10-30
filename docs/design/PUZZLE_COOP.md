# Co-op puzzle mode: design

**Status:** step 1 is built (plates, doors, logic, checkpoints, exit, the mode with its
clock and objective line, and rooms 1-3 of *Moving Day*, `maps/moving_day.tscn`). The plan
below was revised with Tomek's answers and Noor's puzzle-mode notes (October 2026). The next
step waits for Tomek's go.

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
| **Target** | hit it with a thrown thing (optionally: of a kind, faster than a speed); stays on for a while or for good | next |
| **Button** | on while touched or pushed by anything (a prop, a punt, a thrown Yeet) | next |
| **Logic: time window / sequence** | "all three targets within 3 s", "in this order" | next |
| **Breakable as input** | a BreakableSlab or structure that counts as "on" once broken (destruction puzzles) | next |
| **Key props and reset** | important props respawn at home when they fall out of the level or get destroyed; a big red **Reset** button restores a room's props | next |
| **Seesaw** ("Yeetapult") | a physics plank on a hinge: drop something heavy on one end, launch the Yeet on the other | after |
| **Fan** | a wind cone players can grab and turn; blows props and Yeets (someone will fly into a wall) | after |
| **Rotating platform**, **launcher** | turntables, springs, cannons (jump pads exist) | after |
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

## Scoring (Tomek: maybe, but how?)

A light proposal, all optional for the players:
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

## The "Lost Yeet" (explained)

An idea from the first proposal: a friendly, helpless NPC Yeet stuck somewhere (in a cage,
on an island, behind a wall) that the team has to free and carry to the exit with the
gravity gun, like escorting a VIP. Dropped from too high, it gets dizzy, not hurt; thrown,
it screams happily. It's an objective type, not a requirement: say if you want it.

## Build order (revised)

1. ~~Plates, doors, logic, checkpoints, exit, the mode, Moving Day rooms 1-3.~~ Done.
2. **Never stuck, and more switches**: key props that respawn, the Reset button, Target,
   Button, time-window and sequence logic, breakables as inputs. Chambers 1 and 2.
3. **Mechanisms**: Seesaw, Fan, rotating platform. Chambers 3 and 4.
4. **Scoring**: end screen, medals, the awards.
5. **Open level**: receptacles, collectibles, several objectives on the HUD, the warehouse.
6. Chambers 5 and 6, Moving Day rooms 4-5 (delivery; the Lost Yeet if wanted), Pass the Yeet.
7. Later: magnets, ropes and pulleys, electricity and ice.

## Questions for Tomek

1. Does the scoring proposal (time with medals, fun stats, awards) sound right?
2. Lost Yeet: yes or no?
3. Go ahead with step 2?
