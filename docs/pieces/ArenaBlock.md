<!-- Made by tools/make_guide.gd from scripts/mapkit/arena_block.gd: change the comments there and run it again, not this page. -->
# ArenaBlock

*Building: a Map Kit piece (Add Child Node > ArenaBlock). Script: `scripts/mapkit/arena_block.gd`.* [All the pieces](README.md)

A solid box with the arena's look (soft panels, a warm to cool gradient): floors, walls, platforms, ramps. Most of a map is made of these.

- Size it with Size, or drag the handles on its faces in the 3D view (Ctrl: whole metres). The Scale tool works too: when you let go, the scale becomes Size (a scaled block would collide wrong).
- Ramps: rotate it about X or Z. Players walk up slopes up to about 46 degrees; steeper are slides.
- Surface ice: clear, slippery ice that can't be broken. Custom Material: your own material (a PBR texture set) instead of the colour, laid on in the map's own metres.
- Solid off: only seen (a painted stripe, trim). Bounciness: a ricochet surface.

## Settings

| Setting | Default | What it does |
|---|---|---|
| **Size** | `(4, 1, 4)` | Its size in metres (width X, height Y, depth Z). Type it, or drag the handles on its faces in the 3D view (Ctrl: whole metres). Don't scale a block: set its Size. |
| **Color** | `Color(0.42, 0.47, 0.62)` | Its colour (with the arena's soft panels on it). |
| **Roughness** | `0.7` | 0: glossy, 1: matte. *(0 to 1)* |
| **Metallic** | `0` | 0: paint or stone, 1: metal. *(0 to 1)* |
| **Emission** | `0` | Glow strength (0 = none). Great for neon trims and landmarks. *(0 to 8)* |
| **Surface** | `arena` | arena: the usual soft panels. ice: clear, frosty blue ice that can't be broken, and is slippery (Yeets skate on it, props glide). For breakable ice use a BreakableSlab of ice. Choices: `arena`, `ice`. |
| **Ice Clarity Map** | (none) | Ice only, optional: a clarity map (greyscale: white clear, black cloudy) and a normal map (the surface's bumps), wrapped onto every face; Ice Map Scale = repeats per metre. Without them the ice makes its own frost and bumps. |
| **Ice Normal Map** | (none) | Ice only: a normal map for the ice's surface bumps (empty: its own melted bumps). |
| **Ice Map Scale** | `0.5` | Ice only: how often the Ice Clarity Map and Ice Normal Map repeat per metre. *(0.05 to 4)* |
| **Custom Material** | (none) | Your own material instead of the colour above: PBR textures (albedo, normal, roughness, metallic, AO, height...). It's used as it is, every setting included, on a box whose texture coordinates are laid out in metres in the map, so the texture tiles evenly whatever the block's size and lines up across neighbouring blocks: Texture Size = the metres one repeat covers. The material's own UV1 Scale / Offset apply on top. |
| **Texture Size** | `2` | With a Custom Material: metres per repeat of its texture (laid out in the map's own metres, so neighbouring blocks line up). *(0.1 to 20)* |
| **Solid** | on | Off: nothing bumps into it, it's only seen (a painted stripe, window bands, a trim). |
| **Bounciness** | `0` | Ricochet surfaces: how much bounce things keep off it (0 = like any wall; 0.8 = a lot). A bouncy block is also frictionless, so things leave it at the angle they came in. *(0 to 1)* |

## Used in

[Example Garden](../../custom/example_garden/example_garden.tscn) (9), [Lighthouse Point](../../custom/lighthouse_point/lighthouse_point.tscn) (28), [Make Your Own Boat](../../custom/make_your_own/boat.tscn) (17), [Make Your Own Workshop](../../custom/make_your_own/workshop.tscn) (6), [Courtyard](../../maps/courtyard.tscn) (19), [Facing Yeets](../../maps/facing.tscn) (101), [The Fortress](../../maps/fortress.tscn) (45), [Haunted Yard](../../maps/haunted_yard.tscn) (15), [High Seas](../../maps/high_seas.tscn) (128), [Hoops Court](../../maps/hoops_court.tscn) (28), [Lagoon](../../maps/lagoon.tscn) (24), [Moving Day](../../maps/moving_day.tscn) (37), [Yeetwork Prime](../../maps/prime.tscn) (81), [The Pump House](../../maps/pump_house.tscn) (18), [The Scrapyard](../../maps/scrapyard.tscn) (29), [Test Chambers](../../maps/test_chambers.tscn) (75), [Volley Beach](../../maps/volley_beach.tscn) (5), [The Warehouse](../../maps/warehouse.tscn) (59), [Yeetball Stadium](../../maps/yeetball_stadium.tscn) (46)
