# Make your own, Phase 5: things that animate

The last part of [Make your own](MAKE_YOUR_OWN.md): scenery, monsters, the Yeets and the
gravity gun with your own models, moving the way you made them move. This is the plan;
nothing in it is built yet. Agreed with Tomek 2026-11-02: both kinds of monster (parts that
swing first, rigged later), new monster kinds and new looks both, each player picks their
own gun, rigged Yeets decided later; and first of all, animated scenery (Tomek's most likely
use of Blender animation: things that spin, swing, move to and fro).

## Where things stand

| Thing | Today | Your own version today |
|---|---|---|
| Monsters (7 kinds, the boss) | built in code; drawn by the hundred in one batch per kind; a shader swings six tagged parts (torso, two legs, two arms, head) | none |
| Yeets | built in code; code animates each part (walk, run, jump, slide, swim, ragdoll...) | hats, head extras, outfits and body parts: a folder each, no code ([CHARACTERS.md](../CHARACTERS.md)) |
| The gravity gun | one model, `assets/models/gravity_gun.glb`; the game moves its parts `Muzzle`, `Core`, `ClawPivot0-2` and tints `Accent` | only by overwriting that file |
| Scenery that moves | a Spinner turns what's under it; a Fixture's `Spin` part turns, it sways; the pieces' named moving parts | a model's own Blender animations never play |

**The one hard limit: the horde.** MegaYeet draws up to 600 monsters and simulates 200+ on a
Steam Deck because each kind is a single mesh drawn many times at once, animated by the
graphics card. A normal rigged character (its own skeleton, its own animation player) per
monster would be far too slow at those numbers. So rigged monsters need the crowd trick big
games use: the animations are **baked into textures** once (when the game loads your model),
and the same shader plays them for hundreds at once. Everything below is built around that.

## Two ways to make a monster move

**A. Parts that swing (no rigging).** Model your monster in separate parts, named like
markers: `Torso`, `Leg_L`, `Leg_R`, `Arm_L`, `Arm_R`, `Head` (anything else rides on the torso;
`Glow` in a material's or part's name makes it glow). Put each part's origin at its joint (the
hip, the shoulder, the neck): that's where it swings from. The game swings them the way it
swings the built-in monsters now: a lurching walk, reaching arms, flailing when thrown, a
lolling head. Quick to make, no Blender rigging at all, as fast as the built-in ones.

**B. Rigged, with your animations.** A normal rigged model (an armature, skinned mesh) with
actions named for what they're for:

| Action | Plays when | Without it |
|---|---|---|
| `Walk` | walking toward the Heart, chasing | (required) |
| `Run` | a fast kind's walk | `Walk`, faster |
| `Attack` | hitting a Yeet, battering a gate | `Walk` |
| `Climb` | climbing a wall (a climber kind) | `Walk` |
| `Fly` | thrown, blasted, falling | `Walk`, sped up |
| `Stunned` | dazed after a hit or a crash | `Walk`, slowed |
| `Held` | wriggling in the gravity gun | `Fly` |
| `Die` | the death tumble | the body tumbles as now |
| `Idle` | standing still (rare) | `Walk`, slowed |

When the map loads, the game bakes each action into a texture (a few frames a second of
animation, every vertex) and the monster shader plays it, each monster at its own point in
it, blending from one action to the next. Up to the same numbers as now.

**5a done** (2026-11-02): AnimatedModel, four starter models (windmill, sign, platform,
drawbridge), all four in the Make Your Own Workshop (the drawbridge on a button to an islet),
its page, the guide's step 4i, checks (the windmill on the shared clock, a ferry ride, the
drawbridge on its button; a client sees it turn). Next: 5b, your own gravity gun.

## The pieces to build

0. **AnimatedModel** (a Map Kit piece): your model, playing its own Blender animations in
   the game: a windmill, a swinging sign, a bobbing buoy, a piston, a sliding platform, a
   flag in the wind. **Model**, **Animation** (which action; empty: the first), **Speed**,
   **Loop** (or **Ping Pong**: there and back), **Offset** (seconds, so several don't move in
   step). Every player sees it at the same point of its animation (it runs off the match
   clock: nothing sent). **Inputs** (it's a puzzle piece): it plays while they're on, and
   stops (or runs back, **Reverse When Off**) when they go off: a drawbridge, a gate, a lift
   you made. **Solid**: its parts named `Collision...` move with the animation and carry
   what stands on them (a turning platform, a swinging log that knocks Yeets off). Spinning,
   sliding or swinging parts don't need rigging: object animation in Blender is enough;
   armatures work too.

1. **MonsterType files** (like PropType): right-click > Create New > Resource > MonsterType.
   **Display Name**, **Behaves Like** (a built-in kind: how it moves, what it can do: climb,
   float through walls, blow up...), **Model** (A or B above), and its numbers: **Hit Points**,
   **Speed**, **Bite** (damage to a Yeet), **Bash** (to a gate), **Size**, **Grabbable**,
   **Burns** (how much fire hurts it). Your types join the waves: a MonsterSpawn's **Types**
   list says which come out of that rift (and from which wave on), and the map's FortressHeart
   says how many of a wave are yours.
2. **A map theme's monster slots**: MapTheme gets a model slot per built-in kind (a haunted
   theme's shamblers as mummies), the numbers staying the built-in ones'.
3. **Parts that swing**: the monster shader learns each part's own joint (from your model)
   instead of the built-in monsters' fixed hip and shoulder heights.
4. **Baked animations**: the baking (load time, cached per model), the shader that plays
   them, and which action each monster is in (sent with the snapshots it already gets: no
   more network traffic).
5. **The boss of your own**: there's only ever one, so it can be a full rigged character
   with a normal animation player: its own `Stomp`, `Throw` (a boulder) and `Summon`
   actions on top of the list above.
6. **Your own gravity gun**: a `assets/characters/guns/` folder like the hats', each a model
   with the same named parts as the built-in gun (`Muzzle`, `Core`, `ClawPivot0-2`, the
   `Accent` material); picked in the Character menu, everyone sees each player's own gun. If
   the model has actions `Grab`, `Hold`, `Charge`, `Throw`, they play (one gun per player:
   a normal animation player is fine).
7. **Yeets that move your way** (the biggest, and last): a whole Yeet as one rigged model,
   with actions for everything a Yeet does (`Idle`, `Run`, `Jump`, `Fall`, `Slide`, `WallRun`,
   `Climb`, `Swim`, `Grab`, `Throw`, `Hit`...) and the ragdoll taking over from it when
   knocked flying. Hats and extras keep working (bones named `Head`, `Torso`... hold them).
   Today's code animation stays for anyone without such a model.

Each comes with what the earlier phases had: a starter model in
`custom/make_your_own/models/` (a monster in parts, a rigged monster, a gun), the Make Your Own
Workshop using them, the piece pages and the guide, a check in CI.

## The order (a suggestion)

| Step | What | Size | Needs from you |
|---|---|---|---|
| 5a | AnimatedModel: scenery playing its own animations (0) | small-medium | nothing: starter models come with it (a windmill, a swinging sign, a moving platform) |
| 5b | Your own gravity gun (6) | small | your gun model (`gravity_gun1.blend`?) when you like |
| 5c | MonsterType files with parts that swing (1, 3), MapTheme monster slots (2) | medium | nothing: a starter monster comes with it |
| 5d | Rigged monsters, baked animations (4), the boss of your own (5) | big | a rigged test monster helps (a free one works for building it) |
| 5e | Rigged Yeets (7) | biggest | decided later |

5a and 5b are the quick wins: animated scenery and your own gun. 5c brings your own monsters
into the waves without rigging; 5d rigged ones. 5e is a project of its own.

## Decided (2026-11-02)

- Monsters: new models and new kinds, the animation staying as it is: parts that swing (5c)
  is what's wanted. Rigged, baked monsters (5d) only if ever wanted.
- Both: new monster kinds in the waves (MonsterType) and new looks for the built-in ones
  (MapTheme slots).
- The gun: Tomek models one gun (low-poly, hand-painted PBR textures) to replace the
  built-in one; being able to keep several versions and pick one is a nice extra. So 5b:
  the guns folder, a **Default Gun** (what everyone has: Tomek's gun once it's there), and
  the Character menu picker for anyone who wants another.
- Yeets: a fully rigged Yeet decided later (5e).
