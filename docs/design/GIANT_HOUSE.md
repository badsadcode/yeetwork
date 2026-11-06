# Grandma's Glasses: the plan

The first real adventure (A4 in [ADVENTURE.md](ADVENTURE.md)), agreed with Tomek 2026-11-05. A cosy
comedy in a giant house: the Yeets are their normal size, nobody's been shrunk, the house is just
enormous.

**The study is built** (2026-11-06), with placeholder boxes: `tools/make_giant_house.py` writes it,
`adventures/grandmas_glasses/`. **Next: Tomek plays it** and judges the scale and feel, before three
more maps are built on them.

## The story

A giant old lady has lost her glasses and can't see a thing. She's hired the Yeets to find them.
You never see her: she's huge subtitled lines from somewhere overhead ("A VOICE"), mostly talking
to the wrong thing, because she can't see you either. Each chapter's clue sends you on to the next
room. At the very end the Yeets get the glasses to her, she puts them on, and for the first time she
notices them. The last line of the adventure is her reaction.

## The chapters

| | Room | The main idea | The fight |
|---|---|---|---|
| 1 | The hallway | Under the front door; learning how big everything is; a coat to climb | (none: a first taste, maybe one mouse) |
| 2 | **The study** (built first) | Climbing the bookshelf; a book toppling into a bridge to the desk; her diary | Dust bunnies behind the books |
| 3 | The kitchen | The sink overflowing, floating up on what floats; toaster springs; a hot hob | Mice |
| 4 | The nursery, then the sitting room | Wind-up toys; the glasses at last | Toys, then the family cat, the boss (a charger, dazed when it hits the furniture) |

## The scale

Everything real is built **20 times bigger**. A Yeet stands 1.8 m in the game, so they look about 9 cm
tall. That sets the sizes:

| Real thing | In the game |
|---|---|
| Door, 2 m | 40 m |
| Ceiling, 2.5 m | 50 m |
| Study, 4 x 3 m | 80 x 60 m |
| Bookshelf, 1.5 m | 30 m |
| Desk top, 75 cm | 15 m up |
| A big book, 25 cm tall | 5 m |
| Matchbox | 1 m: a crate |
| Thimble, 2 cm | 0.4 m |
| Domino, 5 cm | 1 m long |

What a Yeet can actually do doesn't scale, so **every route is built to these numbers**, whatever it
looks like:

- A jump rises about **1.5 m**, so anything meant to be jumped rises **1.2 m at most**.
- A running jump goes about 6.8 m on the flat, a walking one 3.6 m, so gaps are **5 m at most**, or
  3 m where a slow player has to make it.
- Shelves are 7 m apart: nobody jumps that. Each one needs a way up: stacked books as stairs, a
  bookmark ribbon as a ladder, a spring as a jump pad, something to grapple.

The Yeets must never need to be good at movement to finish a chapter. Wall-runs and grapples can
be shortcuts, not the only way.

## The study

1. **The floor.** In under the door, onto a rug the size of a car park. A TalkingYeet explains the
   job. Grandma says something to a lamp, thinking it's you. A checkpoint.
2. **The shelf.** Stacked books as stairs up to the first shelf, a bookmark ribbon up to the second.
   Things to throw lying about, normal-sized to a Yeet: a thimble, dominoes, sugar cubes.
3. **The fight.** Dust bunnies come out from behind the books on the second shelf (a checkpoint just
   before). The shelf has no rail: punting one off the edge is the fun way to win.
4. **The bridge.** Weigh down a pressure plate (the gun's job, with something heavy): a huge book
   topples across the gap and lands on the desk.
5. **The desk.** Across it, past the lamp and the pencils, to her diary (a StoryNote): she last had
   her glasses in the kitchen. Reading it opens the way on, and a StoryFlag remembers it. The exit's
   a way off the desk and out.

About 10 to 15 minutes for a team that's new to it. The whole adventure is about an hour.

## How the study was made

The generator (`tools/make_giant_house.py`) writes plain Map Kit, so the map can be edited in Godot
afterwards (rerunning the generator overwrites it). What it needed besides the map:

- **Fights up on a shelf:** an Encounter only uses ground from about its rifts' height upward. One
  knocked off that ground falls and is out of the fight.
- **The falling book:** an AnimatedModel, with a small scene of its own (`models/falling_book.tscn`),
  a box, an animation, and a `Collision` box: Godot scenes work as models, not only imports.
- **The light:** a ceiling shuts the sun out and everything goes blue-black, so the walls and ceiling
  have ArenaBlock's **Casts Shadow** off: the sun comes through them, the furniture throws shadows.
- **Dust bunnies don't bleed:** MonsterType's **Remains**.
- **The Steam Deck tool** measures levels too, from Marker3Ds named `View...` and in the fight.
- **The check** (`--tour-mode study`) walks the whole route with a real Yeet and real jumps, so a step
  that's too high fails in CI.

**Still to come, for chapter 4:** a boss's own name and hint on the wave ("THE CAT", in place of "THE
WRECKING RAM").

## Art: what's worth modelling first

All placeholders, and all swappable without code. In the order they'd change how it looks most:

1. **Books:** the room is mostly books. The real look would be a few book models or a texture with
   spines on (ArenaBlock's **Custom Material** tiles a texture without new models).
2. **The dust bunny** (`models/dust_bunny.tscn`, on `types/dust_bunny.tres`): parts named Torso, Head,
   Leg_L, Leg_R, Arm_L, Arm_R.
3. **The big book** (`models/falling_book.tscn`): keep an animation and a `Collision...` part.
4. **The desk, lamp, armchair** as models over the boxes that make them solid.
5. **Things to throw** (`types/`): thimble, domino, sugar cube, matchbox.
6. **Floorboards and wallpaper:** textures, the same way as the books.

## After the study

Play it. If the scale feels wrong, this is the moment to change it, at the cost of one map. Then the
other three chapters, then A5, the "Write your own adventure" guide, from what building these taught.
