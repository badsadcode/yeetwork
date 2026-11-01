<!-- Made by tools/make_guide.gd from scripts/mapkit/hazard_volume.gd: change the comments there and run it again, not this page. -->
# HazardVolume

*Building: a Map Kit piece (Add Child Node > HazardVolume). Script: `scripts/mapkit/hazard_volume.gd`.* [All the pieces](README.md)

A box that does something to whatever is in it, by Kind: acid or lava (a glowing pool that hurts and bounces you up), water (a pool to swim in; wood and rubber float), kill (instant death: under a void), wind (a constant push: an updraft) or fire (a burning place: flames over the bottom of the box that set players and wood alight).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Kind** | `acid` | acid and lava hurt and bounce up; water is a pool to swim in; kill is instant death (under- map voids); wind pushes (updrafts); fire sets alight what's in it. Choices: `acid`, `kill`, `wind`, `water`, `lava`, `fire`. |
| **Size** | `(8, 2, 8)` | Its box, metres. For a liquid the surface sits 80% of the way up (give it a floor and walls). |
| **Damage** | `22` | Acid / lava: damage per touch. Others: ignored. |
| **Fire Color** | `orange` | Fire: the colour of the flames (orange fire, or blue / green magic fire). Choices: `orange`, `blue`, `green`. |
| **Wind** | `(0, 30, 0)` | Wind: acceleration in m/s^2 (world space). |

## Used in

[Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn), [Courtyard](../../maps/courtyard.tscn) (2), [Lagoon](../../maps/lagoon.tscn) (2), [Moving Day](../../maps/moving_day.tscn), [Yeetwork Prime](../../maps/prime.tscn), [The Scrapyard](../../maps/scrapyard.tscn), [Test Chambers](../../maps/test_chambers.tscn) (4)
