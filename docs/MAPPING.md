# Yeetwork Map Kit

You build Yeetwork arenas in the **Godot editor** as ordinary scenes, using a few
drop-in nodes for gameplay (spawns, flags, breakable walls, jump pads...). Any scene in
`res://maps/` shows up in the game's map list automatically.

The example map `maps/courtyard.tscn` uses every node type. Open it, look around,
press **F6**, and you are playing it with bots.

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

Lighting is automatic (*MapSettings → Sky*): **sunset**, **day**, **night** or
**space**. You can still add your own `OmniLight3D` and `SpotLight3D` nodes for
accents. If your scene has its own `WorldEnvironment` or `DirectionalLight3D`, the
preset is skipped and yours is used.

---

## 4. Node reference

All kit nodes preview themselves in the editor. In game they become the real thing.

### MapSettings (one per map)
| Property | |
|---|---|
| Map Name, Author, Description | shown in the menu and HUD |
| Sky | `sunset`, `day`, `night`, `space` |
| Sun Rotation Degrees, Sun Energy Scale, Ambient Scale | tweak the preset |
| Ocean Preset | sea state with the *Sculpted* water style: `calm`, `lake`, `ocean`, `stormy` |
| Ocean, Ocean Level | surround the map with an animated sea whose surface sits at *Ocean Level*. Players who fall in sink and drown; wooden and rubber props float. Put your floors above it, and an island's sides look best reaching a few metres below it |
| Kill Height | anything below dies or respawns. Keep it ≥ 3 m below your lowest floor |
| Avoid Areas | XZ rectangles bots walk around (pits). `Rect2(x, z, width, depth)` |
| Playtest Mode / Playtest Bots | used by F6 |

### ArenaBlock (StaticBody3D)
A solid box with the arena surface shader (soft panels, warm/cool gradient).
- **Size**: use this, **do not scale** the node.
- Color, Roughness, Metallic, Emission (glow).
- **Ramps:** rotate a block around X or Z. Players can walk up to 46°, and steeper
  slopes are slides.

### BreakableSlab
A destructible wall, floor or bridge. In game it fractures into irregular pieces.
- **Orientation**:
  - *WALL*: upright. Width is local X, height is local Y, thickness is local Z.
    Rotate around Y to turn it.
  - *FLOOR*: flat. Length is local X, width is local Z. Rotate around Y to aim a bridge.
- **Size** (meters), **Thickness**.
- **Material**: `plaster`, `concrete`, `brick` (brick-shaped chunks), `wood` (plank
  splinters along the slab's length), `glass` (shards), `metal` (very tough).
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
- **Size** is the box size. For liquids, the surface sits 80% of the way up the box and
  the liquid fills the box below it. Give the pool a floor and walls: a liquid without a
  floor under it looks bottomless.
- **Damage** applies to acid and lava.
- Liquids can't be rotated; only the box's position counts.
- Water uses the host's water style: *Classic*, or *Sculpted* (sharper waves, ripples and
  wakes; pools are a calm sea state).

### Anything else
- **CSG nodes** (`CSGBox3D`, `CSGCylinder3D`, `CSGCombiner3D`...) with *Use Collision*
  on become solid geometry. They're great for blocking out complex shapes.
- **Imported meshes**: add a `StaticBody3D` with a collision shape (or use *Mesh →
  Create Collision Shape*). StaticBody3D's default collision layer is already correct.
- **Lights, decals, particles, decorative meshes**: used as-is.
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
