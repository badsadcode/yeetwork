<!-- Made by tools/make_guide.gd from scripts/mapkit/encounter_wave.gd: change the comments there and run it again, not this page. -->
# EncounterWave

*Adventure: a type file (Create New > Resource > EncounterWave). Script: `scripts/mapkit/encounter_wave.gd`.* [All the pieces](README.md)

One wave of an Encounter: how many of what come through its rifts. The next wave comes once they're all dead.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Shamblers** | `0` | How many of each built-in kind. *(0 to 200)* |
| **Runners** | `0` | Fast, and they fall apart. *(0 to 200)* |
| **Brutes** | `0` | Huge and slow; too heavy to grab. *(0 to 50)* |
| **Ghosts** | `0` | Drift through walls; only light and fire hurt them. *(0 to 100)* |
| **Climbers** | `0` | Climb any wall in the way. *(0 to 100)* |
| **Bombers** | `0` | Run at Yeets with a powder keg. *(0 to 100)* |
| **Boss** | `none` | A boss leading this wave in: the Siege Golem, or the Wrecking Ram. Choices: `none`, `golem`, `ram`. |
| **Boss Health** | `1500` | The boss's hit points (more with more Yeets playing). *(100 to 50000)* |
| **Own Monsters** | (none) | Monsters of your own (MonsterType files; their From Wave and Share are for MegaYeet). |
| **Own Count** | `0` | How many of each of your own come. *(0 to 200)* |
| **Spawn Gap** | `0.5` | Seconds between one monster coming through and the next. *(0.05 to 10)* |

## Start from

- [`adventures/the_cellar/cellar.tscn`](../../adventures/the_cellar/cellar.tscn): the waves are in the Encounters' Waves: built-in kinds, a boss, monsters of your own
