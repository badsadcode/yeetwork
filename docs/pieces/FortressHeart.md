<!-- Made by tools/make_guide.gd from scripts/mapkit/fortress_heart.gd: change the comments there and run it again, not this page. -->
# FortressHeart

*MegaYeet: a Map Kit piece (Add Child Node > FortressHeart). Script: `scripts/mapkit/fortress_heart.gd`.* [All the pieces](README.md)

MegaYeet: what the players defend (put one at the fortress's centre). Monsters head for it through the fortress; one that reaches it (within Radius) takes a big bite out of the Fortress meter. The built-in look is a glowing crystal over a pedestal; Model (or the theme's `heart` slot) replaces it: a throne, a reactor, a giant cake. MegaYeet Rules: how the game goes on this map (the Fortress meter's size, what a bite and a kill are worth, the breaks, how big the waves get): tune it to the fortress you built.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Radius** | `2.5` | A monster this close (metres) has reached it. |
| **Model** | (none) | Your own Heart (a throne, a reactor, a giant cake) instead of the crystal. |
| **Color** | `Color(0.35, 0.9, 1.0)` | Its glow's colour (it flashes red when a monster bites). |
| **Monster Types** | (none) | Monsters of your own (MonsterType files) joining the waves: each from its From Wave on, as its Share of every wave. |

### MegaYeet Rules

| Setting | Default | What it does |
|---|---|---|
| **Health** | `1000` | The Fortress meter: how much it holds (the team's life). *(100 to 10000)* |
| **Bite** | `40` | What a monster reaching the Heart takes off it. *(0 to 1000)* |
| **Kill Refill** | `3` | What a kill puts back, and the extra for a stylish one (a fall, a crush, fire, lava...). *(0 to 100)* |
| **Style Refill** | `2` | The extra a stylish kill puts back (a fall, a crush, fire, lava...). *(0 to 100)* |
| **Wave Bonus** | `60` | What holding a wave puts back. *(0 to 2000)* |
| **First Break** | `12` | Seconds before the first wave, and between waves. *(3 to 120)* |
| **Break Time** | `25` | Seconds between waves. *(3 to 300)* |
| **Wave Size** | `1` | How many monsters a wave brings, times this (1: 24 in wave 1, ten more each wave). *(0.2 to 5)* |
| **Max Monsters** | `220` | The most monsters at once (the rest of a wave waits for room). Mind the Steam Deck. *(10 to 400)* |
| **Boss Every** | `5` | A boss wave every this many waves (0: never): the Siege Golem leads it in. *(0 to 50)* |
| **Boss Health** | `3000` | Its hit points (more with more Yeets playing, and each time it comes back), and what bringing it down puts back in the meter. *(200 to 50000)* |
| **Boss Reward** | `300` | What bringing the boss down puts back in the meter. *(0 to 5000)* |

## Start from

- [`custom/make_your_own/scarecrow.tres`](../../custom/make_your_own/scarecrow.tres): a monster of your own for Monster Types (see MonsterType)

## Used in

[Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [The Fortress](../../maps/fortress.tscn)
