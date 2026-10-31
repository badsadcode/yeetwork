# Sounds: replacing them, and the Yeets' voices

Every sound in Yeetwork is made by the game's code when it starts (`scripts/fx/sfx.gd`):
nothing is a recording. Any of them can be **replaced by a recording of your own**, with no
code: save it into **`assets/sounds/`** named after the sound.

| You save | What happens |
|---|---|
| `assets/sounds/boom.ogg` | every explosion plays your recording instead of the made-up one |
| `assets/sounds/boom_1.ogg`, `boom_2.ogg`, `boom_3.ogg` | variants: one is picked at random each time (repeats sound less samey) |

- Formats: **.ogg** (best), .wav or .mp3.
- The game still plays your sound a little higher or lower each time (as it does its own),
  louder for bigger hits, and places it in 3D.
- Sounds in the list marked *loops* loop by themselves: make them seamless.
- Take a file out and the made-up sound is back.

To hear a change: from the **Godot editor**, switch to its window (it imports the new file by
itself) and play (F5). The built `Yeetwork.exe` only has the recordings that were there when
it was exported: export it again (*Project → Export*), or ask Claude to build it.

## The Yeets' voices (Yeetish)

The Yeets shout when things happen to them, in **Yeetish**: gibberish. For now the voices
are made-up placeholders (`scripts/fx/yeetish.gd`). Your recordings replace them the same way,
named `voice_<kind>`, and several takes per kind is best, so they don't repeat:
`voice_hurt_1.ogg`, `voice_hurt_2.ogg`, `voice_hurt_3.ogg`...

| Sound | When | Like | Length |
|---|---|---|---|
| `voice_hurt` | taking a hit | a short "oof", "ow", "agh" | ~0.2 s |
| `voice_die` | dying | a falling wail, "wa-aaah" | ~0.8 s |
| `voice_scream` | launched, knocked flying, ragdolling | a high scream, "aaaah!", "wheee!" | ~0.7 s |
| `voice_grabbed` | grabbed by someone's gravity gun | an indignant "hey?!" | ~0.3 s |
| `voice_taunt` | just got a kill | sing-song teasing, "nya-nya-nyaa" | ~0.5 s |
| `voice_cheer` | their team scored | "yee-YAH!" | ~0.6 s |
| `voice_burn` | on fire (now and then while it lasts) | "ah! ah! ah!", hot hot hot | ~0.4 s |
| `voice_gasp` | coming up after a while under water | a breath in, then "hah" | ~0.5 s |
| `voice_yay` | picking up a power-up | "ya-hoo!" | ~0.5 s |
| `voice_effort` | charging a throw to the full | a strained "hnnngh" | ~0.5 s |
| `voice_yeet` | letting go of a fully charged throw | "YEET!" | ~0.3 s |

How they're used:

- **Every Yeet has its own voice pitch** (the same on every player's screen): your recording
  is played between about 0.85x and 1.25x speed, so one take sounds like many Yeets. Noor's is
  a little higher. Record at a natural pitch: the game does the rest.
- They don't talk all the time: a shout has a chance of happening, a Yeet waits about a second
  before the next one (dying, a taunt and a cheer always get through), and at most three Yeets
  shout at once.
- *Options → Yeet voices* turns them off.
- A new kind needs a line of code to say when it's used (`Player.shout()` in
  `scripts/player/player.gd`); recordings for the kinds above need none.

**Recording tips:** mono, trim the silence at the start (it delays the shout) and the end,
peaks around −1 dB, a few takes of each with different words and pitch. Gibberish works best
when it's short and the emotion is clear from the melody: up for surprise and joy, down for
pain.

## Every sound

Effects (3D: heard from where it happens, unless marked *UI*):

| Sound | When |
|---|---|
| `thud` | the body of most impacts (anything hitting anything) |
| `thud_heavy` | the sub-bass under heavy hits |
| `land` | a Yeet landing from a jump or a fall |
| `smack` (also `hit`) | a body hitting something; things hitting a Yeet |
| `crunch` | the crunchy top of very hard hits (bodies, stone, wood) |
| `stone` | stone and concrete being hit |
| `wood` | wood being hit (crates, planks) |
| `metal` (also `clang`) | metal being hit: barrels, anvils (quick repeats are skipped; light taps ring softer) |
| `boing` | rubber (balls, tyres), jump pads |
| `glass` | glass and ice being hit, glass breaking |
| `splat` | gore, a ragdoll slapping down |
| `crack` | something cracking or breaking apart |
| `splinter` | wood splintering when it breaks |
| `creak` | a wall or a structure straining before it gives way |
| `boom` | explosions |
| `punt` | the gravity gun's push |
| `throw` | throwing something with the gravity gun |
| `whoosh` | fire catching, a beacon lighting, big swooshes |
| `jump` | jumping |
| `zap` | electricity, a live wire's shock |
| `spawn` | respawning, a prop appearing (*UI* when it's you) |
| `slide` | sliding |
| `sizzle` | fire put out by water, acid, lava |
| `splash` | something falling into water |
| `death` | a Yeet dying (the body's sound; `voice_die` is the shout) |
| `squelch` | a pumpkin bursting (Pumpkin mode, Halloween) |
| `heal` | a first aid kit |
| `powerup` | a power-up taken |
| `pickup` | small blips: picking things up, puzzle beeps |
| `charge` | the gravity gun winding up a throw |
| `arc` | the gravity gun's hum while holding (*loops*) |
| `fire` | burning things (*loops*) |
| `thunder` | distant thunder in a storm |
| `thunder_crack` | a close lightning strike (*UI*) |
| `wind` | wind (*loops*) |
| `rain` | rain (*loops*) |
| `hum` | a machine's mains hum: generators, pumps (*loops*; Map Kit Fixtures) |
| `buzz` | an electric buzz with crackles: switchboards (*loops*) |
| `engine` | a diesel engine thumping below decks (*loops*) |
| `fan` | air through a fan (*loops*) |
| `steam` | a steam leak's hiss (*loops*) |
| `radio` | a radio left on: static and a voice in it (*loops*) |
| `ship_horn` | High Seas' horn |

Match and menu sounds (*UI*: the same everywhere):

| Sound | When |
|---|---|
| `score` | a point, a goal, a flag captured |
| `whistle`, `whistle_long` | the referee's whistle (kick-off, full time) |
| `cheer` | the crowd cheering a goal |
| `horn` | the stadium horn |
| `tick` | the countdown's last seconds of a power-up |
