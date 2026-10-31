# Ideas backlog

Ideas worth keeping. Nothing here is scheduled until it is picked up.

## High Seas (map, in progress)

The MV *Bad Decisions*: a giant container ship on the open ocean.

1. **Ship and motion** (phase 1, done): the ship rolls, pitches and heaves on the ocean's
   long swell, the same on every peer; loose cargo slides and rolls with the tilt.
2. **Layout** (phase 2, first step done: "around the ship"): overboard isn't the end (a
   swimmable sea, ladders up the hull; bots swim to them), the bridge as a room (breakable
   windows, the ship's horn, ladders through hatches in its wings), lashing bridges between
   the bays, bots routed round the forecastle's drop. Still to do: interiors (a cabin route
   inside the superstructure), more of the bow.
3. **Cargo** (phase 2, done: lashed containers that break loose to blasts, pushes, lightning
   and a storm's rolling, creaking first; open containers with pickups; floating cargo; far
   drifting cargo comes back). Original notes: secured containers with breakable restraints, sliding containers, open and
   special containers, floating debris overboard, ladders back aboard.
4. **Weather** (phase 2, done: the Hurricane variant (an extreme sea, up to 20 degrees of
   roll), green water washing over the low side in storms, rogue waves with a warning, the
   horn and a lurch, wet decks; the ship's motion on a smooth clock of its own). Original
   notes: calm, rough, storm and extreme presets; rain, lightning, waves washing over
   the deck, rogue waves, wet decks.
5. **Machinery** (done: the engine room below deck, built from Map Kit Fixtures, dry below
   the waterline, with a scalding steam leak and a zapping switchboard; a deck crane
   sweeping a swinging container over the forward stacks). Possible later: more cranes, a
   crane players can work.

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

- Done: a flashlight on/off key (synced), lights that break when hit (and come back on),
  lightning that strikes the map itself (a tall thing set alight). The fire look (new: charred surface,
  ember cracks, ray-marched volumetric flames, embers; Options keeps the classic one).

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

## Docs: characters (done: docs/CHARACTERS.md, drop-in folders in assets/characters/)

A step-by-step tutorial on adding and changing character models and attachments (hats,
head extras, outfits): where they're built, the Blender file, and replacing a part with a
model of your own.

## Sound pass (done: docs/SOUNDS.md: recordings replace any sound by name, Yeetish voices, metal clangs rate-limited, a louder crowd)

Tomek's notes after playing Yeetball: metal clangs (barrels and the like) get really
annoying when they repeat; the crowd cheer is too quiet to notice. Go over impact
variety, volume and repetition, and the sports sounds.

## Trailer tool

Scripted, recorded scenes outside the game (camera moves, directed bots, explosions),
rendered with Godot's movie writer for a YouTube trailer.

## Music and volume controls (done: assets/music/ tracks by name, Music and Sound effects sliders with switches, Match music)

Tomek is making music for the menu screen, and maybe ambient tracks. Needed: a music player
(menu music, optional in-game ambience), and in Options separate volume sliders for
**Music** and **Sound effects** (on top of the master volume), each with an on/off switch.
Music files dropped into a folder like the sounds (assets/music/), no code.

## MegaYeet (mode; first step done: shamblers, the Fortress meter and zones, waves and breaks, combos and style kills, bots, the fall and a fresh start, the Fortress map, Map Kit pieces)

Next steps, as proposed: (2) monster kinds (runner, brute that smashes gates and can't be
grabbed, ghost only light and fire hurt, climber, bomber) and grabbing monsters with the
gun; (3) the break between waves: spend the meter on repairs, traps and team upgrades; (4)
more maps (a factory), the gate repair; (5) bosses, polish and tuning for the Steam Deck.
Fire doesn't hurt them yet.

Co-op survival: endless waves of NPC monsters (zombies, Frankenstein's monsters, ghosts and
the like) come for the players, who work together and use everything the game has (the
gravity gun, props, explosives, fire, water, traps, the map) to survive as long as possible.
Waves grow bigger and nastier. To design: monster kinds and how they move and attack (they
must be yeetable), wave pacing, downed/revive or respawns, scoring (waves survived), which
maps, bots joining in.

- **Team lift** (Tomek, for later): a really heavy object (a huge iron ball, a siege
  boulder) that one Yeet's gravity gun can't lift, but several together can: their guns'
  strength adds up, and together they hurl it. A weapon of mass destruction for huge waves
  or a boss fight. To design: how many guns it takes, how the throw is aimed and timed when
  several hold it (whoever charges last? the average aim?), how the HUD shows "2 of 3 pulling".

## Set dressing with features (done: the Map Kit's **Fixture**; see MAPPING.md)

Built as described below, except the big fan's gentle push (not yet).

Tomek's idea: decoration pieces that do more than sit there. A Blender model of machinery
filling out an environment, with its own hum or buzz. A Map Kit piece (say **Ambience** or
**Fixture**) with a model slot and a sound slot, both swappable, no code. Suggestions to
build into it:
- **Sound**: a looping 3D sound (hum, buzz, drip, crackle, radio chatter) with volume and
  reach; random one-shots now and then (a clank, a hiss); pitch variation.
- **Motion**: spin a named part (fans, gears, a radar dish), bob or sway (a hanging sign, a
  buoy), shake/vibrate (a running engine).
- **Effects**: particles from a named point (steam, smoke, sparks, drips), a light that
  flickers or pulses with it, a glow material.
- **Puzzle wiring**: on/off by inputs (power restored: the machine starts humming and
  turning; off: it winds down).
- **Breakable**: hit hard enough it breaks (sparks, the hum stops, smoke), like the map
  lights; comes back after a while.
- **Gameplay touches** (optional): a hot or electrified area around it (hurts), a gentle
  push (a big fan), a camera shake nearby (heavy machinery).
- Themes can supply them (a theme's `fixture_<name>` slot), like the other pieces.
