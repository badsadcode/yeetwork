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
**High Seas** is a Map Kit scene too (`maps/high_seas.tscn`): the ship is a **Vessel** with
High Seas Weather on, its hull blocks and CSG ends, the engine room a **ShipHold** full of
Fixtures, its containers **CargoContainers**, ladders, the crane, the horn, the bridge's glass.
Its variants (Golden Hour, Storm, Hurricane) are the same scene on another sea under another
sky. It was saved from the code builder (see *Converting the code-built maps*).

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

All kit nodes preview themselves in the editor. In game they become the real thing. Every
piece also has its own page with all its settings, defaults and markers:
[pieces/](pieces/README.md) (made from the pieces' scripts by `tools/make_guide.gd`; the
same descriptions are the Inspector's tooltips). A walkthrough that rebuilds Courtyard from
these pieces: [REBUILD_A_MAP.md](REBUILD_A_MAP.md); one that makes a new map from an idea
(Lighthouse Point): [MAKE_A_NEW_MAP.md](MAKE_A_NEW_MAP.md).

### MapSettings (one per map)
| Property | |
|---|---|
| Map Name, Author, Description | shown in the menu and HUD |
| Sky | the environment: `sunset`, `day`, `tropical`, `desert`, `snow`, `volcano`, `storm`, `night`, `haunted`, `space` (sky, light, haze, horizon scenery, clouds). The host can override it per match. **haunted** is truly dark and misty (a faint moon, low haze the lamps glow in, bats): light it with MapLights; it stays haunted in spooky season |
| Flashlights | `auto` (every Yeet carries one under a dark sky: haunted), `on` or `off`. Yours casts shadows; you see everyone else's beam too |
| Sun Rotation Degrees, Sun Energy Scale, Ambient Scale | tweak the preset |
| Ocean Preset | sea state with the *Sculpted* water style: `calm`, `lake`, `ocean`, `stormy` (a confused storm sea: wave trains cross from wide angles and the heading drifts across the map) |
| Weather | `none`, `rain` or `storm` (rain plus wind wisps and lightning; the `storm` sky brings it by itself). Lightning strikes in view: branching bolts from the clouds to the ground that light up the land around them, or sheet lightning in the clouds; the thunder comes as late as sound would (distance / 343 m/s), a crack first when it's close. In a storm, every 25-55 s lightning strikes the map itself, mostly something tall (props up high, lamp posts, torches): what's flammable there catches fire, Yeets within 4 m are zapped and thrown, lights within 5 m break. Rain falls around each player's camera with splashes where it lands and its own sound |
| Rain Intensity, Rain Wind | how hard it rains (0.1 drizzle .. 1 downpour) and the wind slanting it (m/s) |
| Ocean, Ocean Level | surround the map with an animated sea whose surface sits at *Ocean Level*. Players who fall in sink and drown; wooden and rubber props float. Put your floors above it, and an island's sides look best reaching a few metres below it |
| Kill Height | anything below dies or respawns. Keep it ≥ 3 m below your lowest floor |
| Avoid Areas | XZ rectangles bots walk around (pits). `Rect2(x, z, width, depth)` |
| Puzzle | a level for the Puzzle (co-op) mode: `--validate` skips the team and flag checks and wants a PuzzleExit |
| Gold / Silver / Bronze Time | Puzzle mode medals: finish within these many seconds (0: no such medal) |
| Playtest Mode / Playtest Bots | used by F6 |

### ArenaBlock (StaticBody3D)
A solid box with the arena surface shader (soft panels, warm/cool gradient).
- **Size**: type it in the Inspector, or drag the **handles** on the block's faces in the 3D
  view (the opposite face stays put; hold Ctrl to snap to whole metres). The **Scale tool**
  (R) works too: when you let go, the scale becomes Size and the scale goes back to 1 (a
  scaled block would collide wrong).
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
- **Solid**: off, nothing bumps into it, it's only seen (a painted stripe, window bands,
  trim). A hidden solid block (Visible off in the Scene dock) is felt, not seen (a machine's
  bulk on a ship).
- **Bounciness** (0-1): a ricochet surface for bank shots. Bouncy blocks are frictionless,
  so things leave at the angle they came in (Test Chambers' BOUNCE panel uses 0.85).
- **Custom Material** (optional): your own material instead of the colour, e.g. a PBR
  `StandardMaterial3D` with albedo / normal / roughness / metallic / AO / height textures.
  It's used exactly as you set it up, and edits show straight away. The block's texture
  coordinates are laid out in metres in the map, so the texture tiles evenly at any size and
  lines up across neighbouring blocks: **Texture Size** = metres per repeat; the material's own
  UV1 Scale / Offset apply on top. Works for your own shaders too (UV and UV2 are the same).
  AO only darkens the ambient light, so it shows most in shade.

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
  couch, tire, cone (and the rest of the props below).
- **Type**: your own prop (a PropType, see *Make your own versions*) in place of Kind.
- Map props come back at their spot a while after they are destroyed or fall out.

### PickupSpawn
A pickup floating a metre over a glowing pad: walk through it to take it. Put the node on
the floor. It comes back after a while (**Respawn**, seconds; 0 = the usual for its kind).
- **Kind**:
  - `health`: first aid, +50 HP (back after 20 s). `health_big`: +100 HP (40 s). Never above
    100 HP; at full health you walk past it.
  - `speed`: run 40% faster for 12 s. `super` (Super Yeet): throws, punts and launches 1.8x
    stronger for 15 s. `feather`: low gravity and high jumps for 12 s. `iron` (Iron Yeet):
    can't be grabbed, barely knocked about, half damage, for 12 s. (Back after 35-40 s.)
  - `random`: a different power-up each time it comes back.
- The host can play with first aid only or no pickups (*Pickups* in the menu); the Puzzle
  mode has none. Bots go for first aid when hurt and grab power-ups close by.
- Good spots: first aid out at the sides, power-ups where the fights are (and somewhere a
  little risky to reach).

### JumpPadNode
- Move the **Target** (relative to the pad). The launch velocity is computed so the arc
  peaks **Arc Height** above the higher end. The editor draws the predicted arc in green.
- **Velocity Override**: launch with exactly this velocity instead (the converted Prime and
  Facing pads use it). Set it back to zero to aim with Target again.
- Props get launched too.
- **Model** (optional): your own look for it (a scene or an imported model).

### LiftPlatform
- **Size**, **Travel** (relative end point), **Period** (seconds per round trip),
  **Phase** (0-1, to offset several lifts). Every player sees it in the same place.
- **Model** (optional): your own look (the collision stays a box of Size). Doors, buttons
  and pressure plates have the same **Model** slot (a button model's `Cap` child moves when
  pressed, a plate model's `Plate` child sinks).

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
| **FloodValve** | a pipe pouring water into its FloodZone while its inputs are on (always, without inputs). **Rate** m³/s (a 10 x 12 m room rises 1 m per 120 m³), **Total** (stops after this much; 0 never). Its model's `Spout` marker: where the water comes out and which way (it can sit on a pool's wall) |
| **FloodDrain** | a floor grate taking water out while its inputs are on. **Rate**, **Radius**. Its model's `Intake` marker: where the water goes in |
| **FloatSwitch** | a float on a post: on while the water stands **Level** above the node. Invert it with a PuzzleLogic for "drained" |
| **Beacon** | a brazier, on while it burns. Lit by fire (a burning prop or Yeet, a FuseLine's spark, another beacon's flames) or its inputs; water up to the bowl puts it out. Its flames set alight wood and Yeets that touch them. **Start Lit**, **Burn Time** (0 forever), **Palette** |
| **FuseLine** | a cord along the floor to **End**: fire at its start lights a spark that runs along it at **Speed**; at the end it's on for good. Water puts the spark out (light it again where it stopped) |
| **GoalZone** | a Yeetball goal: posts, crossbar and a solid net, its mouth facing local +Z (turn it toward the pitch). **Team**: who defends it (the other team scores there). A goal counts when the whole ball is past the line, inside **Size** (width, height, depth behind the line). A Yeetball map needs one Red and one Blue (no FlagStands needed) |
| **BallSpot** | where the Yeetball (or the basketball) waits for each kickoff (the middle of the map without one) |
| **VolleyNet** | a YeetVolley court: the net (posts and a solid net, **Net Height**) across the middle and the court lines on the floor. Put it on the floor in the middle of the court: the net runs along local X, Red plays on the local -Z side, Blue on +Z. **Court**: width (X) and length (Z, both halves together); landing outside the lines is out. A YeetVolley map needs one (and a BallSpot at the net) |
| **Hoop** | a YeetHoops basket: pole, a solid backboard, the rim (3.6 m up) and a net, the rim facing local +Z (turn it toward the court; put the node on the floor). **Team**: who defends it. A basket is the ball dropping down through the rim; from beyond **Three Range** (the glowing arc on the floor) it's 3. A YeetHoops map needs one Red and one Blue (and a BallSpot in the middle) |
| **GrapplePoint** | a yellow ring for the grapple hook. On maps whose MapSettings **Grapple** is `grapple points` (puzzle levels) the hook only takes hold on these (and on props and friends); aiming near one is enough |
| **RopeAnchor** | a rope from the node holding a prop it spawns (**Kind**) **Length** below. It swings, can be pushed and grabbed, but stays on the rope. Fire burns through it in a second (hold something burning to it); its inputs let go of it. On once cut (for good): drop the anvil on the plate |
| **Pulley** | two wheels **Width** apart, one rope, a lift platform on each end (**Drop A**, **Drop B** below the wheels). A counterweight: the heavier side (platform, what lies on it, 70 kg per Yeet) sinks, the other rises, until one meets the floor or its wheel |
| **Magnet** | an electromagnet facing its local -Y: while its inputs are on (always without inputs) it pulls metal props (barrels, anvils, batteries, fuses, fans) within **Reach** and holds them at its face; switched off, they drop. **Strength** |
| **Wire** | a power cable through **Points**, live (glowing) while its inputs are on, and an input for others like a relay: show where the power goes. **Zap Water**: a live end in water shocks the Yeets swimming near it |
| **Contacts** | two copper pads **Gap** apart: on while powered (inputs on, or always without inputs) and bridged by a metal prop, water over both, or a Yeet standing between them (who gets zapped) |
| **PuzzleReset** | the big red button: walk up and press **Use** (E) on it, and every map prop whose home is inside **Area** (around **Area Center**) goes back home, the destroyed ones come back. Bumping into it does nothing. Gates stay as they are |
| **Checkpoint** | turns green when a player reaches it; in the Puzzle mode the dead respawn at the last one reached |
| **PuzzleExit** | on when every living player is inside **Size** (and its inputs are on, if it has any). Finishes the level in the Puzzle mode |

Puzzles must never get stuck: mark the props a puzzle needs as **Key Prop** on their
PropSpawn (they come back 2.5 s after being destroyed or falling out, instead of 10-25 s),
and give rooms a PuzzleReset. Any solution counts: puzzles check *that* something
happened, never *how*.

PropSpawn kinds for puzzles: `fuse` (a glowing fuse, 5 kg), `lost_yeet` (a Yeet in trouble
to rescue, 50 kg: scared while carried, grinning on a rescue mat), `boulder` (a 120 kg stone
ball that rolls) and `platform` (a 7 m wooden deck, 90 kg, to rest on breakable pillars) and `battery` (15 kg,
metal: power for a Receptacle of kind `battery`, the classic power socket).

**Grapple** (MapSettings): `anywhere` (the default: any surface), `grapple points` (only on
GrapplePoints, plus props and friends: use it for puzzle levels) or `off`.

Fire and walls: a BreakableSlab of **wood** catches fire when fire touches it, burns for 6 s
and falls apart (make it tough with **HP Scale** so burning is the way); one of **ice** melts
where fire stays on it for 2 s, and the meltwater runs into the FloodZone there. A
BreakSensor on the slab makes either one a switch.

`maps/moving_day.tscn` and `maps/test_chambers.tscn` use all of them; `maps/warehouse.tscn` is
an open level with receptacles, fuses and a Lost Yeet; `maps/pump_house.tscn` uses the water
and fire pieces; `maps/scrapyard.tscn` the grapple points, ropes, pulleys, magnets and
electricity.

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

### MapLight (lights for dark maps, and any map)
A light with its own little model: **Kind** `bulb`, `lamp_post` (put it on the ground),
`wall_lamp` (on a wall, facing out along local +Z), `candle`, `torch`, `spotlight` (shines
along local -Z) or `neon` (a 1.2 m tube along X).
- **Color**, **Energy** (1 = the usual for its kind), **Reach** (metres; 0 = the usual).
- **Flicker**: `none`, `candle` (a gentle wobble), `faulty` (on, with sudden drop-outs),
  `strobe`, `pulse`.
- **Shadows**: lovely and dearer; only on High graphics in the game. Use them for a few
  key lights.
- **Inputs** (it's a puzzle piece): on while its inputs are on ("restore the power and the
  lights come on": wire it to a PuzzleButton); without inputs it's always on.
- **Model** (or the theme's `light_<kind>` slot) replaces the look; a child named `Light`
  in the model is where the light shines from.
- **Breakable** (on by default): a prop flying into it, a blast, a gravity-gun push or
  lightning smashes it (dark, a burst of glass; a candle or torch is blown out). **Repair
  Time**: seconds until it flickers back on (0: it stays broken until a PuzzleReset over it).
  Untick Breakable for lights a puzzle needs.
- `maps/haunted_yard.tscn` is an example: lamp posts (one failing), candles on the graves,
  torches at the crypt and a power switch for the crypt's lights.

### Vessel (a ship, a boat, a raft riding the swell)
Everything under a **Vessel** node rides the sea's swell together, heaving, pitching and
rolling like High Seas' ship (the same for every player, nothing sent). Build the ship from
ordinary pieces as its children: blocks for the hull and deck, breakable walls and models,
ladders, a crane, a horn, machines, pickups, props, spawn points, flag stands. Players and
props on it ride along; loose cargo slides when it tilts. Needs MapSettings > **Ocean**
(with **Ocean Swimmable**, whoever falls overboard swims to its ladder).
- Put the node on the waterline, bow along its **+X**. **Length** and **Beam** (0: its blocks'
  size): the hull the swell lifts. **Roll** (how hard it answers the swell), **Max Roll
  Degrees**, **Max Pitch Degrees**, **Heave** (1: as much as the water), **Lag** (seconds
  behind the water: more for a big heavy ship).
- Dry land beside it works too (an island, a dock, a harbour): pieces not under the Vessel stay
  put. Spawn points, props and flag stands can be on either: on the ship they move with it
  (a flag comes home to where the ship is now), ashore they stay where they are. A jump pad
  on a pier can throw players aboard. One Vessel a map.
- When the ship has to jump rather than glide (its first moment, or catching up after a
  stall), everything aboard jumps with it.
- Its blocks' collision becomes the ship's own, so you stand on a moving deck, not slide off
  it; pieces that move by themselves (doors, plates, seesaws) keep their own.
- **High Seas Weather**: High Seas' own green water over the rail, rogue waves and hull spray
  in a stormy sea (laid out for its ship: about 140 x 32 m, the deck 8 m up); off, a Vessel in a
  stormy sea just rolls harder.
- Shaped solids under it (a **CSG** shape with Use Collision: a hull's rounded stern, its bow)
  are the ship's collision too.
- **ShipHold** (under the Vessel): a box below deck (Size, standing on the node) the sea stays
  out of however far she heels; bots knocked down a hatch climb out up the Ladders whose foot
  is in it. High Seas' engine room is one.
- **CargoContainer**: a 40 ft container (12.2 x 2.6 x 2.44 m, bottom on the node, length along
  X) in its **Color**: closed (solid, stack them), **Lashed** (on a ship: its lashings wear down
  under blasts, pushes, lightning and a storm's rolling until it breaks loose as a heavy prop
  that slides about), or **Open** (hollow, doors swung wide at one end, **Doors Aft**: the -X
  end, a lamp inside; **Pickup**: a random power-up waits in it).
- `custom/make_your_own/boat.tscn` (**Make Your Own Boat**: a boat beside an island with a
  pier, Red ashore and Blue aboard) is one, built by `tools/make_boat.py`.

### BreakableModel (your own model, breaking part by part)
A door, a window, a fence you modelled: each separate part (each mesh) breaks on its own.
- **Model**: your model. A part's name says what it's made of (glass, wood, metal, stone,
  concrete, brick, plaster, ice anywhere in it: `Glass_Pane`, `Wood_Plank3`); `Fixed` in its
  name: it never breaks and holds up what touches it; `Collision`: hidden.
- **Material**: what a part named none of them is made of. **Hp Scale**: toughness (times
  the material's). **Anchor To Ground**: its lowest parts stand on the ground and hold the rest
  (off: only the Fixed parts do). **Color**: dust and fallbacks.
- A broken part shatters into pieces cut from its own outline (the hull of the part in its own
  plane: its two longest sides; the longest is the grain, so wood splinters along it), from the
  hit outward, in the part's own material; a part under 0.3 m comes off whole. A part left
  holding onto nothing falls off whole (a prop). Hits are measured to each part itself, so a
  hit on one plank reaches only the planks it touches.
- Like a BreakableSlab: synced for everyone and late joiners, battered by monsters (a
  MegaYeet gate; the shop repairs it), wooden parts burn. The map check notes a model that
  can't break (every part Fixed) or that nothing holds up.
- **Tear Off**: the gravity gun rips it off (a door off its hinges): its loose parts (not the
  Fixed ones) come away together as one prop, in the gun's grip, free of its frame until it's
  out. Thrown hard (it hits something at about 25 m/s; sooner with glass in it, later with a
  higher Hp Scale), it comes apart into its parts, each a prop of its own; glass shatters. The
  shop's repair puts it back. On a MegaYeet gate it lets players pull the gate off.
- Parts work best mostly flat or long (panes, planks, boards, posts, bars); a chunky part
  breaks into pieces cut through its box.

### AnimatedModel (your model, moving the way you animated it)
A windmill, a swinging sign, a bobbing buoy, a piston, a sliding platform, a drawbridge: your
model playing its own Blender animation (object animation is enough; armatures work too).
- **Model**; **Animation**: which action (empty: the first). **Play**: `loop`, `ping pong`
  (there and back) or `once` (to its end, then it stays). **Speed**, **Offset** (seconds in,
  so several don't move in step). **Preview**: it moves in the editor too.
- It runs off the match clock: every player sees it at the same point, nothing is sent.
- **Solid** (on): its parts named `Collision...` are what things bump into and stand on,
  moving with it (made convex, hidden in the game); a moving platform carries riders. Put a
  Collision part inside the part that moves.
- **Inputs** (a puzzle piece): it plays while they're on; with `once`, forward while on and
  back while off (a drawbridge on a button). It's on (for other pieces) while it plays.
- The map check notes a model with no animation, or none called **Animation**.
- Starter models: `custom/make_your_own/models/` windmill, sign, platform, drawbridge.

### Ladder, Crane, Horn (High Seas' pieces, for any map)
- **Ladder**: climb a wall (a building, a ship's side, out of a pool or the sea). Put the node
  at the foot against the wall, its **+Z** (blue arrow) pointing away from the wall, toward the
  climber. **Height**; **Over The Top** (how hard the top throws you on over the edge, m/s:
  more for a rail or a wide ledge). Let it reach a little above what it climbs (a rail's top:
  about 40 cm more), or climbers stick at the top. **Top Throw**: instead, exactly how the top
  throws you (m/s in the ladder's frame: x along the wall, y up, z out), for a ladder that lets
  you off sideways. Face it and hold forward (or Jump) to climb, back to go
  down. **Model**: your own ladder (origin at the foot, up +Y, wall behind at -Z). A ladder
  whose foot is in a swimmable sea is where bots in the water swim to.
- **Crane**: slews to and fro on its own, a solid load swinging from its jib (ride it, or be
  swept off a roof). **Height**, **Jib**, **Cable**, **Heading** (degrees round from +X:
  the middle of its sweep), **Sweep** (either side), **Period** (s there and back), **Load
  Size** and **Load Color**, **Pedestal Size** (its collision; height 0: the crane's).
  **Model**: a part named `Turret` slews (its jib along the Turret's +X), an empty `Hook` on it
  is where the cable hangs. **Load Model**: what hangs (origin in its middle). Every player
  sees the same crane (it runs off the match clock).
- **Horn**: Use sounds a deep blast everyone hears (a ship's horn, a factory whistle). Model:
  a part named `Lever` is pulled.
- **MapSettings > Ocean Swimmable**: the ocean can be swum in (and climbed out of by a
  Ladder) instead of drowning whoever falls in.

### Fixture (set dressing that does something)
Machinery, appliances, anything that fills out a place and hums, turns, steams or sparks.
Everything is optional: a fixture can just be a model.
- **Kind**: a built-in placeholder look and its usual behaviour: `generator` (hums, a puff of
  exhaust, a green panel light), `engine` (thumps, its flywheel turns, it shudders and shakes
  the camera nearby), `fan` (whirs, its blades turn), `pump` (hums, drips), `pipes` (a steam
  leak, a valve wheel), `radio` (static and a voice somewhere in it), `box` (a plain block).
- **Model**: your own (an imported .glb...), or the theme's `fixture_<kind>` slot. Parts
  named **`Spin`** (turns), **`Emitter`** (where the steam, smoke, sparks or drips come from)
  and **`Light`** (where its glow is) are used if the model has them.
- **Solid**: players bump into a box round its look; untick for things to walk past.
- **Sound**: `auto` (the kind's), `none`, or one of the game's loops: `hum`, `buzz`, `engine`,
  `fan`, `steam`, `radio` (replace them with recordings: [SOUNDS.md](SOUNDS.md)). **Custom
  Sound** plays your own loop instead. **Volume**, **Reach** (metres), **Pitch**. **One Shot
  Sounds** (game sounds: `creak`, `metal`, `zap`, `sizzle`...) and **One Shot Recordings**
  (yours) play now and then, every **One Shot Every** seconds (a random time in that range).
- **Motion**: **Spin Speed** (turns a second of the `Spin` part; -1: the kind's) about **Spin
  Axis**; **Vibrate** (metres of shaking); **Sway** (degrees) and **Sway Speed** for a hanging
  sign or a buoy.
- **Effect**: `auto`, `none`, `steam`, `smoke`, `sparks`, `drips`, with **Effect Rate**.
- **Light**: **Light Color**, **Light Energy** (-1: the kind's; 0: none), **Light Pulse**
  (pulses a second; 0: steady).
- **Inputs** (it's a puzzle piece): on while its inputs are on ("restore the power and the
  machines start up"); without inputs it's always on. Switched on, it winds up (the sound
  rises, the parts speed up); off, it winds down.
- **Breakable** (off by default): a prop flung at it, a blast, a gravity-gun push or
  lightning breaks it: sparks, it falls silent and smokes. **Repair Time**: seconds until it
  starts again (0: until a PuzzleReset over it).
- **Hazard**: `hot` (burns and sets alight) or `electric` (a zap and a jolt) for whoever comes
  within **Hazard Radius** of its `Emitter` (or its middle) while it runs. **Shake**: camera
  shake for anyone close (-1: the kind's).
- `maps/pump_house.tscn` has six (a pump that starts with the valves' button, steam pipes, a
  fan, a radio, a breakable generator, an engine); High Seas' engine room is built from them.

### MegaYeet pieces (co-op survival)
A MegaYeet map is a fortress: put a **FortressHeart** at its centre, **DefenseZones** over its
rings, **MonsterSpawns** outside it, and the players' **SpawnPoints** (Any) inside, near the
Heart. Gates are **BreakableSlabs** (wood, metal...) across gaps in the walls: monsters
batter them down when there's no open way round. Monsters walk on the ground and climb
nothing taller than a step (about half a metre): walls stop them, a low wall players hop
over still does; anything a monster fits under (a gate under a lintel) is a way through.
- **FortressHeart**: what's defended. **Radius**: how close a monster gets before it bites.
  **Color**; **Model** (or the theme's `heart` slot) replaces the crystal: a throne, a
  reactor, a giant cake. Its **MegaYeet Rules** tune the game on your map: **Health** (the
  Fortress meter, 1000), **Bite** (a monster reaching it, 40), **Kill Refill** and **Style
  Refill** (what kills put back, 3 and 2 more for style), **Wave Bonus** (holding a wave,
  60), **First Break** and **Break Time** (seconds, 12 and 25), **Wave Size** (times the
  usual: 24 in wave 1, ten more each wave) and **Max Monsters** (at once, 220; fewer for the
  Steam Deck), **Max Traps** (how many traps players can put down anywhere, 12; the map's
  trap spots don't count), **Boss Every** (a boss wave every this many, 5; 0: none), **Bosses**
  (which come, in turn: `golem`, the Siege Golem, and `ram`, the Wrecking Ram, which charges
  in straight lines and is dazed by whatever solid it hits: so leave it walls to hit and room
  to dodge; the same one twice comes twice as often; empty: no bosses), **Boss Health**
  (3000; more with more players and each time it returns) and **Boss Reward** (300).
- **TrapSpot**: a place for a trap (a box, **Size**, its bottom on the node), built between
  waves by a player with Use or from the shop window (which builds the free spot of that kind
  nearest the buyer), paid out of the Fortress meter or the buyer's Y$, as the match's
  Economy says (**Cost**; 0: the usual: spikes 80, fire 120, mine 60).
  **Kind**: `spikes` (monsters crossing are hurt and slowed), `fire` (a burning grate: they
  catch fire), `mine` (blows up under the first monsters, then it's gone: build it again).
  Built traps last until the fortress falls. Put them where monsters will come: behind a
  gate, in a passage. Not built, a faint outline shows where it goes. Players can also put
  traps down anywhere monsters walk (the shop: a preview where they aim), up to the Heart's
  **Max Traps** (12; on top of the map's spots): a map's spots are suggestions, a trap of the
  spot's kind aimed into it goes on the spot. A built trap, spot or not, can be picked up
  between waves (Use) to move it, or sold for half. **Your Own Trap**:
  its name, model and numbers (damage, slowing, burning, blast): see *Make your own
  versions*.
- Between waves players also **repair gates** (Use on a broken one; the more is gone, the
  more it costs) and buy **team upgrades** at the Heart (Use on it opens the shop's Team
  tab: any of the seven, in any order). Spending never takes the meter below a tenth of it.
- **Iron ball** (PropSpawn kind `iron_ball`): a team lift, too heavy for one gun; two
  lift it together and throw it (any mode, not just MegaYeet).
- **Gates**: any BreakableSlab. Its **material** and **Hp Scale** (toughness: 0.5 half as
  tough, 10 ten times) set how long it holds against monsters battering it; brutes hit
  hardest, bombers blow holes in it.
- **DefenseZone**: a box (**Size**, its bottom on the node). **Level** 1 the outer walls, 2 the
  courtyard, 3 the keep: each monster inside drains the Fortress meter 1, 3 or 6 points a
  second (**Drain** sets your own); where zones overlap the deepest counts, so nest them.
  **Zone Name** for the HUD's alert ("Monsters in the stables!"); **Show Edge** draws a faint
  line round it on the ground.
- **MonsterSpawn**: a rift monsters come out of (**Radius**). Several round the outside;
  **From Wave** keeps one shut until then (a surprise later on).
- **Monsters of your own**: a **MonsterType** file (Create New > Resource > MonsterType) on
  the Heart's **Monster Types** list joins the waves: **Behaves Like** a built-in kind (how it
  moves and what it can do: a runner sprints, a brute smashes gates, a ghost drifts through
  walls, a climber scales them, a bomber blows up), your **Model**, and its own **Hit
  Points**, **Speed**, **Bite**, **Bash**, **Size**, **Burns**, **Grabbable** (0, or "as it":
  the built-in kind's). **From Wave** and **Share** (0.3: about a third of every wave from
  then on); **Announce**, what the wave says the first time it comes.
  - The model: facing -Z (Blender +Y, like the Yeets), feet at the origin, about a Yeet's
    height (1.8 m; **Size** scales it), in parts named `Torso`, `Leg_L`, `Leg_R`, `Arm_L`,
    `Arm_R`, `Head`, **each with its origin at its joint** (the hips, the shoulders, the
    neck): the game swings them like the built-in monsters' (a lurching stride, reaching
    arms, flailing when thrown, a lolling head). Anything else rides on the part it's in (or
    the torso). `Glow` in a part's or a material's name (or an emissive material) glows.
    Colours and textures (one per material) show as in Blender.
  - They're drawn by the hundred like the built-in ones (no rigging, no slow-down): no
    animations of your own, the swing is the game's.
  - The map check notes a type with no model or with parts it doesn't find.
  - The example: `custom/make_your_own/scarecrow.tres` (a scarecrow with a pumpkin head that
    behaves like a shambler; straw burns), its model `models/scarecrow.glb`, in the Make Your
    Own Workshop.
- Bots find their way round your fortress the way players can: walking, hopping anything
  up to about 1.3 m, dropping off walls, and riding **jump pads** (aimed with Target; not
  ones set by Velocity Override). Give the inner rings a way out (a low wall, a pad up onto
  a wall) or the bots stay inside until a gate falls.
- In the match setup the host can play the map's own rules or set custom ones for the match.
  The setup lists a map for a mode only if it has what the mode needs (two flag stands for
  CTF, two GoalZones for Yeetball, two Hoops, a VolleyNet, MapSettings Puzzle); played in
  another mode, pieces that mode doesn't use stay out of sight (no Heart or rifts in a
  deathmatch on a fortress, no flag stands but in CTF).
- No Heart, zones or rifts on a map: the game makes them (a Heart amid the spawn points,
  rings of zones round it, rifts at the farthest ground monsters can walk from).
- `maps/fortress.tscn` is the example (built by `tools/make_fortress.py`, plain Map Kit
  afterwards). A track named `fortress.ogg` in `assets/music/` plays there.
- `maps/foundry.tscn` (`tools/make_foundry.py`) shows a fortress needn't be rings round a
  middle: the Heart at one end, three ways in that play differently. A map's first
  **MonsterSpawn** is where its bosses come from. To have monsters keep to a bridge, make the
  canal `acid` or `lava` (they don't path into it; thrown in, that's the end of them), and
  build the bridge solid from the bed up: they take the lowest floor they fit on, so under a
  thin deck they'd count the bed as theirs (that's what lets them walk under catwalks). Thin
  walls between the parts of a fortress need **jump pads** over them, floor to floor, with the
  top of the arc over the wall (Target on the far floor, Arc Height above the wall): bots only
  reach monsters behind a closed gate that way (catwalks aren't on their map).

### Themes (a look for a whole map)
A **MapTheme** gives every piece and prop on a map the look of its theme (haunted, foundry,
beach...) in one place. Make one: right-click a folder in the FileSystem > **Create New >
Resource... > MapTheme**, save it (e.g. `custom/my_map/haunted_theme.tres`), then drag your
models (`.glb`, `.gltf`, `.blend`, `.fbx` or a `.tscn`) onto its slots. Pick it in
**MapSettings > Theme**. The same theme file can serve many maps.

- **Which look wins**: a piece's own **Model** slot, then the theme's slot for that kind,
  then the built-in look (an empty slot keeps it).
- **Only the look changes.** Pieces work exactly the same, keep their collision and size;
  props weigh and collide the same (a themed crate is still a 1 m box to the game), so make
  your model about the size given below, its origin where the piece's node is.
- Lights, sounds and the effects that tell players something stay: a valve's stream, a
  drain's swirl, a magnet's field, a contacts' sparks, the beacon's fire, a receptacle's
  count, a hoop's three-point arc, the volleyball court lines, a pickup's glowing ring, the
  pulley's wheels.
- In the editor, the map re-skins as soon as you change the theme or drop a model on one
  of its slots. `custom/example_garden/garden_theme.tres` is an example: a mushroom jump pad,
  hay bales for crates and a tree stump flag stand.

**Moving parts** are found by name in your model (any depth):

| Slot | Name a child... | ...and it |
|---|---|---|
| button | `Cap` | moves down when pressed |
| pressure_plate | `Plate` | sinks when weighed down |
| valve | `Wheel` | turns while water pours |
| float_switch | `Float` | rides up and down on the water |
| seesaw | `Plank` | tips with the plank (the rest stays put) |
| volley_net | `Net` | rises with the net (TOTAL YEET) |
| fan (prop) | `Rotor` | spins |
| door | (the whole model) | slides open like the built-in door |
| monster_shambler ... monster_golem, monster_ram | `Torso`, `Leg_L`, `Leg_R`, `Arm_L`, `Arm_R`, `Head` (each origin at its joint) | swing like the built-in monster's (see *Monsters of your own* above): a theme's mummies for shamblers |
| turntable, lift | (the whole model) | turns / rides along |

**Slots**: *Lights* light_bulb, light_lamp_post, light_wall_lamp, light_candle,
light_torch, light_spotlight, light_neon. *Movement* jump_pad, lift, grapple_point, rope_anchor. *Puzzle pieces* button,
pressure_plate, door, target, receptacle, exit, checkpoint, reset_post, seesaw, turntable,
pulley, magnet. *Water, fire, power* valve, drain, float_switch, beacon, contacts. *Modes*
flag_stand, goal (the frame; the net stays solid), hoop (the arc stays), volley_net.
*MegaYeet* heart, trap_spikes, trap_fire, trap_mine (built; flames and lights stay).
*Pickups* pickup_pad (added around the glowing ring) and one item per kind
(pickup_health, pickup_health_big, pickup_speed, pickup_super, pickup_feather, pickup_iron).
*Props* (sizes in metres; spheres and cylinders give the radius):

| Prop | Size | Prop | Size |
|---|---|---|---|
| crate | box 1 x 1 x 1 | crate_big | box 1.7 x 1.7 x 1.7 |
| barrel, boom_barrel | cylinder r 0.42, h 1.15 | tire | cylinder r 0.6, h 0.38 |
| ball | sphere r 0.36 | beachball | sphere r 0.95 |
| anvil | box 0.55 x 0.5 x 1.0 | plank | box 3.2 x 0.16 x 0.55 |
| couch | 2.0 x 0.9 x 0.95 | cone | cone r 0.3, h 0.8 |
| boulder | sphere r 0.55 | pumpkin | r 0.46, h 0.4 |
| gravestone | 0.8 x 1.1 x 0.25 | coffin | 0.9 x 1.8 x 0.45 |
| battery | box 0.5 x 0.7 x 0.5 | fuse | cylinder r 0.22, h 0.62 |
| fan | 1.5 x 1.7 x 0.8 | flag | pole 2.4 tall |
| yeetball | sphere r 0.7 | basketball | sphere r 0.32 |
| volleyball | sphere r 0.5 | | |

### Make your own versions (new kinds of pieces and props)
A new kind of thing next to the built-in ones, with your model and numbers, no code. Step
by step: [CUSTOM_MAPS_GUIDE.md](CUSTOM_MAPS_GUIDE.md), "Your own versions";
`custom/make_your_own/` has an example of each and a map using them (Make Your Own
Workshop), and starter models with their markers (`models/`, made by
`tools/make_templates.gd`).

- **A piece** (pipe, drain, trap, door, button, light, machine, any piece with a **Model**
  slot): set its Model and numbers, then right-click > *Save Branch as Scene*; the saved
  scene is your new piece.
- **A trap** (TrapSpot > *Your Own Trap*): **Trap Name**, **Model**, **Damage** (a second),
  **Slows To** (speed across it, 1 full), **Burn** (seconds alight; only burning traps catch
  ghosts), **Blast** (goes off once, this big, then needs building again); -1 keeps the
  Kind's (spikes 30 / 0.4 / 0 / 0, fire 0 / 1 / 4 / 0, mine 0 / 1 / 0 / 6). Traps with the
  same name and model are one type in the shop; its picture is your model.
- **A prop**: a **PropType** resource (Create New > Resource > PropType) on a PropSpawn's
  **Type** slot: **Display Name**, **Behaves Like** (a built-in prop: how it breaks, blows
  up, floats, powers sockets), **Model** (origin in its middle), **Size** (the box it fills,
  metres; 0 the built-in one's), **Shape** (auto: its `Collision` mesh, made convex, if it
  has one, else the built-in shape; or box, ball, cylinder), **Mass**, **Bounce**,
  **Toughness** (impact energy that breaks it; props that break only), **Unbreakable**,
  **Breaks Into Its Parts** (it comes apart into its model's parts instead: each part named
  for its material like a BreakableModel's, `Wood_Side`, `Glass_Door`, `Metal_Handle`; each
  flies off whole as a prop, glass shatters; Behaves Like must be a prop that breaks: a crate,
  a plank...), **Color** (what it breaks into). It travels to every player like any prop.
- **A pickup**: a **PickupType** resource on a PickupSpawn's **Type** slot: **Display Name**,
  **Gives** (health, speed, super, feather, iron), **Heal** (health; 0: 50), **Lasts**
  (boost seconds; 0: the boost's), **Respawn**, **Model** (floats over the pad), **Color**
  (the ring).
- **More Model slots**: FlagStand (the flag sits 0.4 m up; the team light stays), PuzzleFan
  (`Rotor` spins; the fan keeps the built-in size and weight), Hoop and GoalZone.
- **A breakable wall's look**: BreakableSlab **Custom Material** (any material; a standard
  one is laid on by position, a repeat every **Texture Size** metres) on its faces; the
  broken edges keep **Material**'s look, and Material still sets how it breaks. Save the
  material as a `.tres` so the flying pieces match for every player.
- PropTypes and PickupTypes must be saved as files (`.tres`), not kept inside a scene: the
  game sends their path to the other players.
- **A ladder, a crane, a horn** of your own: their Model slots (see *Ladder, Crane, Horn*):
  a crane's `Turret` and `Hook`, a horn's `Lever`.
- **The map check's notes** (`--validate` prints them as NOTE, they don't fail the check):
  a model missing the markers its piece looks for, and what happens without them; a name
  that's nearly a marker's ("spout" for "Spout").

**Markers** (found by name, any depth; a Blender empty keeps its name and place; "points"
is its Y axis: a Single Arrow empty's arrow): `Spout` (FloodValve: where the water comes out
and which way; it arcs out and lands where it falls), `Intake` (FloodDrain: where water goes
in), `Collision` (props: a mesh, the shape; hidden), `Emitter` / `Light` / `Spin`
(Fixture), and the moving parts in *Themes* above. Without one, the piece's origin is used.

### Selecting pieces in the 3D view
The Map Kit's pieces draw themselves with internal meshes (not saved in the map), which
Godot doesn't pick when you click. The **Yeetwork Map Kit** editor plugin
(`addons/yeetwork_mapkit/`, on by default under *Project Settings → Plugins*) gives every
piece a click shape, so clicking a block, a slab, a prop or a puzzle piece selects it. It
also puts resize handles on boxes (blocks, hazard volumes, doors, lifts) and turns a Scale
tool drag on any sized piece into its Size.

### Adventures (a few maps linked by a story)
An adventure is a file and some maps, no code:
1. Build each chapter as a Puzzle level: **MapSettings** with **Puzzle** on, a **PuzzleExit**,
   spawn points; test it in Puzzle mode.
2. Right-click a folder > **Create New > Resource > Adventure**, and save it as
   `<name>.adventure.tres` in `adventures/` (or your custom map's folder).
3. Fill in its **Display Name** and **Description**, and add its **Chapters**: each a new
   **AdventureChapter** with its **Map**, a **Title** and an **Intro** for the card.

It's in the match setup under **Adventure (co-op)**. When every living Yeet is at a chapter's
exit, everyone moves on to the next map; Yeets start each chapter fresh, and the clock and the
end screen's counts carry over. The host's progress is saved as each chapter starts. Medal
times in a chapter's MapSettings don't count here. Example: `adventures/two_small_rooms.adventure.tres`.

**Telling the story** (these pieces work on any map, wired like other puzzle pieces):
- **StoryNote**: a thing to read (**Title**, **Text**, a **Picture**). Use opens it on the
  reader's screen. On once read: so it can open a door or count as a clue.
- **StoryLine**: a subtitle for everyone, a **Speaker** and their **Text**, with Yeetish babble as
  the **Voice**, when its **Inputs** come on. On once it's finished, so a conversation is a chain:
  each line's Input is the line before it. Lines never talk over each other.
- **StoryZone**: on when a Yeet walks in (**Stays**: once, or while inside; **Who**: anyone or
  everyone). What sets off a line as you enter a room, or a door slamming behind you.
- **StoryFlag**: the story's memory across chapters. **Action** `remember` sets its **Flag** when
  its Inputs come on; `check` is on when the flag is set, even from an earlier chapter, so a later
  map can react to what you did. Saved with the adventure.
- **TalkingYeet**: a Yeet who stands there and talks. Use says their next line; on once they've
  said them all. **Display Name**, **Lines**, **Voice**, **Shirt**, **Hat**, **Face**, **Character**.
- The map itself changing is ordinary wiring: an **AnimatedModel** with Inputs, a **PuzzleDoor**, a
  **Fixture** switching on.

### Custom maps (map packs)
Maps don't have to live in the game: make them in `custom/<your_map>/` (with their own
textures, materials, models, sounds and even scripts), export them with
`tools/export_map_pack.bat <your_map>` and drop the `.zip` into the game's `maps` folder.
Step by step with pictures: [CUSTOM_MAPS_GUIDE.md](CUSTOM_MAPS_GUIDE.md); the short
version for map makers is `custom/README.md`; `custom/example_garden/` is an example.
(Game builds leave `custom/` out; packs leave the game's own files out.)

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

High Seas' builder (`MapHighSeas`) notes everything it makes while it's exported; to save
`maps/high_seas.tscn` from it again (this **overwrites** it):

```bash
godot --headless --path . -- --host --map highseas --map-source code --bots 0 --tour x --tour-mode export_highseas
```
