<!-- Made by tools/make_guide.gd from scripts/mapkit/map_settings.gd: change the comments there and run it again, not this page. -->
# MapSettings

*The map: a Map Kit piece (Add Child Node > MapSettings). Script: `scripts/mapkit/map_settings.gd`.* [All the pieces](README.md)

The map's name and its world: the sky and light, the weather, a sea round it, how far down is death, its theme, what the Puzzle mode needs. Put exactly one in every map scene (any depth; usually the first child of the root). Running a map scene directly (F6) starts a test match with bots (Playtest Mode, Playtest Bots).

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Map Name** | `Untitled Arena` | Its name in the menu and on the HUD. |
| **Author** | (empty) | Who made it. |
| **Description** | (empty) | A line or two for the menu. |
| **Theme** | (none) | The map's look for its pieces and props: a MapTheme file (haunted, foundry, beach...). Empty: the built-in look. A piece's own Model slot still wins over the theme. |
| **Sky** | `sunset` | Environment: sky, light, haze, distant scenery and clouds. sunset, day, tropical (islands), desert (mesas, dunes), snow (peaks, pines), volcano (red sky, ash, a glowing volcano), storm (dark slate sky, low clouds), night, haunted (truly dark and misty: light it with MapLights; everyone carries a flashlight) or space. Choices: `sunset`, `day`, `tropical`, `desert`, `snow`, `volcano`, `storm`, `night`, `haunted`, `space`. |
| **Sun Rotation Degrees** | `(-42, 38, 0)` | Sun direction (rotation of the DirectionalLight3D, degrees). |
| **Sun Energy Scale** | `1` | Brighter (above 1) or dimmer sun than the Sky's. *(0 to 3)* |
| **Ambient Scale** | `1` | Brighter (above 1) or darker shade than the Sky's. *(0 to 3)* |
| **Flashlights** | `auto` | Flashlights on every Yeet: auto (on under a dark sky: haunted), on, off. Choices: `auto`, `on`, `off`. |
| **Ocean** | off | Surround the map with an animated ocean (players who fall in sink and drown, wooden props float on the waves). |
| **Ocean Level** | `-4` | With Ocean: the sea's surface height, metres. |
| **Ocean Preset** | `ocean` | Sea state with the "sculpted" water style: calm, lake, ocean or stormy. Choices: `calm`, `lake`, `ocean`, `stormy`, `extreme`. |
| **Ocean Swimmable** | off | Players swim in the ocean (and climb back out by a Ladder: bots swim to one whose foot is in the water) instead of sinking and drowning. |
| **Weather** | `none` | Weather around the players: rain, or a full storm (rain, wind wisps and lightning). The "storm" sky brings the storm by itself. Choices: `none`, `rain`, `storm`. |
| **Rain Intensity** | `0.7` | How hard it rains (0.1 drizzle .. 1 downpour) and the wind that slants it (m/s). *(0.1 to 1)* |
| **Rain Wind** | `(3, 0, 1)` | The wind slanting the rain, metres a second. |
| **Kill Height** | `-40` | Players and props below this height die / respawn. |
| **Avoid Areas** | (none) | Areas (XZ rectangles in world space) bots should walk around, e.g. pits. |
| **Puzzle** | off | A level made for the Puzzle (co-op) mode: --validate skips the team and flag checks. |
| **Grapple** | `anywhere` | The grapple hook: on any surface, only on GrapplePoints (puzzle levels: so it doesn't skip the puzzles; props and friends can always be grappled), or not at all. Choices: `anywhere`, `grapple points`, `off`. |
| **Open Level** | off | An open level: the HUD lists every unfinished objective (do them in any order), not just the first one. |
| **Gold Time** | `0` | Puzzle mode medals: finish within these times (seconds; 0 = no such medal). |
| **Silver Time** | `0` | Puzzle mode: finish within this many seconds for silver (0: no such medal). |
| **Bronze Time** | `0` | Puzzle mode: finish within this many seconds for bronze (0: no such medal). |
| **Playtest Mode** | `Sandbox` | Playtest settings used when you press F6 on this scene. Choices: `Sandbox`, `Capture the Flag`, `Dodgeball`, `Pumpkin Smash`, `Puzzle (co-op)`, `Yeetball`, `YeetHoops`, `YeetVolley`, `MegaYeet (co-op)`. |
| **Playtest Bots** | `3` | Bots in a test match from the editor (F6). *(0 to 11)* |

## Used in

[Example Garden](../../custom/example_garden/example_garden.tscn), [Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn), [Make Your Own Boat](../../custom/make_your_own/boat.tscn), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn), [Courtyard](../../maps/courtyard.tscn), [Facing Yeets](../../maps/facing.tscn), [The Fortress](../../maps/fortress.tscn), [The Foundry](../../maps/foundry.tscn), [Haunted Yard](../../maps/haunted_yard.tscn), [High Seas](../../maps/high_seas.tscn), [Hoops Court](../../maps/hoops_court.tscn), [Lagoon](../../maps/lagoon.tscn), [Moving Day](../../maps/moving_day.tscn), [Yeetwork Prime](../../maps/prime.tscn), [The Pump House](../../maps/pump_house.tscn), [The Scrapyard](../../maps/scrapyard.tscn), [Test Chambers](../../maps/test_chambers.tscn), [Volley Beach](../../maps/volley_beach.tscn), [The Warehouse](../../maps/warehouse.tscn), [Yeetball Stadium](../../maps/yeetball_stadium.tscn)
