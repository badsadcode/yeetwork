<!-- Made by tools/make_guide.gd from scripts/mapkit/map_theme.gd: change the comments there and run it again, not this page. -->
# MapTheme

*The map: a type file (Create New > Resource > MapTheme). Script: `scripts/mapkit/map_theme.gd`.* [All the pieces](README.md)

A map's look in one file: a model for each kind of Map Kit piece and prop. Pick it in MapSettings > Theme and every jump pad, button, pipe, crate... on the map takes that look. Make one per theme (haunted, foundry, beach...): right-click a folder > Create New > Resource > MapTheme, then drag your models (.glb/.gltf/.blend/.tscn) onto the slots.

- A piece's own Model slot wins over the theme; an empty theme slot keeps the built-in look.
- Only the look changes: pieces work the same, props weigh and collide the same.
- Moving parts are found by name in the model (see docs/MAPPING.md, "Themes"): a button's "Cap", a plate's "Plate", a float switch's "Float", a valve's "Wheel", a seesaw's "Plank", a reset post's "Cap", a volley net's "Net".

## Settings

### Movement

| Setting | Default | What it does |
|---|---|---|
| **Ladder** | (none) |  |
| **Crane** | (none) |  |
| **Horn** | (none) |  |
| **Jump Pad** | (none) |  |
| **Lift** | (none) |  |
| **Grapple Point** | (none) |  |
| **Rope Anchor** | (none) |  |

### Puzzle pieces

| Setting | Default | What it does |
|---|---|---|
| **Button** | (none) |  |
| **Pressure Plate** | (none) |  |
| **Door** | (none) |  |
| **Target** | (none) |  |
| **Receptacle** | (none) |  |
| **Exit** | (none) |  |
| **Checkpoint** | (none) |  |
| **Reset Post** | (none) |  |
| **Seesaw** | (none) |  |
| **Turntable** | (none) |  |
| **Pulley** | (none) |  |
| **Magnet** | (none) |  |

### Water, fire, power

| Setting | Default | What it does |
|---|---|---|
| **Valve** | (none) |  |
| **Drain** | (none) |  |
| **Float Switch** | (none) |  |
| **Beacon** | (none) |  |
| **Contacts** | (none) |  |

### Lights

| Setting | Default | What it does |
|---|---|---|
| **Light Bulb** | (none) |  |
| **Light Lamp Post** | (none) |  |
| **Light Wall Lamp** | (none) |  |
| **Light Candle** | (none) |  |
| **Light Torch** | (none) |  |
| **Light Spotlight** | (none) |  |
| **Light Neon** | (none) |  |

### Modes

| Setting | Default | What it does |
|---|---|---|
| **Flag Stand** | (none) |  |
| **Goal** | (none) |  |
| **Hoop** | (none) |  |
| **Volley Net** | (none) |  |

### MegaYeet

| Setting | Default | What it does |
|---|---|---|
| **Heart** | (none) |  |
| **Trap Spikes** | (none) |  |
| **Trap Fire** | (none) |  |
| **Trap Mine** | (none) |  |

### Monsters

| Setting | Default | What it does |
|---|---|---|
| **Monster Shambler** | (none) | New looks for MegaYeet's monsters (their numbers stay the built-in ones'): models made of parts named Torso, Leg_L, Leg_R, Arm_L, Arm_R, Head, each with its origin at its joint (see MonsterType). |
| **Monster Runner** | (none) | The runners (drawn a little smaller than a Yeet). |
| **Monster Brute** | (none) | The brutes (drawn half again a Yeet's height). |
| **Monster Ghost** | (none) | The ghosts (drawn see-through and glowing). |
| **Monster Climber** | (none) | The climbers. |
| **Monster Bomber** | (none) | The bombers (drawn small). |
| **Monster Golem** | (none) | A boss, the Siege Golem: drawn three times a Yeet's height. |
| **Monster Ram** | (none) | A boss, the Wrecking Ram: drawn 2.4 times a Yeet's height. |

### Pickups

| Setting | Default | What it does |
|---|---|---|
| **Pickup Pad** | (none) |  |
| **Pickup Health** | (none) |  |
| **Pickup Health Big** | (none) |  |
| **Pickup Speed** | (none) |  |
| **Pickup Super** | (none) |  |
| **Pickup Feather** | (none) |  |
| **Pickup Iron** | (none) |  |

### Props

| Setting | Default | What it does |
|---|---|---|
| **Crate** | (none) |  |
| **Crate Big** | (none) |  |
| **Barrel** | (none) |  |
| **Boom Barrel** | (none) |  |
| **Ball** | (none) |  |
| **Beachball** | (none) |  |
| **Anvil** | (none) |  |
| **Plank** | (none) |  |
| **Couch** | (none) |  |
| **Tire** | (none) |  |
| **Cone** | (none) |  |
| **Boulder** | (none) |  |
| **Pumpkin** | (none) |  |
| **Gravestone** | (none) |  |
| **Coffin** | (none) |  |
| **Battery** | (none) |  |
| **Fuse** | (none) |  |
| **Fan** | (none) |  |
| **Flag** | (none) |  |
| **Yeetball** | (none) |  |
| **Basketball** | (none) |  |
| **Volleyball** | (none) |  |

## Used in

[Garden Theme](../../custom/example_garden/garden_theme.tres)
