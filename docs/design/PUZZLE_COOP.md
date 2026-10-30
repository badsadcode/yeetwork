# Co-op puzzle mode: design proposal

**Status:** step 1 of the build order is done (plates, doors, logic, checkpoints, exit,
the mode and its HUD line, and rooms 1-3 of *Moving Day*, `maps/moving_day.tscn`). Open
questions at the end still need answers before step 3.

## The idea

A mode with **no bots and no frags**: 1–4 players get through a level together using the
physics they already have (the gravity gun, throwing, punting, gravity jumps, swimming,
fire and explosions), plus a few new puzzle pieces. Each level is a short chain of rooms;
the team wins by reaching the exit, and can be scored by time and by how much chaos they
caused on the way.

It should feel like Yeetwork, not like a quiet puzzle game: puzzles have physical,
slightly silly solutions, several of them usually work, and failing is funny rather than
punishing.

## What players do

| Goal | Example |
|---|---|
| **Collect** | Gather 3 golden pumpkins scattered around the room and drop them in the cauldron. |
| **Open doors** | Put enough weight on a pressure plate (a crate, an anvil, or a friend standing still). |
| **Physics puzzles** | Build a ramp from planks, stack crates to reach a ledge, float barrels across water as stepping stones, punt a wall to gravity-jump a gap. |
| **Rescue** | A "Lost Yeet" (a captive NPC, harmless, can't fight) is stuck behind a breakable wall or on an island. Free it, then carry it with the gravity gun to the exit. If it's dropped from too high it gets dizzy (not hurt). |
| **Deliver** | Carry a fragile package (glass vase, egg crate) to the other side of the level. It breaks if it hits hard: careful gun carrying or throwing it to a teammate. |

## New pieces (Map Kit nodes)

Everything is a Map Kit node, so puzzle levels are built in the editor like any map.

- **PressurePlate**: activates while the weight on it is at least *Required Mass*
  (players count as ~70). Outputs a signal.
- **Button**: hit it (with a prop, a punt or a thrown player) to toggle or pulse.
- **Door / Gate**: opens while its input is active (or stays open once opened). Slides,
  swings or lifts. Doors that can't be broken, so the puzzle can't be skipped by brute force
  (but breakable slabs remain an intended alternative route where the designer wants one).
- **Logic**: AND / OR / timer / sequence nodes, wired by NodePath in the inspector. Two
  plates far apart that must be held at once make players split up and cooperate.
- **Receptacle**: a basket, cauldron or chute that accepts props of a chosen kind (or the
  package / the Lost Yeet) and counts them.
- **Collectible**: a prop with a glow and a counter in the HUD.
- **Checkpoint**: respawn point that the team reaches together; falling or burning respawns
  you at the last checkpoint after 3 s (no score loss).
- **Exit**: the level ends when every living player is inside (or the delivery arrives).
- **Hint sign**: a short in-world text, optional, for the first levels.

Existing pieces that become puzzle tools: jump pads, lifts, wind volumes, water (floating
props), fire (burn a wooden barrier; a burning crate as a timed light source), boom
barrels (blast a wall open), breakable slabs, the gun's freeze (a frozen crate as a
platform).

## Rules and flow

- Mode `Puzzle (co-op)` on the Play page, only offered on maps whose MapSettings say they
  are puzzle maps. The bot count is ignored.
- One team, everybody friendly. No damage between players; fall and fire damage still
  apply, death is a respawn at the checkpoint.
- HUD: objective line ("Open the gate 0/2", "Pumpkins 1/3"), a timer, and at the end a
  results screen: time, props destroyed, times yeeted by a friend.
- Server-authoritative like everything else: plates, doors and counters run on the host and
  sync their state; clients only animate. Late joiners get the current state.

## A first level, to prove it

**"Moving Day"** (on a small island, sunny day):

1. Room 1 (tutorial): a door opens when a crate is put on the plate. A sign says so.
2. Room 2: two plates on opposite sides; both must be held at once (two players, or one
   player plus a crate, or an anvil thrown just right).
3. Room 3: a moat: float barrels across, or freeze a crate mid-air with the gun and hop.
4. Room 4: deliver the fragile vase across a windy bridge to the receptacle.
5. Finale: free the Lost Yeet from a wooden cage by burning it (bonfire nearby, carry a
   burning plank) or blowing it up (boom barrel), and carry them to the exit.

## Build order (if approved)

1. PressurePlate, Door, Logic AND/OR, Exit, Checkpoint, the mode itself and its HUD line.
2. "Moving Day" rooms 1–3, playtested with 1 and 2 players.
3. Receptacle, Collectible, Button, fragile Package.
4. Lost Yeet NPC (a CharacterModel on a ragdoll-able body, idle animations, carried with
   the gun, panicked face when thrown).
5. Rooms 4–5, results screen, docs (MAPPING.md section for puzzle nodes).

## Open questions for Tomek

1. Should the mode have **scoring** (time, medals) or just completion?
2. **Lost Yeet**: one per level, or several to rescue as a collectible?
3. Should levels be **linear** (room after room) or **open** (several objectives in any order)?
4. Any must-have puzzle from Noor's ideas to include in the first level?
