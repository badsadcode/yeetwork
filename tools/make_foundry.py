"""Builds maps/foundry.tscn, The Foundry, MegaYeet's second fortress, from Map Kit pieces: a
sprawling works, no rings and no symmetry, the Heart off to one end in the furnace hall. Three
ways in that play differently:
- west: the scrapyard, then the assembly hall, long and straight, catwalks overhead;
- north: the pipe alley, narrow and twisting round the boiler house, its rift shut until wave 3;
- south: over the bridge across a chemical canal (off the edge, it's the end of them), the docks
  with their crane and containers, then along the yard to the furnace hall's side gate.
Yeets start in the control room, beside the furnace hall; jump pads cross the walls between
the parts of the works (for players and bots: the only way to monsters behind a closed gate).
Run from the repo root:
    python tools/make_foundry.py
The map is plain Map Kit afterwards: edit it in Godot as you like (rerunning this overwrites it).
"""
import math

out = []
ext = [("settings", "map_settings"), ("block", "arena_block"), ("slab", "breakable_slab"), ("spawn", "spawn_point"),
       ("prop", "prop_spawn"), ("pad", "jump_pad"), ("zone", "defense_zone"), ("rift", "monster_spawn"), ("heart", "fortress_heart"),
       ("trap", "trap_spot"), ("hazard", "hazard_volume"), ("crane", "crane"), ("fixture", "fixture"), ("light", "map_light")]
out.append('[gd_scene format=3]\n')
for i, f in ext:
    out.append('[ext_resource type="Script" path="res://scripts/mapkit/%s.gd" id="%s"]' % (f, i))
out.append('')
out.append('[node name="Foundry" type="Node3D"]\n')
out.append('''[node name="MapSettings" type="Node" parent="."]
script = ExtResource("settings")
map_name = "The Foundry"
author = "Yeetwork"
description = "A sprawling old works, the Heart in its furnace hall. Three ways in: the long assembly hall, the twisting pipe alley, and the bridge over the chemical canal."
sky = "sunset"
ambient_scale = 1.9
kill_height = -20.0
avoid_areas = Array[Rect2]([Rect2(-96, 37.5, 96.5, 13), Rect2(5.5, 37.5, 90.5, 13)])
playtest_mode = 8
playtest_bots = 3
''')
for g in ["Ground", "Walls", "Works", "Gates", "Zones", "Rifts", "Spawns", "Props", "Pads", "Traps", "Machines", "Lights"]:
    out.append('[node name="%s" type="Node3D" parent="."]\n' % g)

n = {"i": 0}
BRICK = "Color(0.56, 0.32, 0.25, 1)"
BRICK2 = "Color(0.47, 0.27, 0.22, 1)"
CONCRETE = "Color(0.5, 0.5, 0.47, 1)"
OIL = "Color(0.34, 0.34, 0.37, 1)"
STEEL = "Color(0.36, 0.39, 0.44, 1)"
RUST = "Color(0.55, 0.33, 0.17, 1)"
HAZARD = "Color(0.95, 0.75, 0.15, 1)"
WOOD = "Color(0.6, 0.42, 0.25, 1)"
IRON = "Color(0.42, 0.45, 0.5, 1)"
T = 1.5
WALL_H = 10.0
GATE_H = 5.0


def xf(x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    return "Transform3D(%g, 0, %g, 0, 1, 0, %g, 0, %g, %g, %g, %g)" % (round(c, 5), round(s, 5), round(-s, 5), round(c, 5), x, y, z)


def block(parent, x0, z0, x1, z1, y0, y1, color, name=None, extra=""):
    """A box from corner to corner."""
    n["i"] += 1
    out.append('[node name="%s" type="StaticBody3D" parent="%s"]\ntransform = %s\nscript = ExtResource("block")\nsize = Vector3(%g, %g, %g)\ncolor = %s\n%s'
               % (name or "Block%d" % n["i"], parent, xf((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), abs(x1 - x0), y1 - y0, abs(z1 - z0), color, extra))


def slant(x0, z0, x1, z1, h, color=BRICK):
    """A wall from one point to another, at any angle."""
    n["i"] += 1
    length = math.hypot(x1 - x0, z1 - z0)
    yaw = math.atan2(-(z1 - z0), x1 - x0)
    out.append('[node name="Block%d" type="StaticBody3D" parent="Walls"]\ntransform = %s\nscript = ExtResource("block")\nsize = Vector3(%g, %g, %g)\ncolor = %s\n'
               % (n["i"], xf((x0 + x1) / 2, h / 2, (z0 + z1) / 2, yaw), length, h, T, color))


def gate(name, x, z, along_x, w, h, material, color):
    out.append('[node name="%s" type="Node3D" parent="Gates"]\ntransform = %s\nscript = ExtResource("slab")\nsize = Vector2(%g, %g)\nthickness = 0.5\nmaterial = "%s"\ncolor = %s\nanchor_bottom = true\nanchor_top = true\nanchor_left = true\nanchor_right = true\n'
               % (name, xf(x, h * 0.5, z, 0.0 if along_x else -math.pi / 2), w, h, material, color))


def wall(x0, z0, x1, z1, h=WALL_H, gaps=(), color=BRICK):
    """A straight wall along X or Z, with gaps: (centre along it, width, bottom, top, gate name, gate material, gate colour).
    Bottom 0 is a doorway (with its lintel; a gate name closes it); higher up, a window."""
    along_x = z0 == z1
    a0, a1 = (x0, x1) if along_x else (z0, z1)
    fixed = z0 if along_x else x0

    def seg(s0, s1, y0, y1, col):
        if s1 - s0 < 0.01 or y1 - y0 < 0.01:
            return
        if along_x:
            block("Walls", s0, fixed - T / 2, s1, fixed + T / 2, y0, y1, col)
        else:
            block("Walls", fixed - T / 2, s0, fixed + T / 2, s1, y0, y1, col)

    at = a0
    for c, w, bottom, top, gname, gmat, gcol in sorted(gaps):
        seg(at, c - w / 2, 0, h, color)
        seg(c - w / 2, c + w / 2, 0, bottom, color)
        seg(c - w / 2, c + w / 2, top, h, BRICK2)
        if gname:
            if along_x:
                gate(gname, c, fixed, True, w, top, gmat, gcol)
            else:
                gate(gname, fixed, c, False, w, top, gmat, gcol)
        at = c + w / 2
    seg(at, a1, 0, h, color)


def node(parent, name, script, x, y, z, extra=""):
    out.append('[node name="%s" type="Node3D" parent="%s"]\ntransform = %s\nscript = ExtResource("%s")\n%s' % (name, parent, xf(x, y, z), script, extra))


def paint(x0, z0, x1, z1, color, y=0.02):
    """A floor marking: seen, not bumped into."""
    block("Ground", x0, z0, x1, z1, 0.0, y, color, None, "solid = false\n")


def hazard_stripes(x0, z0, x1, z1):
    """A yellow band in front of a gate."""
    paint(x0, z0, x1, z1, HAZARD, 0.03)


# --- Ground: the works, the canal's pit, the far bank -----------------------------------------
GROUND = "Color(0.4, 0.42, 0.36, 1)"
block("Ground", -96, -66, 96, 38, -6, 0, GROUND, "GroundNorth")
block("Ground", -96, 38, 96, 50, -6, -3, "Color(0.2, 0.22, 0.18, 1)", "CanalBed")
block("Ground", -96, 50, 96, 72, -6, 0, GROUND, "GroundSouth")
paint(-82, -46, -43, 30, "Color(0.43, 0.38, 0.3, 1)")  # (the scrapyard's dirt)
paint(-43, -7, 80, 38, CONCRETE)  # (the yard)
paint(-43, -24, 30, -7, OIL, 0.03)  # (the hall's floor)
paint(30, -52, 72, 3, "Color(0.3, 0.27, 0.26, 1)", 0.03)  # (the furnace hall's)
paint(32, 3, 54, 15, STEEL, 0.03)  # (the control room's)
paint(-43, -56, 30, -24, "Color(0.37, 0.37, 0.35, 1)")  # (the alley's)

# --- The canal: chemicals (the monsters won't walk in; thrown in, that's it) ------------------
node("Works", "Canal", "hazard", 0, -1.625, 44, 'kind = "acid"\nsize = Vector3(192, 2.75, 12)\n')
# The bridge: a stone causeway from the bed up (no rails: push them off).
block("Works", 0.5, 38, 5.5, 50, -3, 0, CONCRETE, "Bridge")
paint(0.5, 38, 1, 50, HAZARD, 0.03)
paint(5, 38, 5.5, 50, HAZARD, 0.03)

# --- Outer walls (uneven on purpose) ----------------------------------------------------------
# The scrapyard, its south-west corner cut off.
wall(-82, -46, -43, -46, 7)
wall(-82, -46, -82, 8, 7)
slant(-82, 8, -60, 30, 7)
wall(-60, 30, -43, 30, 7)
# The line between the scrapyard and the rest: the hall's west gate, a side gate into the yard.
wall(-43, -56, -43, 38, WALL_H, [(-15.5, 7, 0, GATE_H, "HallWestGate", "wood", WOOD), (12, 5, 0, GATE_H, "YardSideGate", "wood", WOOD)])
# The alley's north side, and the boiler yard.
wall(-43, -56, 30, -56, 8)
# The furnace hall, its north-east corner cut off.
wall(30, -56, 30, 3, WALL_H, [(-46, 5, 0, GATE_H, "FurnaceAlleyGate", "metal", IRON), (-15.5, 7, 0, GATE_H, "FurnaceHallGate", "metal", IRON), (-22, 3, 5.5, 8.2, None, None, None)])
wall(30, -52, 60, -52, WALL_H)
slant(60, -52, 72, -40, WALL_H)
wall(72, -40, 72, 3, WALL_H)
wall(30, 3, 80, 3, WALL_H, [(43, 4, 0, 4.0, None, None, None), (63, 6, 0, GATE_H, "FurnaceYardGate", "metal", IRON)])
# The hall's long south wall; the yard's east end.
wall(-43, -7, 30, -7, WALL_H)
wall(-43, -24, 30, -24, WALL_H)
wall(80, 3, 80, 38, 6)
# The far bank's pen.
wall(-25, 50, -25, 66, 5)
wall(35, 50, 35, 66, 5)
wall(-25, 66, 35, 66, 5)
hazard_stripes(-41.5, -19, -40.5, -12)
hazard_stripes(27.5, -19, 28.5, -12)
hazard_stripes(60, 0.5, 66, 1.5)
hazard_stripes(60, 4.5, 66, 5.5)
hazard_stripes(30.8, -48.5, 31.8, -43.5)
hazard_stripes(0.5, 36, 5.5, 37.5)

# --- The pipe alley: what makes it narrow and twisting ----------------------------------------
block("Works", -14, -56, 18, -35.5, 0, 12, BRICK2, "BoilerHouse")
block("Works", -14, -30, 30, -24.75, 0, 6, RUST, "PipeRack")
block("Works", -43, -38, -22, -24.75, 0, 6, BRICK2, "AlleySheds")
for x in (-10, -2, 6, 14):  # (pipes over the alley, rack to boiler house)
    block("Works", x, -35.5, x + 1, -30, 5.2, 6, RUST, None)
block("Works", 20, -56, 24, -44, 0, 4, RUST, "BoilerTank")
node("Machines", "AlleyPipes1", "fixture", 2, 0, -29.2, 'kind = "pipes"\nsolid = false\n')
node("Machines", "BoilerEngine", "fixture", 21, 4, -50, 'kind = "engine"\nsolid = false\n')

# --- The assembly hall: catwalks along both sides, a walkway across, machines down the sides ---
CAT_Y = 5.5
block("Works", -42.25, -23.25, 29.25, -21, CAT_Y - 0.4, CAT_Y, STEEL, "CatwalkNorth")
block("Works", -42.25, -10, 29.25, -7.75, CAT_Y - 0.4, CAT_Y, STEEL, "CatwalkSouth")
block("Works", -24, -21, -21, -10, CAT_Y - 0.4, CAT_Y, STEEL, "WalkwayAcross1")
block("Works", 10, -21, 13, -10, CAT_Y - 0.4, CAT_Y, STEEL, "WalkwayAcross2")
for i, x in enumerate((-32, -14, 4, 20)):  # (down the sides, the middle kept clear: a straight run)
    z = -21 if i % 2 == 0 else -10
    node("Machines", "HallMachine%d" % i, "fixture", x, 0, z, 'kind = "%s"\n' % ("engine" if i % 2 == 0 else "generator"))
    node("Machines", "HallMachineB%d" % i, "fixture", x + 8, 0, -31 - z, 'kind = "%s"\n' % ("generator" if i % 2 == 0 else "engine"))
for x in range(-36, 30, 12):  # (roof trusses: just seen)
    block("Works", x, -24, x + 0.4, -7, 9.4, 9.8, STEEL, None, "solid = false\n")

# --- The furnace hall ------------------------------------------------------------------------
block("Works", 58, -50, 71.25, -30, 0, 8, BRICK2, "Furnace")
block("Works", 57.9, -46, 58.1, -35, 1, 4, "Color(1, 0.45, 0.1, 1)", "FurnaceGlow", "emission = 4.0\nsolid = false\n")
node("Works", "FurnaceMouth", "hazard", 56, 0.4, -40.5, 'kind = "fire"\nsize = Vector3(3, 1, 8)\n')
block("Works", 62, -48, 67, -43, 8, 34, BRICK, "StackFurnace")
block("Works", 61.8, -48.2, 67.2, -42.8, 30, 31, "Color(0.95, 0.75, 0.15, 1)", "StackBand", "solid = false\n")
block("Works", 31, -51, 34, 2, CAT_Y - 0.4, CAT_Y, STEEL, "CatwalkFurnaceWest")
block("Works", 34, -23.5, 46, -20.5, CAT_Y - 0.4, CAT_Y, STEEL, "CatwalkOverHeart")
block("Works", 66, -28, 71, -22, 0, 3.5, RUST, "HoppersA")
block("Works", 66, -12, 71, -4, 0, 2.5, RUST, "HoppersB")
node("Machines", "FurnaceGen1", "fixture", 68, 3.5, -25, 'kind = "generator"\nsolid = false\n')
node(".", "Heart", "heart", 52, 0, -22, 'radius = 3.0\ncolor = Color(1, 0.55, 0.2, 1)\nwave_size = 0.85\nfirst_break = 16.0\nbreak_time = 30.0\n')  # (more ground to cover than the Fortress)

# --- The control room: Yeets start here (a low south wall to hop; monsters can't) -------------
wall(32, 3, 32, 15, 4)
wall(54, 3, 54, 15, 4)
wall(32, 15, 54, 15, 1.1, [], STEEL)
block("Works", 34, 11, 40.5, 12.5, 0, 1, STEEL, "ControlDeskWest")  # (the way from the door to the low wall kept clear)
block("Works", 45.5, 11, 52, 12.5, 0, 1, STEEL, "ControlDeskEast")
for k, (x, z) in enumerate([(35, 6), (39, 6), (47, 6), (51, 6), (35, 9), (39, 9), (47, 9), (51, 9)]):
    node("Spawns", "Spawn%d" % k, "spawn", x, 0, z)

# --- The yard and docks ----------------------------------------------------------------------
block("Works", -36, -2, -8, 14, 0, 7, BRICK2, "Warehouse")
block("Works", -30, 3, -26, 7, 7, 26, BRICK, "StackWarehouse")
block("Works", 2, -48, 7, -43, 12, 30, BRICK, "StackBoiler")
CONTAINERS = ["Color(0.85, 0.42, 0.1, 1)", "Color(0.13, 0.45, 0.55, 1)", "Color(0.6, 0.18, 0.15, 1)", "Color(0.2, 0.38, 0.22, 1)"]
stacks = [(-18, 24, 0), (-18, 24, 1), (-11, 29, 0), (14, 22, 0), (14, 22, 1), (14, 22, 2), (24, 30, 0), (40, 32, 0), (40, 32, 1), (58, 28, 0), (70, 20, 0), (70, 20, 1)]
for k, (x, z, lvl) in enumerate(stacks):
    block("Works", x - 3, z - 1.25, x + 3, z + 1.25, lvl * 2.6, (lvl + 1) * 2.6, CONTAINERS[k % 4], "Container%d" % k)
node("Machines", "DockCrane", "crane", 30, 0, 24, 'height = 14.0\njib = 18.0\ncable = 4.0\nheading = 150.0\nsweep = 55.0\nperiod = 40.0\n')
for x in (8.5, -3.5):  # (bollards at the bridge's head)
    block("Works", x - 0.5, 36.5, x + 0.5, 37.5, 0, 1, STEEL, None)

# --- The scrapyard: heaps of junk --------------------------------------------------------------
heaps = [(-66, -24, 8, 6, 2.0), (-64, -22, 4, 3, 4.0), (-52, -36, 6, 8, 1.6), (-58, 2, 9, 5, 2.4), (-60, 3, 4, 3, 4.4), (-50, 20, 7, 6, 1.4), (-72, -6, 5, 7, 1.8)]
for k, (x, z, sx, sz, h) in enumerate(heaps):
    block("Works", x - sx / 2, z - sz / 2, x + sx / 2, z + sz / 2, 0, h, [RUST, "Color(0.4, 0.36, 0.33, 1)", "Color(0.5, 0.25, 0.15, 1)"][k % 3], "Heap%d" % k)

# --- Zones (deepest wins where they overlap) ---------------------------------------------------
# (None over the scrapyard, the docks or the alley's mouth, where monsters arrive: the meter only
# drains once they're getting somewhere.)
zones = [("ZoneHall", 1, -21.5, -15.5, 43, 17, "the assembly hall"), ("ZoneHallEnd", 2, 15, -15.5, 30, 17, "the hall's far end"),
         ("ZoneAlley", 1, 2, -33, 32, 10, "the pipe alley"), ("ZoneBoilerYard", 2, 24, -43, 12, 26, "the boiler yard"),
         ("ZoneYard", 1, 60, 20.5, 40, 35, "the yard"), ("ZoneYardEnd", 2, 65, 12.5, 30, 19, "the furnace door"),
         ("ZoneFurnace", 3, 51, -24.5, 42, 55, "the furnace hall"), ("ZoneControl", 3, 43, 9, 22, 12, "the control room")]
for name, lvl, x, z, sx, sz, label in zones:
    node("Zones", name, "zone", x, -0.5, z, 'level = %d\nsize = Vector3(%g, 14, %g)\nzone_name = "%s"\n' % (lvl, sx, sz, label))

# --- Rifts (the first is where a boss comes from) ----------------------------------------------
rifts = [("RiftScrapNorth", -74, -38, 3.5, 1), ("RiftScrapSouth", -73, 13, 3.5, 1), ("RiftFarBank", 3, 58, 4.0, 1), ("RiftAlley", -32, -48, 3.0, 3), ("RiftFarBankEast", 24, 59, 3.0, 5)]
for name, x, z, r, wave in rifts:
    node("Rifts", name, "rift", x, 0, z, "radius = %g\n" % r + ("from_wave = %d\n" % wave if wave > 1 else ""))

# --- Trap spots ---------------------------------------------------------------------------------
traps = [("SpikesAlley", -4, -32.75, "spikes", 4, 5), ("FireAlleyEnd", -18, -44, "fire", 4, 4), ("MineAlleyGate", 26, -46, "mine", 4, 4),
         ("SpikesHallWest", -36, -15.5, "spikes", 4, 6), ("MineHall", -6, -15.5, "mine", 4, 6), ("FireHallEast", 23, -15.5, "fire", 4, 6),
         ("SpikesBridge", 3, 33, "spikes", 5, 4), ("MineYard", 44, 24, "mine", 4, 4), ("FireYardGate", 63, 9, "fire", 5, 4)]
for name, x, z, kind, sx, sz in traps:
    node("Traps", name, "trap", x, 0, z, 'kind = "%s"\nsize = Vector3(%g, 1, %g)\n' % (kind, sx, sz))

# --- Jump pads: up onto the catwalks, a heap, the warehouse -------------------------------------
pads = [(-37, -11, 0, CAT_Y + 0.2, 2.5), (-1, -19.5, 0, CAT_Y + 0.2, -2.5), (24, -11, 0, CAT_Y + 0.2, 2.5),
        (37, -6, -4.5, CAT_Y + 0.2, 0), (37, -30, -4.5, CAT_Y + 0.2, 0),
        (-22, 17, 0, 7.2, -8), (-61, 8, 1, 4.6, -5)]
for k, (x, z, tx, ty, tz) in enumerate(pads):
    node("Pads", "Pad%d" % k, "pad", x, 0, z, "target = Vector3(%g, %g, %g)\n" % (tx, ty, tz))
# Over the walls, floor to floor, to get about without opening a gate (the bots ride them too:
# monsters behind a gate can only be reached this way).
# (each arc's top right over the wall)
over = [("FurnaceToHall", 40, -11, 20, -13), ("HallToFurnace", 20, -19, 40, -17), ("FurnaceToBoilerYard", 38, -37, 22, -37), ("BoilerYardToFurnace", 22, -41, 38, -41),
        ("YardToHall", 16, -1, 16, -13), ("HallToYard", -6, -13, -6, -1), ("YardToScrap", -36, 18, -50, 14), ("ScrapToYard", -50, 26, -36, 26),
        ("HallToScrap", -36, -19, -50, -20), ("ScrapToHall", -50, -9, -36, -13)]
for name, x, z, x2, z2 in over:
    node("Pads", name, "pad", x, 0, z, "target = Vector3(%g, 0.2, %g)\narc_height = 14.0\n" % (x2 - x, z2 - z))

# --- Lights: glows that say where you are -------------------------------------------------------
lamps = [("wall_lamp", -10, 3.2, -35.2, "Color(1, 0.82, 0.55, 1)"), ("wall_lamp", 2, 3.2, -35.2, "Color(1, 0.82, 0.55, 1)"), ("wall_lamp", 14, 3.2, -35.2, "Color(1, 0.82, 0.55, 1)"),
         ("lamp_post", -24, 0, -41, "Color(1, 0.82, 0.55, 1)"), ("lamp_post", 8, 0, 34, "Color(1, 0.82, 0.55, 1)"), ("lamp_post", 50, 0, 20, "Color(1, 0.82, 0.55, 1)"),
         ("bulb", -30, 8, -15.5, "Color(1, 0.86, 0.65, 1)", 2.2), ("bulb", -8, 8, -15.5, "Color(1, 0.86, 0.65, 1)", 2.2), ("bulb", 14, 8, -15.5, "Color(1, 0.86, 0.65, 1)", 2.2),
         ("bulb", 45, 4.5, -36, "Color(1, 0.6, 0.3, 1)"), ("bulb", 45, 4.5, -6, "Color(1, 0.6, 0.3, 1)")]
for k, lamp in enumerate(lamps):
    kind, x, y, z, col = lamp[:5]
    energy = "energy = %g\nreach = 22.0\n" % lamp[5] if len(lamp) > 5 else ""
    node("Lights", "Lamp%d" % k, "light", x, y, z, 'kind = "%s"\ncolor = %s\n%s' % (kind, col, energy))

# --- Props: things to drop off the catwalks, throw, push folk into the canal with ---------------
props = []
for x in (-34, -18, -2, 16):
    props.append(("boom_barrel", x, CAT_Y + 0.7, -22))
    props.append(("crate", x + 8, CAT_Y + 0.6, -9))
props += [("anvil", -8, CAT_Y + 0.3, -22), ("anvil", 22, CAT_Y + 0.3, -9), ("boom_barrel", 40, CAT_Y + 0.7, -22), ("boom_barrel", 32.5, CAT_Y + 0.7, -36), ("crate", 32.5, CAT_Y + 0.6, -6)]
for (x, z) in ((-38, -21.5), (26, -9.5), (-20, -11), (40, -46), (37, -13), (64, -18)):
    props.append(("crate", x, 0.6, z))
    props.append(("barrel", x + 1.5, 0.7, z))
for (x, z) in ((-6, 22), (10, 28), (26, 17), (46, 30), (62, 22), (-34, 26)):
    props.append(("crate", x, 0.6, z))
    props.append(("boom_barrel", x + 1.6, 0.7, z + 0.5))
for (x, z) in ((-62, -32), (-54, -14), (-70, 2), (-52, 8), (-48, -26), (-66, 18)):
    props.append(("tire", x, 0.5, z))
    props.append(("plank", x + 1.5, 0.3, z + 1))
    props.append(("crate_big", x - 2, 0.9, z - 1))
for (x, z) in ((-30, -50), (-18, -30), (24, -36), (14, -32.5)):
    props.append(("barrel", x, 0.7, z))
props += [("couch", 52.5, 0.5, 12), ("cone", 2, 0.4, 35), ("cone", 4.5, 0.4, 35)]
# Two iron balls (team lift), off the ways.
props += [("iron_ball", 28, 1.2, 12), ("iron_ball", 50, 1.2, -47)]
for k, (kind, x, y, z) in enumerate(props):
    node("Props", "Prop%d" % k, "prop", x, y, z, 'kind = "%s"\n' % kind)

open("maps/foundry.tscn", "w", encoding="utf-8", newline="\n").write("\n".join(out))
print(len(props), "props,", n["i"], "blocks")
