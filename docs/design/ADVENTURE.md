# Adventure mode: the plan

A home for many co-op adventures: each a few maps linked by a story, played together, each in
its own style. This is the plan, agreed with Tomek 2026-11-04.

**A1 done** (2026-11-05): the Adventure and AdventureChapter files, the mode (ModeAdventure, on
top of Puzzle mode), moving on between chapters (Main swaps the World on every peer, the
connection staying up; each says hello again, so a late joiner lands in the right chapter),
chapter cards, the save and Continue (AdventureRun), the test adventure *Two Small Rooms*
(`tools/make_adventure_test.py`), checks (solo, a client following, a client joining late).
Story flags are saved and carried over, but nothing sets or reads them yet: that's A2.
Next: A2, the story pieces.

## Decided

- **Many adventures, each with its own style:** one can be silly-spooky, another properly
  creepy, another pure comedy. The mode doesn't pick a tone; each adventure does.
- **Puzzles, then set-piece fights:** mostly exploring and physics puzzles, as in Puzzle mode,
  broken up by a few big moments (ghosts in the attic, a monster-filled cellar, a boss at the
  end). Dying sends you to a checkpoint, never back to the start.
- **Notes and talking Yeets:** clues and notes to find and read, short subtitled lines with
  Yeetish babble as the voice, and the map itself changing as the story goes. No voice acting,
  no cutscenes that take away control.
- **Everything editable in Godot, no code,** like every other map: an adventure is a file and
  some maps, so Tomek can write new ones himself.

## Adventure ideas (Tomek's)

- **An investigation in a big mansion,** maybe a haunted one: clues to find, rooms to open.
- **A level built enormous:** a house with giant books, giant furniture. The Yeets are their
  normal size and nobody gets shrunk; the map is just bigger, so they look and feel tiny.
  Climbing a bookshelf, crossing a desk, books as bridges and walls, a sofa as a mountain.
  This needs no new game code: it's map building (see "Building big" below).

## What's already there

Puzzle mode does much of it already: co-op for 1-4 players with no bots and no frags, objectives
at the top of the screen, checkpoints, an exit, key props that come back, doors and logic, the
Lost Yeet, the clock and the end screen. The Map Kit builds the places, AnimatedModel and the
puzzle pieces change them as things happen, MonsterType gives each adventure its own monsters,
and MapTheme its own look.

## What's missing

1. **The Adventure file** (a Resource, like MonsterType): its **Name**, **Description**, a
   **Picture**, and its **Chapters**: the maps in order, each with a title and a line or two for
   the chapter card. Adventure files in a folder show up in the match setup, in a new mode.
2. **The mode** (built on Puzzle mode): when everyone reaches a chapter's exit, a chapter card,
   then the next map, for every player together. Today a match never changes maps mid-way, so
   this is the first real new engineering: the server moving everyone on, and someone joining
   late landing in the right chapter.
3. **What carries over:** story flags ("found the butler's diary", so a later map can react)
   and the team's stats for the end screen. Not health, not things carried. The Yeets start
   each chapter fresh, which keeps levels fair to build.
4. **Saving:** per adventure, on the host: the chapter reached and the flags. The host gets
   **Continue** or **Start over**.
5. **Story pieces** (Map Kit):
   - **StoryNote:** a thing to read. Use opens a panel with your text (and a picture, if any);
     it switches on once read, so it can open a door or count as a clue. Your own model.
   - **StoryLine:** a subtitled line, a speaker's name and some text with Yeetish babble as the
     voice, played when its Inputs come on: a room entered, a door opened, a note read.
   - **StoryZone:** on when a Yeet walks in (once, or while inside): what sets lines and fights
     off.
   - **StoryFlag:** sets a flag, or is on when one is set, including from an earlier chapter.
   - **Talking Yeet:** a Yeet who stands there and says their lines when you Use them.
6. **Encounter** (a Map Kit piece): the set-piece fight. When its Inputs come on, it wakes its
   rifts and sends in what you list (kinds, MonsterTypes, a boss), in waves if you like; it's on
   once they're all dead, so it can open the way on. If everyone falls, back to the checkpoint and
   it starts again. The catch: monsters today only exist in MegaYeet and only head for a Heart.
   Here each Encounter has its own **Goal** point and they chase whoever's near. That's the
   second piece of real engineering.

## Building big (the giant house, for one)

No new code, but things to get right, for the guide:

- **Sizes are in metres, whatever it looks like:** a Yeet still jumps about as high and reaches
  as far, so a shelf's steps must still be jumpable. Scale the look, not the moves: every
  "giant" surface is built to a Yeet's reach.
- **Things to throw are normal-sized to a Yeet:** a thimble, a pencil, a domino, a sugar cube as
  PropTypes, with the crate's weight. They sell the scale better than anything.
- **Check the far view:** a huge room is a long way across, so it may need fog or walls to keep
  draw costs down on a Steam Deck. `--tour-mode deckperf` measures it.
- Bots aren't in Adventure, so their route map doesn't matter here; monsters' does.

## The order

| Step | What | Size |
|---|---|---|
| A1 | The Adventure file, the mode, moving on between chapters, chapter cards, saving (1-4); a tiny two-room test adventure to prove it | medium |
| A2 | Story pieces: StoryNote, StoryLine, StoryZone, StoryFlag, Talking Yeet (5), piece pages | small-medium |
| A3 | Encounter: monsters outside MegaYeet, the Goal, fights that reset (6) | medium |
| A4 | The first real adventure: three or four chapters, about an hour together | big, mostly maps |
| A5 | A guide, "Write your own adventure", from building A4; Tomek's next ones | small, then yours |

Each step comes with a check in CI, like everything else. A1 to A3 can be tested with the tiny
adventure; only A4 needs real art and writing, and placeholders do until Tomek's come in.

## To decide

- **Which adventure comes first** (A4). The giant house needs fewer new pieces and shows off
  quickly; the mansion uses all of them, so it proves the whole mode.
- **Can a client's progress count?** The plan saves on the host only: if you play on with
  someone else hosting, the story's in their save.
