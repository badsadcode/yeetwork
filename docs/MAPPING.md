# Yeetwork Map Kit

You build Yeetwork arenas in the **Godot editor** as ordinary scenes, using a few
drop-in nodes for gameplay (spawns, flags, breakable walls, jump pads...). Any scene in
`res://maps/` shows up in the game's map list automatically.

The example map `maps/courtyard.tscn` uses every node type; `maps/lagoon.tscn` shows water
(a swimmable `water` HazardVolume and an ocean). Open it, look around,
press **F6**, and you are playing it with bots.

The built-in arenas **Yeetwork Prime** (`maps/prime.tscn`) and **Facing Yeets**
(`maps/facing.tscn`) are Map Kit scenes too: open them and tweak anything. They keep their
built-in names in the map list. (They were generated from the old code builders; see
*Converting the code-built maps* at the end. Regenerating overwrites your edits.)
**High Seas** stays in code: the whole map rides a moving ship, which the Map Kit can't
express yet.

---

## 1. Quick start

1. Open the project in **Godot 4.7** (standard build).
2. **Scene → New Scene**, choose **3D Scene** as root, and save it as
   `res://maps/my_arena.tscn`.
3. Add a **MapSettings** node: *Add Child Node* (Ctrl+A), search "MapSettings". Set a
   *Map Name* and a *Sky* preset.
4. Build the floor and walls with **ArenaBlock** nodes (search "ArenaBlock"). Set their
   *Size* and *Color*.
5. Add at least 4 **SpawnPoint**s. For team modes, add Red and Blue spawns and two
   **FlagStand**s.
6. Press **F6** (Run Current Scene). The game starts on your map with bots
   (*MapSettings → Playtest Mode / Playtest Bots*).
7. Check the map for problems:
   ```bash
   godot --headless --path . -- --map my_arena --validate
   ```

Your map now appears in the menu's **Map** list. To host it directly:
```bash
godot --path . -- --host --map my_arena --mode ctf --bots 6
```

> **Multiplayer:** every player needs the same map file in `res://maps/`. Maps are
> matched by path, so ship them with the game build.

---

## 2. Scale and movement reference

Design around these numbers:

| Thing | Value |
|---|---|
| Player height / width | 1.8 m / 0.8 m (crouched / sliding: 1.05 m) |
| Eye height | 1.6 m |
| Run speed | 9.5 m/s (bunny hopping and slides go well beyond: 12-20 m/s) |
| Gravity | 24 m/s² |
| Jump height | ~1.5 m (a jump from a ramp keeps upward speed) |
| Jump distance (running) | ~6-7 m, more with speed |
| Walkable slope | up to 46° |
| Wall-run | needs ≥ 6.5 m/s along a vertical wall, lasts ~1.6 s |
| Wall jumps | 3 per airtime |
| Gravity-gun reach | grab 4.5 m, pull 34 m, punt 8 m |
| Fall damage | starts around 10 m drops (impact speed 21 m/s) |

**Rules of thumb**
- Corridors ≥ 3 m wide, doorways ≥ 2.5 m tall: people get thrown through them.
- Leave long straight runs (20 m+) for building speed, and walls alongside them for
  wall-running.
- Make one thing per area breakable, not everything: breakable walls are most fun as
  shortcuts and windows.
- Put explosive barrels near breakables for chain reactions.

---

## 3. Visual language (keep maps readable)

| Meaning | Look |
|---|---|
| Solid floor | slate blue `#6B789E` |
| Solid wall | lavender `#C7B3DB` |
| Steel (platforms, ramps) | `#809ECC` |
| **Breakable** | cream `#F2DBA8` (plaster), terracotta (brick), warm wood, glass (refracting, cracks show) |
| Movement aids (pads, lifts) | green glow (automatic) |
| Hazard | acid green, lava orange (automatic) |
| Water | teal (automatic) |
| Red team / Blue team | `#FF4554` / `#408CFF` |
| Landmarks | something glowing (`ArenaBlock → Emission`), unique shapes, lights |

Lighting is automatic (*MapSettings → Sky*): **sunset**, **day**, **tropical**,
**desert**, **snow**, **volcano**, **night** or **space**. Each also places low-poly
scenery on the horizon and cartoon clouds overhead. You can still add your own `OmniLight3D` and `SpotLight3D` nodes for
accents. If your scene has its own `WorldEnvironment` or `DirectionalLight3D`, the
preset is skipped and yours is used.

---

## 4. Node reference

All kit nodes preview themselves in the editor. In game they become the real thing.

### MapSettings (one per map)
| Property | |
|---|---|
| Map Name, Author, Description | shown in the menu and HUD |
| Sky | the environment: `sunset`, `day`, `tropical`, `desert`, `snow`, `volcano`, `storm`, `night`, `space` (sky, light, haze, horizon scenery, clouds). The host can override it per match |
| Sun Rotation Degrees, Sun Energy Scale, Ambient Scale | tweak the preset |
| Ocean Preset | sea state with the *Sculpted* water style: `calm`, `lake`, `ocean`, `stormy` (a confused storm sea: wave trains cross from wide angles and the heading drifts across the map) |
| Weather | `none`, `rain` or `storm` (rain plus wind wisps and lightning; the `storm` sky brings it by itself). Rain falls around each player's camera with splashes where it lands and its own sound |
| Rain Intensity, Rain Wind | how hard it rains (0.1 drizzle .. 1 downpour) and the wind slanting it (m/s) |
| Ocean, Ocean Level | surround the map with an animated sea whose surface sits at *Ocean Level*. Players who fall in sink and drown; wooden and rubber props float. Put your floors above it, and an island's sides look best reaching a few metres below it |
| Kill Height | anything below dies or respawns. Keep it ≥ 3 m below your lowest floor |
| Avoid Areas | XZ rectangles bots walk around (pits). `Rect2(x, z, width, depth)` |
| Puzzle | a level for the Puzzle (co-op) mode: `--validate` skips the team and flag checks and wants a PuzzleExit |
| Gold / Silver / Bronze Time | Puzzle mode medals: finish within these many seconds (0: no such medal) |
| Playtest Mode / Playtest Bots | used by F6 |

### ArenaBlock (StaticBody3D)
A solid box with the arena surface shader (soft panels, warm/cool gradient).
- **Size**: use this, **do not scale** the node.
- Color, Roughness, Metallic, Emission (glow).
- **Ramps:** rotate a block around X or Z. Players can walk up to 46°, and steeper
  slopes are slides.
- **Surface**: `arena` (the usual panels) or `ice`: frosty blue ice that can't be broken,
  and slippery: Yeets skate (little grip, long slides), props glide. Blocks thinner than
  2.5 m are see-through, tinted by how much ice you look through (thin is nearly clear);
  thicker ice is solid (deep blue, frost inside). For ice that breaks, use a BreakableSlab
  of `ice` (see-through thin ice).
  - **Ice Clarity Map** (optional): a greyscale texture, white clear, black cloudy, wrapped
    onto every face; **Ice Normal Map** (optional): the surface's bumps; **Ice Map Scale**:
    repeats per metre. Without them the ice makes its own frost and melted bumps.
    `assets/textures/ice_clarity_noise.tres` and `ice_normal_noise.tres` are examples.
- **Bounciness** (0-1): a ricochet surface for bank shots. Bouncy blocks are frictionless,
  so things leave at the angle they came in (Test Chambers' BOUNCE panel uses 0.85).

### BreakableSlab
A destructible wall, floor or bridge. In game it fractures into irregular pieces.
- **Orientation**:
  - *WALL*: upright. Width is local X, height is local Y, thickness is local Z.
    Rotate around Y to turn it.
  - *FLOOR*: flat. Length is local X, width is local Z. Rotate around Y to aim a bridge.
- **Size** (meters), **Thickness**.
- **Material**: `plaster`, `concrete`, `brick` (brick-shaped chunks), `wood` (plank
  splinters along the slab's length), `glass` (shards), `metal` (very tough), `ice`
  (breakable ice: cracks spread, bursts into icy chunks; slippery to walk on while it
  holds; thin ice over water as a FLOOR slab).
- **Anchors** (Bottom/Top/Left/Right): the edges glued to the world. A wall standing on
  the floor uses *Bottom*. A bridge uses *Left* and *Right*. A window uses all four.
  Pieces cut off from every anchored edge crumble and fall.
- **HP Scale**: tougher or weaker than the material default.
- **Budget:** keep the whole map under ~4000 fracture cells (the validator reports the
  total). Plaster cells are ~0.9 m, brick 1.2×0.6 m, glass 0.6 m. The editor warns about
  a single huge slab.
- The editor preview shows the fracture *style*. The exact pattern in game is seeded per
  map so every player sees the same cracks.

### SpawnPoint
- **Team**: `Any` (free-for-all), `Red`, `Blue`. Place it on the floor. Players face the
  map center.
- Want: 6+ `Any`, 4+ per team. Team modes fall back to `Any` spawns if a team has none.

### FlagStand
- **Team**: Red or Blue. Place it on the floor. CTF needs exactly one of each.

### PropSpawn
- **Kind**: crate, crate_big, barrel, boom_barrel, ball, beachball, anvil, plank,
  couch, tire, cone.
- Map props come back at their spot a while after they are destroyed or fall out.

### JumpPadNode
- Move the **Target** (relative to the pad). The launch velocity is computed so the arc
  peaks **Arc Height** above the higher end. The editor draws the predicted arc in green.
- **Velocity Override**: launch with exactly this velocity instead (the converted Prime and
  Facing pads use it). Set it back to zero to aim with Target again.
- Props get launched too.

### LiftPlatform
- **Size**, **Travel** (relative end point), **Period** (seconds per round trip),
  **Phase** (0-1, to offset several lifts). Every player sees it in the same place.

### HazardVolume
- **Kind**:
  - `acid`: a glowing pool that hurts and bounces players and props up.
  - `lava`: like acid (burns and bounces), with glowing molten rock and drifting crust.
  - `water`: a pool to swim in. Players float with their head out, hold jump to swim
    up, crouch to dive, and climb out by swimming into a ledge while holding jump (it
    clears up to ~1.5 m above the water). Wood and rubber props float, metal and stone
    sink. Nobody drowns in a pool.
  - `kill`: instant death, for under-map voids.
  - `wind`: constant push, for updrafts. **Wind** is the acceleration in m/s². Gravity
    is 24, so use more than 24 upward to lift people.
  - `fire`: a burning place (campfire, burning wreck, fire pit). Flames rise from the
    bottom of the box; players who step in catch fire, and wooden props in it burn.
    **Fire Color**: `orange`, or `blue` / `green` magic fire.
- **Size** is the box size. For liquids, the surface sits 80% of the way up the box and
  the liquid fills the box below it. Give the pool a floor and walls: a liquid without a
  floor under it looks bottomless.
- **Damage** applies to acid and lava.
- Liquids can't be rotated; only the box's position counts.
- Water uses the host's water style: *Classic*, or *Sculpted* (sharper waves, ripples and
  wakes; pools are a calm sea state).

### Puzzle pieces (Puzzle co-op mode)
Every piece is on or off; the server decides and everybody sees the same. Common settings:
- **Inputs**: other pieces that switch this one on (drag them into the list).
  **Combine** `all` (AND) or `any` (OR). **Latch**: once on, stay on.
- **Objective**: in the Puzzle mode the top of the screen shows the first piece (in scene
  order) that is still off and has an objective, e.g. a gate's "Hold both plates down".
  On an **open level** (MapSettings **Open Level**) it lists every unfinished one instead,
  to do in any order.
  Put objectives on what the players must achieve (gates, exits), not on plates that turn
  off again.

| Node | |
|---|---|
| **PressurePlate** | on while the weight on it reaches **Required Mass**. Crate 25, barrel 40, couch 60, big crate 70, player 70, anvil 300. Things held with the gun don't count. Amber rim, green when pressed |
| **PuzzleDoor** | slides by **Open Offset** (shown as a green ghost in the editor) at **Speed** while its inputs are on. Can't be broken. Red / green lamps. Also a moving bridge or platform |
| **PuzzleLogic** | invisible. **Mode** `gate`: AND / OR of its inputs; `window`: every input on within the last **Window** seconds ("all three targets within 3 s"); `sequence`: inputs switched on in list order (a wrong one starts over). **Invert**, and **Hold Time** (stays on for a while after: a timed door) |
| **PuzzleButton** | **Press** `touch`: on while anything touches its cap (a player, a prop leaning on it, a rolling ball, a thrown Yeet); `use key`: players walk up and press **Use** (E), with a prompt showing **Label**. Floor or wall (rotate it). **Hold Time** keeps it on after release (use key with 0: each press switches it on or off) |
| **PuzzleTarget** | a bullseye facing its local +Z: on when something thrown hits it at **Min Speed** or more (only **Kind** props, or `any`). **Stay On** seconds (0: for good) |
| **BreakSensor** | invisible: on once **Percent** of the BreakableSlab it points at (**Slab**) is broken. Smash the wall, the pillar, the statue |
| **Seesaw** | the Yeetapult: a plank along its X on a pivot (the node). Tips toward the heavier side, takes a kick from things landing on it; when an end slams down, whatever stands on the other end is launched up and away (**Launch Boost**). Red end: drop the heavy thing; yellow end: stand and fly. **Max Angle**, **Length**, **Width**, **Pivot Height** |
| **Turntable** | a round platform turning at **Speed** (degrees per second): always, or while its inputs are on. Things on it ride along (put a fan on it) |
| **PuzzleFan** | a big fan blowing along the node's forward (-Z; the editor shows its stream): it's a prop players can grab, carry and aim with the gun, block with crates, or turn on a turntable. Blows while its inputs are on (always without inputs). **Strength** (m/s², gravity is 24): light props fly, heavy ones barely move; Yeets get **Player Push**. **Reach**, **Radius**. Comes back home if lost |
| **Receptacle** | somewhere to bring things: a fuse box, a rescue mat. Props of **Kind** (`fuse`, `lost_yeet`, any prop, or `any`) set down inside **Size** lock into a slot for good (no grabbing them back out); on once **Required** are in. A counter shows how many (**Title** over it), and the objective can count too: "Fuses: {count}/{required}". Make the props Key Props so lost ones come back |
| **FloodZone** | flood water over a box (**Size**, standing on the node; not rotated): a 0.5 m grid of water columns that runs toward lower water, fills rooms, piles up behind doors, pours through holes in broken walls and out into pits below the box. The floor is whatever the level's collision says (rescanned all the time). **Start Level**: water already there, up to this height. Yeets swim in it, wood floats, the current carries things, fire goes out. Keep it under ~25 x 25 m (Steam Deck hosts); one floor per column |
| **FloodValve** | a pipe pouring water into its FloodZone while its inputs are on (always, without inputs). **Rate** m³/s (a 10 x 12 m room rises 1 m per 120 m³), **Total** (stops after this much; 0 never) |
| **FloodDrain** | a floor grate taking water out while its inputs are on. **Rate**, **Radius** |
| **FloatSwitch** | a float on a post: on while the water stands **Level** above the node. Invert it with a PuzzleLogic for "drained" |
| **Beacon** | a brazier, on while it burns. Lit by fire (a burning prop or Yeet, a FuseLine's spark, another beacon's flames) or its inputs; water up to the bowl puts it out. Its flames set alight wood and Yeets that touch them. **Start Lit**, **Burn Time** (0 forever), **Palette** |
| **FuseLine** | a cord along the floor to **End**: fire at its start lights a spark that runs along it at **Speed**; at the end it's on for good. Water puts the spark out (light it again where it stopped) |
| **PuzzleReset** | the big red button: walk up and press **Use** (E) on it, and every map prop whose home is inside **Area** (around **Area Center**) goes back home, the destroyed ones come back. Bumping into it does nothing. Gates stay as they are |
| **Checkpoint** | turns green when a player reaches it; in the Puzzle mode the dead respawn at the last one reached |
| **PuzzleExit** | on when every living player is inside **Size** (and its inputs are on, if it has any). Finishes the level in the Puzzle mode |

Puzzles must never get stuck: mark the props a puzzle needs as **Key Prop** on their
PropSpawn (they come back 2.5 s after being destroyed or falling out, instead of 10-25 s),
and give rooms a PuzzleReset. Any solution counts: puzzles check *that* something
happened, never *how*.

PropSpawn kinds for puzzles: `fuse` (a glowing fuse, 5 kg), `lost_yeet` (a Yeet in trouble
to rescue, 50 kg: scared while carried, grinning on a rescue mat), `boulder` (a 120 kg stone
ball that rolls) and `platform` (a 7 m wooden deck, 90 kg, to rest on breakable pillars).

Fire and walls: a BreakableSlab of **wood** catches fire when fire touches it, burns for 6 s
and falls apart (make it tough with **HP Scale** so burning is the way); one of **ice** melts
where fire stays on it for 2 s, and the meltwater runs into the FloodZone there. A
BreakSensor on the slab makes either one a switch.

`maps/moving_day.tscn` and `maps/test_chambers.tscn` use all of them; `maps/warehouse.tscn` is
an open level with receptacles, fuses and a Lost Yeet; `maps/pump_house.tscn` uses the water
and fire pieces.

### Anything else
- **CSG nodes** (`CSGBox3D`, `CSGCylinder3D`, `CSGCombiner3D`...) with *Use Collision*
  on become solid geometry. They're great for blocking out complex shapes.
- **Imported meshes**: add a `StaticBody3D` with a collision shape (or use *Mesh →
  Create Collision Shape*). StaticBody3D's default collision layer is already correct.
- **Lights, decals, particles, decorative meshes**: used as-is.
- **Spinner** (`scripts/mapkit/spinner.gd`): a Node3D that slowly turns its children around
  its Y axis in game (Prime's orb ring, Facing's crystal). Decoration only, no collision.
- Use the arena look on your own meshes by giving them a `ShaderMaterial` with
  `res://scripts/world/world_surface.gdshader`.

---

## 5. Testing checklist

- [ ] `--validate` reports no warnings.
- [ ] Every spawn has floor under it and is not inside geometry (the validator checks).
- [ ] You can reach every platform (ramps, pads, lifts, wall-runs, gravity jumps).
- [ ] Nothing important is reachable *only* through a breakable wall (they can be
      rebuilt only by restarting the match).
- [ ] Kill height catches people who fall off, but not people in pits you intended.
- [ ] Pools: you can climb out everywhere you can fall in (ledges ≤ 1.5 m above the water).
- [ ] Bots: pits are in *Avoid Areas*.
- [ ] CTF: flags are roughly equidistant from the center and not reachable in one jump pad.
- [ ] F6 playtest in Sandbox, CTF and Dodgeball modes.
- [ ] Optional: screenshots with
      `godot --path . -- --host --map my_arena --bots 6 --tour /tmp/shots`.
- [ ] Liquids or an ocean: also try `--graphics 0` (Steam Deck preset).

---

## 6. How it works (for programmers)

When a match starts, `Arena._build_scene_map()` instances your scene and converts the
kit nodes in tree order. Destructible ids depend on that order, so every peer builds
identical slabs. Server and clients load the same file. The server sends only the map
path, and later which cells broke. Built-in maps (`prime`, `facing`) are code-built in
`scripts/world/arena.gd` and `scripts/world/map_facing.gd` and use the same helpers.

Kit scripts live in `scripts/mapkit/`. Adding a new node type means writing a `@tool`
script there and handling it in `Arena._collect()`.

### Converting the code-built maps
`Arena` (Prime) and `MapFacing` still contain the original builders, and every builder tags
what it makes. To regenerate the scenes from them (this **overwrites** `maps/prime.tscn` /
`maps/facing.tscn`):

```bash
godot --headless --path . -- --host --map prime --map-source code --bots 0 --tour x --tour-mode export_maps
```

`--map-source code` also plays the code version, for comparing.
