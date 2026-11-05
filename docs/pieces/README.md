<!-- Made by tools/make_guide.gd from the pieces' scripts: run it again, don't edit this page. -->
# Map Kit pieces

A page for every piece you can put in a map, and every type file (your own props and pickups, a theme): what it does, its settings, the markers your model can have, the starter models to begin from and the maps that use it. Building your first map: [CUSTOM_MAPS_GUIDE.md](../CUSTOM_MAPS_GUIDE.md). A real map rebuilt piece by piece: [REBUILD_A_MAP.md](../REBUILD_A_MAP.md). A new map from an idea: [MAKE_A_NEW_MAP.md](../MAKE_A_NEW_MAP.md). The whole kit at a glance: [MAPPING.md](../MAPPING.md).

The same descriptions are the tooltips in Godot's Inspector: hover over a setting.

## The map

One MapSettings per map; where players start; lights; a look for the whole map.

| Piece | What it is |
|---|---|
| [MapSettings](MapSettings.md) | The map's name and its world: the sky and light, the weather, a sea round it, how far down is death, its theme, what the Puzzle mode needs. |
| [SpawnPoint](SpawnPoint.md) | Where players appear. |
| [MapLight](MapLight.md) | A light for dark maps (and any map): a bulb, a lamp post, a wall lamp, a candle, a torch, a spotlight or a neon tube, with its own little model and a light that can flicker. |
| [MapTheme](MapTheme.md) | A map's look in one file: a model for each kind of Map Kit piece and prop. |

## Building

What the map is made of, and what moves you round it.

| Piece | What it is |
|---|---|
| [ArenaBlock](ArenaBlock.md) | A solid box with the arena's look (soft panels, a warm to cool gradient): floors, walls, platforms, ramps. |
| [BreakableSlab](BreakableSlab.md) | A destructible wall, floor or bridge. |
| [BreakableModel](BreakableModel.md) | Your own model, breakable: a door of planks, a window (frame, glass, bars), a fence. |
| [JumpPadNode](JumpPadNode.md) | A pad that throws players and props through the air to a spot: up to a ledge, across a gap. |
| [LiftPlatform](LiftPlatform.md) | A platform moving to and fro between where it is and Travel (from there), a round trip every Period seconds, pausing briefly at each end: a lift, a ferry over a gap. |
| [Ladder](Ladder.md) | A ladder up a wall (a building, a ship's side, out of a pool or the sea): walk up to it facing the wall and hold forward (or Jump) to climb, back (or Crouch) to go down, let go and you hang on; at the top it lifts you up and over the edge. |
| [GrapplePoint](GrapplePoint.md) | A ring to grapple onto. |
| [HazardVolume](HazardVolume.md) | A box that does something to whatever is in it, by Kind: acid or lava (a glowing pool that hurts and bounces you up), water (a pool to swim in; wood and rubber float), kill (instant death: under a void), wind (a constant push: an updraft) or fire (a burning place: flames over the bottom of the box that set players and wood alight). |
| [Spinner](Spinner.md) | Slowly turns its children around its local Y axis in game (decorations: Prime's orb ring, Facing's crystal). |
| [AnimatedModel](AnimatedModel.md) | Your own model, moving the way you animated it in Blender: a windmill's sails turning, a sign swinging, a buoy bobbing, a piston, a platform sliding to and fro, a drawbridge. |

## Things in it

Props, pickups and machines; your own kinds of prop and pickup are files (a type).

| Piece | What it is |
|---|---|
| [PropSpawn](PropSpawn.md) | A physics prop placed in the map. |
| [PropType](PropType.md) | Your own prop, next to the built-in ones: a new crate, barrel, ball... |
| [PickupSpawn](PickupSpawn.md) | A pickup floating over a pad on the floor: walk through it to take it. |
| [PickupType](PickupType.md) | Your own pickup, next to the built-in ones: a first aid kit or a power-up with your model, name and numbers. |
| [Fixture](Fixture.md) | Set dressing that does something: a model (yours, the map theme's fixture_<kind>, or a built-in placeholder) that can hum, buzz or crackle, spin a part, shake, sway, puff steam or smoke, spark, drip, glow, hurt whoever touches it (hot, electric), shake the camera nearby, break when hit hard (sparks, silence, smoke; it comes back), and switch on and off with puzzle wiring (it winds up and down). |
| [Crane](Crane.md) | A crane (a dock, a building site, a ship's deck): it slews to and fro on its own, a load hanging from its jib on a cable. |
| [Horn](Horn.md) | A horn (a ship's on its bridge, a factory whistle, a stadium klaxon): walk up and press Use to sound it, a deep blast everyone hears. |
| [CargoContainer](CargoContainer.md) | A 40 ft shipping container (12.2 x 2.6 x 2.44 m: its bottom on the node, its length along X), in its company's paint: - closed: solid; stack them. |

## Water and ships

Water that floods and drains, and ships riding the sea.

| Piece | What it is |
|---|---|
| [FloodZone](FloodZone.md) | Flood water for puzzles: a 2.5D water grid over the box (Size, standing on this node; keep it unrotated). |
| [FloodValve](FloodValve.md) | A pipe that pours water into the FloodZone it's in while its inputs are on (always, with no inputs): fill a room, raise a raft, flush a corridor. |
| [FloodDrain](FloodDrain.md) | A grate in the floor that takes water out of the FloodZone it's in, while its inputs are on (always, with no inputs): open the drain to empty the room. |
| [FloatSwitch](FloatSwitch.md) | A float on a post: on while the water in its FloodZone stands at least Level above the node (the float rides up the post and its lamp turns green). |
| [Vessel](Vessel.md) | A ship, a boat, a raft: everything under this node rides the sea's swell together, heaving, pitching and rolling the way High Seas' ship does (the same on every player's screen, with nothing sent). |
| [ShipHold](ShipHold.md) | Below deck on a Vessel (an engine room, a cargo hold): a box (Size, standing on this node, lined up with the ship) the sea stays out of however far she heels, and where bots knocked down a hatch find their way out: up the Ladders whose foot is in it. |

## Modes

What Capture the Flag and the sports need.

| Piece | What it is |
|---|---|
| [FlagStand](FlagStand.md) | Team flag base for Capture the Flag (needs one Red and one Blue). |
| [BallSpot](BallSpot.md) | Where the ball is put for a kickoff in Yeetball (and after it's lost). |
| [GoalZone](GoalZone.md) | A football goal for Yeetball: posts, a crossbar and a net, its mouth facing local +Z (turn it toward the pitch). |
| [Hoop](Hoop.md) | A basketball hoop for YeetHoops: a pole, a backboard to bank shots off, a solid rim and a see-through net, the rim facing local +Z (turn it toward the court). |
| [VolleyNet](VolleyNet.md) | A YeetVolley court: the net across the middle (posts, a solid net the ball and players bounce off) and the court lines on the floor. |

## MegaYeet

The fortress, the monsters' rifts, its zones and traps.

| Piece | What it is |
|---|---|
| [FortressHeart](FortressHeart.md) | MegaYeet: what the players defend (put one at the fortress's centre). |
| [MonsterSpawn](MonsterSpawn.md) | MegaYeet: where monsters come from (a rift in the ground, Radius across). |
| [MonsterType](MonsterType.md) | MegaYeet: your own monster, joining the waves beside the built-in ones. |
| [DefenseZone](DefenseZone.md) | MegaYeet: a zone of the fortress (a box, Size, its bottom on the node). |
| [TrapSpot](TrapSpot.md) | MegaYeet: a place for a trap (a box, Size, its bottom on the node). |

## Adventure

The Adventure mode: a few maps linked by a story (files, no code).

| Piece | What it is |
|---|---|
| [Adventure](Adventure.md) | An adventure for the Adventure mode: a few maps linked by a story, played together, each chapter's PuzzleExit leading everyone on to the next (progress is saved on the host). |
| [AdventureChapter](AdventureChapter.md) | One chapter of an Adventure: a map (a Puzzle level: Map Kit pieces and a PuzzleExit), and what the card says as it starts. |

## Puzzles

Pieces that switch on and off and wire up (every one has PuzzleNode's settings).

| Piece | What it is |
|---|---|
| [PuzzleNode](PuzzleNode.md) | Base of the puzzle pieces (PressurePlate, PuzzleDoor, PuzzleLogic, Checkpoint, PuzzleExit). |
| [PuzzleButton](PuzzleButton.md) | A button on the floor or a wall (rotate it). |
| [PressurePlate](PressurePlate.md) | A plate in the floor, on while enough weight stands on it: crates, anvils, barrels, a friend (a player counts as 70). |
| [PuzzleDoor](PuzzleDoor.md) | A heavy door (or gate, or bridge, or platform) that slides by Open Offset while its Inputs are on, and back when they go off. |
| [PuzzleLogic](PuzzleLogic.md) | Combines other pieces' states. |
| [PuzzleTarget](PuzzleTarget.md) | A bullseye that turns on when something thrown hits it hard enough. |
| [BreakSensor](BreakSensor.md) | Turns on once a BreakableSlab is broken enough: wreck the wall, the pillar, the statue and the door opens (destruction puzzles). |
| [Receptacle](Receptacle.md) | Somewhere to bring things: a fuse box that wants its fuses, a rescue mat for Lost Yeets. |
| [PuzzleExit](PuzzleExit.md) | The way out: a glowing archway over a zone of Size. |
| [Checkpoint](Checkpoint.md) | A flag on a ring. |
| [PuzzleReset](PuzzleReset.md) | The big red button: walk up and press Use (E) on it, and every map prop whose home is inside Area goes back home, and the ones that were destroyed come back. |
| [Seesaw](Seesaw.md) | The Yeetapult: a plank on a pivot, along its local X. |
| [Turntable](Turntable.md) | A round platform turning around its Y axis: always, or while its Inputs are on (a button that turns the fan around). |
| [PuzzleFan](PuzzleFan.md) | A big industrial fan, placed here, blowing along this node's forward direction (-Z). |
| [RopeAnchor](RopeAnchor.md) | A rope from this point (a ceiling, a beam) holding a prop, which it spawns hanging Length below. |
| [Pulley](Pulley.md) | Two wheels (Width apart along local X) and one rope over them, a lift platform hanging on each end: Drop A (the -X side) and Drop B below the wheels. |
| [Magnet](Magnet.md) | An electromagnet facing its local -Y (hang it from a ceiling; rotate it to face a wall). |
| [Beacon](Beacon.md) | A brazier: on while it burns. |
| [FuseLine](FuseLine.md) | A fuse cord along the floor, from this node to End (the editor shows it). |
| [Wire](Wire.md) | A power cable through Points (this node's space, starting here), live while its inputs are on: it glows and passes the power on (other pieces can take it as an input, like a relay). |
| [Contacts](Contacts.md) | Two copper pads Gap apart (along local X): on while they're powered (their inputs are on, or always with no inputs) and something conductive bridges them. |
