# Ideas backlog

Ideas worth keeping. Nothing here is scheduled until it is picked up.

## High Seas (map, in progress)

The MV *Bad Decisions*: a giant container ship on the open ocean.

1. **Ship and motion** (phase 1, done): the ship rolls, pitches and heaves on the ocean's
   long swell, the same on every peer; loose cargo slides and rolls with the tilt.
   To do next in phase 2: bots bunch up at the bow ramps.
2. **Layout**: cargo deck routes over and between containers, the bridge (breakable
   windows, ship's horn), the bow, interiors.
3. **Cargo**: secured containers with breakable restraints, sliding containers, open and
   special containers, floating debris overboard, ladders back aboard.
4. **Weather**: calm, rough, storm and extreme presets; rain, lightning, waves washing over
   the deck, rogue waves, wet decks.
5. **Machinery**: cranes with swinging loads, the engine room.

Design notes from the brief: motion builds gradually and stays readable (creaks and
scraping before cargo lets go), most containers stay secured, falling overboard is not
instant death, everything gameplay-relevant is server-authoritative and deterministic.

## Co-op puzzle mode (proposal)

No bots, 1-4 players get through a level together with physics: collect, open doors,
physics puzzles, rescue a Lost Yeet, deliver a fragile package. Full proposal, new Map Kit
pieces and a first level: [PUZZLE_COOP.md](PUZZLE_COOP.md). Step 1 is built; the plan was
revised with Noor's notes (multiple solutions always count, nothing stays broken, celebrate
ridiculous solutions; six test chambers).

## Gravity gun: Grapple mode (later)

A second mode for the same gun: amber energy, claws partly retracted, an energy anchor on a
tether that attaches to surfaces, props and players; swinging, reeling in and out, heavy
things pull you to them, emergency recovery after falling off. The gun stays as it is for
now.

## Themed environments (built: the haunted sky, MapLight, flashlights, storm lightning)

- Later: a flashlight on/off key (synced), lights that break when hit, lightning that can
  strike the map itself (a tall thing set alight). The fire look (new: charred surface,
  ember cracks, tongues of flame, embers; Options keeps the classic one).

## Pickups and power-ups (first batch built)

Placed with PickupSpawn, respawning; the host can turn power-ups off. First batch (Tomek
picked all of them; built, see the README). Later: more kinds, a pickup sound pass.
- **First aid kit**: +50 HP (a big one +100).
- **Speed boost**: 40% faster for 12 s; blue speed lines at the screen edge, a slight FOV
  kick.
- **Super Yeet**: throws, punts and launches 1.8x stronger for 15 s; a pulsing orange edge
  glow, the gun glows hotter.
- **Feather**: low gravity and high jumps for 12 s; a soft cyan haze.
- **Iron Yeet**: can't be grabbed or knocked around, half damage, 12 s; a metallic rim.
Every timed buff shows on the HUD: what it is and a countdown, plus its screen effect.

## Docs: characters (requested)

A step-by-step tutorial on adding and changing character models and attachments (hats,
head extras, outfits): where they're built, the Blender file, and replacing a part with a
model of your own.

## Sound pass (later)

Tomek's notes after playing Yeetball: metal clangs (barrels and the like) get really
annoying when they repeat; the crowd cheer is too quiet to notice. Go over impact
variety, volume and repetition, and the sports sounds.

## Trailer tool

Scripted, recorded scenes outside the game (camera moves, directed bots, explosions),
rendered with Godot's movie writer for a YouTube trailer.
