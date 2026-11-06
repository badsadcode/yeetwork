<!-- Made by tools/make_guide.gd from scripts/horde/monster_type.gd: change the comments there and run it again, not this page. -->
# MonsterType

*MegaYeet: a type file (Create New > Resource > MonsterType). Script: `scripts/horde/monster_type.gd`.* [All the pieces](README.md)

MegaYeet: your own monster, joining the waves beside the built-in ones. It behaves like the built-in kind you pick (Behaves Like: a runner sprints, a brute smashes gates, a ghost drifts through walls, a climber scales them, a bomber blows up) with your model and your numbers. Make one: right-click a folder > Create New > Resource > MonsterType, save it next to your model, fill it in, and add it to the map's FortressHeart (Monster Types).

- Model: facing -Z (Blender: +Y, like the Yeets), its feet at the origin, about a Yeet's height (1.8 m; Size scales it). Made of parts named Torso, Leg_L, Leg_R, Arm_L, Arm_R and Head, each with its origin at its joint (the hip, the shoulder, the neck): the game swings them the way it swings the built-in monsters (a lurching walk, reaching arms, flailing when thrown, a lolling head). Anything else rides on the torso (or on the part it's inside). "Glow" in a part's or a material's name makes it glow.
- Everything at 0 is the built-in kind's.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Display Name** | (empty) | Its name in the game (the wave announcement). |
| **Behaves Like** | `shambler` | The built-in monster it acts like: how it moves, what it can do. Choices: `shambler`, `runner`, `brute`, `ghost`, `climber`, `bomber`. |
| **Model** | (none) | Your model: parts named Torso, Leg_L, Leg_R, Arm_L, Arm_R, Head, each with its origin at its joint. |
| **Hit Points** | `0` | Hit points (0: the built-in kind's: a shambler 40, a runner 20, a brute 320). *(0 to 5000)* |
| **Speed** | `0` | Metres a second (0: the built-in kind's: a shambler 1.7, a runner 4). *(0 to 10)* |
| **Bite** | `0` | What a bite takes off a Yeet (0: the built-in kind's: a shambler 7, a brute 24). *(0 to 200)* |
| **Bash** | `0` | What a hit takes off a gate (0: the built-in kind's: a shambler 22, a brute 110). *(0 to 1000)* |
| **Size** | `0` | How big it's drawn and how big it is (1: a Yeet's height; 0: the built-in kind's). *(0 to 4)* |
| **Burns** | `0` | How hard fire hurts it (1 as a shambler; 0: the built-in kind's). *(0 to 5)* |
| **Remains** | `a body` | What it leaves when it dies: a body (and blood, by the gore setting), or a puff of dust and nothing else. Choices: `a body`, `dust`. |
| **Grabbable** | `as it` | Whether the gravity gun can grab it ("as it": like the kind it behaves like). Choices: `as it`, `yes`, `no`. |

### In the waves

| Setting | Default | What it does |
|---|---|---|
| **From Wave** | `1` | It comes from this wave on. *(1 to 50)* |
| **Share** | `0.2` | How much of each wave it is from then on (0.2: a fifth). *(0 to 1)* |
| **Announce** | (empty) | Shown the first time it comes (empty: "<NAME>S!"). |

## Your model's markers

Name these parts (or empties, for places) in your model exactly so: the map check notes a near miss like "spout".

| Name | What it does | Without it |
|---|---|---|
| `Torso` | the body (its origin: the hips) | anything not in another part is the torso anyway |
| `Leg_L, Leg_R` | swing from their origins (the hips) as it walks | no stride (and the map check notes it) |
| `Arm_L, Arm_R` | reach and flail from their origins (the shoulders) | no reaching (and the map check notes it) |
| `Head` | lolls (its origin: the neck) | no lolling (and the map check notes it) |
| `Glow` | in a part's or a material's name (or an emissive material): it glows | nothing glows |

## Start from

- [`custom/make_your_own/scarecrow.tres`](../../custom/make_your_own/scarecrow.tres): a scarecrow come alive (behaves like a shambler; straw burns)
- [`custom/make_your_own/models/scarecrow.glb`](../../custom/make_your_own/models/scarecrow.glb): its model, its parts named, each origin at its joint

## Used in

[Scarecrow](../../custom/make_your_own/scarecrow.tres), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn)
