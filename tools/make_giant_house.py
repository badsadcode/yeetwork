"""Writes Grandma's Glasses, the giant-house adventure (docs/design/GIANT_HOUSE.md), so far its study:
adventures/grandmas_glasses.adventure.tres, the map adventures/grandmas_glasses/study.tscn, placeholder
models in .../models/ (plain scenes: swap in your own) and the monsters and things to throw in
.../types/. Everything's 20 times real size; every route stays within a Yeet's reach: rises of
1.2 m at most, gaps of 5 m at most. Plain Map Kit afterwards (rerunning this overwrites it).
    python tools/make_giant_house.py
"""
import math
import os
import random

ROOT = "adventures/grandmas_glasses"
RES = "res://" + ROOT
rng = random.Random(7)

WALL = (0.72, 0.66, 0.55)
SKIRTING = (0.93, 0.91, 0.86)
FLOORBOARD = (0.48, 0.33, 0.21)
WOOD = (0.42, 0.26, 0.15)
DESK = (0.33, 0.19, 0.11)
DOOR = (0.56, 0.38, 0.24)
RUG = (0.55, 0.13, 0.16)
BOOKS = [(0.55, 0.14, 0.13), (0.13, 0.27, 0.45), (0.15, 0.38, 0.24), (0.62, 0.47, 0.16), (0.33, 0.16, 0.38), (0.72, 0.68, 0.58), (0.2, 0.2, 0.22)]


def col(c):
    return "Color(%g, %g, %g, 1)" % c


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8", newline="\n").write(text)


# --- Placeholder models: plain scenes of boxes and balls -----------------------------------------

def model(path, parts, extra_subs="", extra_nodes=""):
    """parts: (name, parent, kind, size, position, colour[, glow, scale])"""
    subs = []
    nodes = ['[node name="Model" type="Node3D"]\n']
    for i, p in enumerate(parts):
        name, parent, kind, size, at, c = p[:6]
        glow = len(p) > 6 and p[6]
        scale = p[7] if len(p) > 7 else (1, 1, 1)
        if kind is None:
            nodes.append('[node name="%s" type="Node3D" parent="%s"]\ntransform = Transform3D(%g, 0, 0, 0, %g, 0, 0, 0, %g, %g, %g, %g)\n' % (name, parent, scale[0], scale[1], scale[2], at[0], at[1], at[2]))
            continue
        mat = 'albedo_color = %s\nroughness = 0.8\n' % col(c)
        if glow:
            mat += 'emission_enabled = true\nemission = %s\nemission_energy_multiplier = 1.5\n' % col(c)
        subs.append('[sub_resource type="StandardMaterial3D" id="m%d"]\n%s' % (i, mat))
        if kind == "box":
            subs.append('[sub_resource type="BoxMesh" id="s%d"]\nsize = Vector3(%g, %g, %g)\nmaterial = SubResource("m%d")\n' % (i, size[0], size[1], size[2], i))
        elif kind == "ball":
            subs.append('[sub_resource type="SphereMesh" id="s%d"]\nradius = %g\nheight = %g\nradial_segments = 8\nrings = 5\nmaterial = SubResource("m%d")\n' % (i, size, size * 2, i))
        else:  # cylinder: top radius, bottom radius, height
            subs.append('[sub_resource type="CylinderMesh" id="s%d"]\ntop_radius = %g\nbottom_radius = %g\nheight = %g\nradial_segments = 12\nmaterial = SubResource("m%d")\n' % (i, size[0], size[1], size[2], i))
        nodes.append('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = Transform3D(%g, 0, 0, 0, %g, 0, 0, 0, %g, %g, %g, %g)\nmesh = SubResource("s%d")\n' % (name, parent, scale[0], scale[1], scale[2], at[0], at[1], at[2], i))
    write(path, "[gd_scene format=3]\n\n" + "\n".join(subs) + extra_subs + "\n" + "\n".join(nodes) + extra_nodes)


def falling_book():
    """A huge book standing on the shelf's lip: it topples forward (+Z) about its bottom front edge, onto
    the desk. 6 wide, 9 tall, 1 thick: lying down, its top's 1 m over the shelf: a step up."""
    book_at = (0, 4.5, -0.5)
    size = (6, 9, 1)
    keys = []
    for t, deg in ((0.0, 0), (0.5, 12), (0.85, 42), (1.1, 90), (1.25, 85), (1.4, 90)):
        a = math.radians(deg) * 0.5
        keys += [t, 1, math.sin(a), 0, 0, math.cos(a)]
    anim = '''
[sub_resource type="Animation" id="fall"]
resource_name = "fall"
length = 1.4
tracks/0/type = "rotation_3d"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Pivot")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = PackedFloat32Array(%s)

[sub_resource type="AnimationLibrary" id="lib"]
_data = {
&"fall": SubResource("fall")
}
''' % ", ".join("%g" % k for k in keys)
    parts = [
        ("Pivot", ".", None, None, (0, 0, 0), None),
        ("Book", "Pivot", "box", size, book_at, (0.45, 0.1, 0.12)),
        ("Spine", "Pivot/Book", "box", (0.3, 8.0, 1.04), (2.6, 0, 0), (0.75, 0.62, 0.25)),
        ("CollisionBook", "Pivot", "box", size, book_at, (1, 1, 1)),
    ]
    model(ROOT + "/models/falling_book.tscn", parts, anim, '''
[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {
&"": SubResource("lib")
}
''')


def dust_bunny():
    """Parts as MonsterType wants them; about a metre tall (MonsterType's Size scales it)."""
    grey = (0.56, 0.54, 0.53)
    dark = (0.4, 0.38, 0.38)
    parts = [
        ("Torso", ".", "ball", 0.36, (0, 0.46, 0), grey),
        ("Torso_fluff1", "Torso", "ball", 0.2, (0.26, 0.1, 0.1), dark),
        ("Torso_fluff2", "Torso", "ball", 0.2, (-0.26, 0.04, 0.12), dark),
        ("Torso_fluff3", "Torso", "ball", 0.2, (0.1, -0.1, 0.28), grey),
        ("Head", ".", "ball", 0.27, (0, 0.82, -0.08), grey),
        ("Head_ear1", "Head", "ball", 0.08, (-0.13, 0.32, 0.02), dark, False, (1, 3, 1)),
        ("Head_ear2", "Head", "ball", 0.08, (0.13, 0.32, 0.02), dark, False, (1, 3, 1)),
        ("Head_eye1", "Head", "ball", 0.07, (-0.11, 0.06, -0.23), (0.95, 0.9, 0.5), True),
        ("Head_eye2", "Head", "ball", 0.07, (0.11, 0.06, -0.23), (0.95, 0.9, 0.5), True),
        ("Leg_L", ".", "ball", 0.13, (-0.17, 0.14, 0), dark),
        ("Leg_R", ".", "ball", 0.13, (0.17, 0.14, 0), dark),
        ("Arm_L", ".", "ball", 0.1, (-0.36, 0.55, -0.08), dark),
        ("Arm_R", ".", "ball", 0.1, (0.36, 0.55, -0.08), dark),
    ]
    model(ROOT + "/models/dust_bunny.tscn", parts)


def small_models():
    model(ROOT + "/models/thimble.tscn", [("Thimble", ".", "cyl", (0.17, 0.21, 0.45), (0, 0, 0), (0.75, 0.75, 0.78))])
    pips = [("Domino", ".", "box", (1.0, 0.5, 0.22), (0, 0, 0), (0.08, 0.08, 0.09)), ("Line", "Domino", "box", (0.04, 0.42, 0.24), (0, 0, 0), (0.9, 0.9, 0.85))]
    for i, (x, y) in enumerate(((-0.32, 0.13), (-0.32, -0.13), (-0.14, 0.0), (0.2, 0.13), (0.34, -0.13))):
        pips.append(("Pip%d" % i, "Domino", "box", (0.07, 0.07, 0.24), (x, y, 0), (0.9, 0.9, 0.85)))
    model(ROOT + "/models/domino.tscn", pips)
    model(ROOT + "/models/sugar_cube.tscn", [("Sugar", ".", "box", (0.34, 0.34, 0.34), (0, 0, 0), (0.96, 0.95, 0.92))])
    model(ROOT + "/models/matchbox.tscn", [
        ("Box", ".", "box", (1.1, 0.45, 0.75), (0, 0, 0), (0.15, 0.3, 0.6)),
        ("Label", "Box", "box", (0.6, 0.02, 0.45), (0, 0.23, 0), (0.9, 0.75, 0.2)),
        ("Tray", "Box", "box", (0.3, 0.38, 0.68), (0.62, 0, 0), (0.82, 0.74, 0.55)),
    ])
    model(ROOT + "/models/ribbon.tscn", [("Ribbon", ".", "box", (1.1, 7.6, 0.08), (0, 3.8, 0), (0.75, 0.12, 0.15))])
    model(ROOT + "/models/diary.tscn", [
        ("Cover", ".", "box", (4.0, 0.5, 3.0), (0, 0.25, 0), (0.3, 0.16, 0.08)),
        ("Pages", "Cover", "box", (3.8, 0.4, 2.8), (0.12, 0, 0), (0.92, 0.88, 0.76)),
        ("Clasp", "Cover", "box", (0.5, 0.1, 0.5), (-1.9, 0.26, 0), (0.8, 0.65, 0.2)),
    ])


# --- The monsters and things to throw ------------------------------------------------------------

def monster_type(file, name, like, hp, size, speed, announce):
    write("%s/types/%s.tres" % (ROOT, file), '''[gd_resource type="Resource" script_class="MonsterType" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/horde/monster_type.gd" id="type"]
[ext_resource type="PackedScene" path="%s/models/dust_bunny.tscn" id="model"]

[resource]
script = ExtResource("type")
display_name = "%s"
behaves_like = "%s"
model = ExtResource("model")
hit_points = %g
speed = %g
size = %g
remains = "dust"
announce = "%s"
''' % (RES, name, like, hp, speed, size, announce))


def prop_type(file, name, shape, size, mass):
    write("%s/types/%s.tres" % (ROOT, file), '''[gd_resource type="Resource" script_class="PropType" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/props/prop_type.gd" id="type"]
[ext_resource type="PackedScene" path="%s/models/%s.tscn" id="model"]

[resource]
script = ExtResource("type")
display_name = "%s"
behaves_like = "crate"
model = ExtResource("model")
size = Vector3(%g, %g, %g)
shape = "%s"
mass = %g
unbreakable = true
''' % (RES, file, name, size[0], size[1], size[2], shape, mass))


# --- The study ----------------------------------------------------------------------------------

SCRIPTS = [("settings", "map_settings"), ("block", "arena_block"), ("spawn", "spawn_point"), ("prop", "prop_spawn"), ("plate", "pressure_plate"),
           ("door", "puzzle_door"), ("exit", "puzzle_exit"), ("note", "story_note"), ("line", "story_line"), ("zone", "story_zone"), ("flag", "story_flag"),
           ("talker", "talking_yeet"), ("encounter", "encounter"), ("checkpoint", "checkpoint"), ("rift", "monster_spawn"), ("ladder", "ladder"),
           ("animated", "animated_model"), ("light", "map_light")]
nodes = []
_names = {}


def uniq(name):
    _names[name] = _names.get(name, 0) + 1
    return name if _names[name] == 1 else "%s%d" % (name, _names[name])


def piece(name, script, x, y, z, body=""):
    nodes.append('[node name="%s" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)\nscript = ExtResource("%s")\n%s\n' % (name, x, y, z, script, body))


def box(name, x0, x1, y0, y1, z0, z1, c, shadow=True):
    nodes.append('[node name="%s" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)\nscript = ExtResource("block")\nsize = Vector3(%g, %g, %g)\ncolor = %s\n%s' % (uniq(name), (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, col(c), "" if shadow else "casts_shadow = false\n"))


def marker(name, x, y, z, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    nodes.append('[node name="%s" type="Marker3D" parent="."]\ntransform = Transform3D(%g, 0, %g, 0, 1, 0, %g, 0, %g, %g, %g, %g)\n' % (name, c, s, -s, c, x, y, z))


def prop(name, x, y, z, ptype, extra=""):
    piece(uniq(name), "prop", x, y, z, 'kind = "crate"\ntype = ExtResource("%s")\n%s' % (ptype, extra))


def row_of_books(x0, x1, y, z0, z1, top):
    """Standing books along a shelf, none of them higher than top."""
    x = x0
    while x < x1 - 1.0:
        thick = rng.uniform(1.3, 2.5)
        if rng.random() > 0.08:  # (now and then a gap)
            high = rng.uniform(max(3.5, top * 0.6), top)
            box("Book", x, min(x + thick, x1), y, y + high, z0 + rng.uniform(0, 0.4), z1, rng.choice(BOOKS))
        x += thick


def inp(*names):
    return "inputs = Array[NodePath]([%s])\n" % ", ".join('NodePath("../%s")' % n for n in names)


def line(name, speaker, text, voice, *after, delay=0.0):
    piece(name, "line", 0, 0, 0, 'speaker = "%s"\ntext = "%s"\nvoice = "%s"\n%s%s' % (speaker, text, voice, "delay = %g\n" % delay if delay else "", inp(*after)))


def study():
    nodes.append('[node name="TheStudy" type="Node3D"]\n')
    nodes.append('[node name="MapSettings" type="Node" parent="."]\nscript = ExtResource("settings")\nmap_name = "The Study"\nauthor = "Yeetwork"\ndescription = "Grandma\'s Glasses: up the bookcase, across to the desk."\nsky = "day"\npuzzle = true\nkill_height = -20.0\nambient_scale = 1.3\n')
    # The room: 80 by 60, 50 high.
    box("Floor", -42, 42, -1, 0, -32, 42, FLOORBOARD)
    box("Ceiling", -42, 42, 50, 52, -32, 32, (0.88, 0.86, 0.8), shadow=False)
    box("WallNorth", -42, 42, 0, 50, -32, -30, WALL, shadow=False)
    box("WallEast", 40, 42, 0, 50, -30, 30, WALL, shadow=False)
    # The west wall has a window in it.
    box("WallWest", -42, -40, 0, 14, -30, 30, WALL, shadow=False)
    box("WallWest", -42, -40, 40, 50, -30, 30, WALL, shadow=False)
    box("WallWest", -42, -40, 14, 40, -30, -14, WALL, shadow=False)
    box("WallWest", -42, -40, 14, 40, 14, 30, WALL, shadow=False)
    box("WindowSill", -42, -38.5, 13.4, 14, -15, 15, SKIRTING, shadow=False)
    box("WindowBar", -41.2, -40.8, 14, 40, -0.4, 0.4, SKIRTING, shadow=False)
    box("WindowBar", -41.2, -40.8, 26.6, 27.4, -14, 14, SKIRTING, shadow=False)
    box("Curtain", -40, -38.5, 12, 44, -20, -13, (0.5, 0.2, 0.22), shadow=False)
    box("Curtain", -40, -38.5, 12, 44, 13, 20, (0.5, 0.2, 0.22), shadow=False)
    # The south wall: the door you come in under, and a mouse hole.
    box("WallSouth", -42, -30, 0, 50, 30, 32, WALL, shadow=False)
    box("WallSouth", -14, 22, 0, 50, 30, 32, WALL, shadow=False)
    box("WallSouth", 28, 42, 0, 50, 30, 32, WALL, shadow=False)
    box("WallSouth", -30, -14, 40, 50, 30, 32, WALL, shadow=False)
    box("WallSouth", 22, 28, 4, 50, 30, 32, WALL, shadow=False)
    box("TheDoor", -30, -14, 3, 40, 29.6, 32, DOOR, shadow=False)
    box("DoorHandle", -16.5, -15, 19, 20, 28.4, 29.6, (0.8, 0.65, 0.25))
    # (the crack under the door, and the way behind the mouse hole)
    box("UnderDoorWest", -32, -30, 0, 3, 32, 42, WOOD, shadow=False)
    box("UnderDoorEast", -14, -12, 0, 3, 32, 42, WOOD, shadow=False)
    box("UnderDoorBack", -32, -12, 0, 3, 40, 42, WOOD, shadow=False)
    box("UnderDoorTop", -32, -12, 3, 4, 32, 42, WOOD, shadow=False)
    box("MouseWayWest", 20, 22, 0, 4, 32, 40, (0.2, 0.15, 0.12), shadow=False)
    box("MouseWayEast", 28, 30, 0, 4, 32, 40, (0.2, 0.15, 0.12), shadow=False)
    box("MouseWayBack", 20, 30, 0, 4, 38, 40, (0.2, 0.15, 0.12), shadow=False)
    box("MouseWayTop", 20, 30, 4, 5, 32, 40, (0.2, 0.15, 0.12), shadow=False)
    # Skirting boards: how a Yeet knows how big the wall is.
    box("Skirting", -40, 40, 0, 2, -30, -29.5, SKIRTING)
    box("Skirting", 39.5, 40, 0, 2, -30, 30, SKIRTING)
    box("Skirting", -40, -39.5, 0, 2, -30, 30, SKIRTING)
    box("Skirting", -40, -30, 0, 2, 29.5, 30, SKIRTING)
    box("Skirting", -14, 22, 0, 2, 29.5, 30, SKIRTING)
    box("Skirting", 28, 40, 0, 2, 29.5, 30, SKIRTING)
    box("WallSocket", 30, 34, 6, 12, 29.3, 30, SKIRTING)
    box("WallClock", -4, 8, 34, 46, 29.3, 30, (0.25, 0.2, 0.15))
    box("WallClockFace", -3, 7, 35, 45, 28.9, 29.3, (0.92, 0.9, 0.84))
    # On the floor: the rug, a slipper, an armchair's foot, a wastepaper bin.
    box("Rug", -28, 6, 0, 0.25, 4, 26, RUG)
    box("RugPattern", -24, 2, 0.25, 0.3, 8, 22, (0.72, 0.56, 0.3))
    box("Slipper", -8, -2, 0.25, 1.4, 12, 15, (0.5, 0.25, 0.45))
    box("ChairSeat", 26, 40, 9, 12, 2, 22, (0.3, 0.42, 0.34))
    box("ChairBack", 37, 40, 12, 26, 2, 22, (0.3, 0.42, 0.34))
    box("ChairLeg", 26, 28, 0, 9, 2, 4, WOOD)
    box("ChairLeg", 26, 28, 0, 9, 20, 22, WOOD)
    box("ChairLeg", 38, 40, 0, 9, 2, 4, WOOD)
    box("ChairLeg", 38, 40, 0, 9, 20, 22, WOOD)
    box("WastepaperBin", -38, -30, 0, 7, 8, 16, (0.25, 0.27, 0.3))
    # The bookcase, along the north wall: a cupboard base you can stand on, shelves above.
    box("CaseBase", -31, 11, 0, 8, -30, -22, WOOD)
    box("CaseSideWest", -31, -30, 8, 30, -30, -24, WOOD)
    box("CaseSideEast", 10, 11, 8, 30, -30, -24, WOOD)
    box("CaseShelfTwo", -30, 10, 14.4, 15, -30, -24, WOOD)
    box("CaseShelfThree", -30, 10, 24.4, 25, -30, -24, WOOD)
    box("CaseTop", -31, 11, 29.4, 30, -30, -24, WOOD)
    row_of_books(-30, 10, 8, -30, -26.5, 6.0)  # (first shelf)
    row_of_books(-30, 10, 15, -30, -28, 9.0)  # (second: a narrower row, it's the one you walk along)
    row_of_books(-30, 10, 25, -30, -24.5, 4.2)  # (third, out of reach)
    # Up to the first shelf: stacks of lying books, a stack a step, 1.1 m a step.
    for step in range(7):
        x0 = -37.5 + step * 3.0
        for k in range(step + 1):
            inset = rng.uniform(0.0, 0.15)
            box("Stairs", x0 + inset, x0 + 3.0, k * 1.1, (k + 1) * 1.1, -22, -16 - inset, rng.choice(BOOKS))
    # The desk, in front of the bookcase; the gap between is what the big book's for.
    box("DeskTop", -6, 24, 14, 15, -17, 3, DESK)
    box("DeskLeg", -6, -4, 0, 14, -17, -15, DESK)
    box("DeskLeg", -6, -4, 0, 14, 1, 3, DESK)
    box("DeskDrawers", 16, 24, 0, 14, -17, 3, DESK)
    # On it: a lamp, a pencil, a sheet of paper, a mug, her diary.
    box("LampBase", 16, 21, 15, 15.5, -14, -9, (0.2, 0.35, 0.25))
    box("LampStem", 18.2, 18.8, 15.5, 22, -11.8, -11.2, (0.75, 0.65, 0.3))
    box("LampShade", 15.5, 21.5, 22, 25, -14.5, -8.5, (0.2, 0.4, 0.28))
    piece("LampLight", "light", 18.5, 21.5, -11.5, 'kind = "bulb"\ncolor = Color(1, 0.86, 0.6, 1)\nenergy = 2.0\nreach = 26.0\nbreakable = false\n')
    box("Pencil", -2, 1.6, 15, 15.4, -10, -9.6, (0.9, 0.7, 0.15))
    box("Paper", 2, 8, 15, 15.05, -3, 1.2, (0.93, 0.92, 0.88))
    box("Mug", 11, 12.8, 15, 17, -5, -3.2, (0.82, 0.35, 0.25))
    piece("CeilingLight", "light", -6, 46, 2, 'kind = "bulb"\ncolor = Color(1, 0.93, 0.82, 1)\nenergy = 2.5\nreach = 70.0\nbreakable = false\n')
    # Where you come in.
    for k, x in enumerate((-27, -24, -20, -17)):
        piece("Spawn%d" % k, "spawn", x, 0, 36)
    marker("ViewFloor", -22, 0.3, 24, 0.0)
    marker("ViewShelf", -14, 15.3, -26, -1.57)
    marker("ViewDesk", 10, 15.3, 0, 0.6)
    # On the floor: the job.
    piece("Mabel", "talker", -26, 0, 22, 'display_name = "Mabel"\nlines = PackedStringArray("Oh good, the Yeets. I\'m Mabel. I do odd jobs round here. They\'re all odd.", "She\'s lost her glasses again, and she can\'t see a thing without them. She wrote to you herself. Well, she wrote to the toaster, but it got passed on.", "Her diary\'s on the desk. Up there. No, higher. Higher. There.", "You\'ll want the bookcase. The books at the far end make a good stair. And mind the dust. It bites.")\nshirt = Color(0.75, 0.3, 0.45, 1)\n')
    piece("TheLetter", "note", -20, 0, 20, 'title = "A Letter"\ntext = "To the small people, or the toaster,\\n\\nI seem to have put my glasses down somewhere. Could you find them? I would look myself, but I can\'t see where to start.\\n\\nThere\'s a biscuit in it for you.\\n\\nYours, Grandma\\n\\nP.S. Is that you, Harold?"\n')
    for k, (x, z) in enumerate(((-13, 21), (-11, 19))):
        prop("FloorSugar", x, 0.5, z, "sugar_cube")
    prop("FloorThimble", -16, 0.5, 16, "thimble")
    # The voice from above.
    piece("IntoTheRoom", "zone", -22, 0, 25, "size = Vector3(20, 4, 8)\n")
    line("VoiceOne", "A VOICE", "Is somebody there? Speak up, dear.", "tired", "IntoTheRoom", delay=1.0)
    line("VoiceTwo", "A VOICE", "Oh, it's only you, Harold. You've got very thin.", "tired", "VoiceOne", delay=0.5)
    line("MabelOne", "Mabel", "She's talking to the lamp.", "talk", "VoiceTwo")
    line("VoiceThree", "A VOICE", "And you never did fix that shade.", "tired", "MabelOne", delay=0.3)
    # Up the bookcase: the ribbon hangs from a big book on the second shelf.
    box("RibbonBook", -28, -24, 8, 14.4, -25.2, -24.2, BOOKS[0])
    nodes.append('[node name="Ribbon" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -26, 8, -24.1)\nscript = ExtResource("ladder")\nheight = 7.6\nover_the_top = 5.0\nmodel = ExtResource("ribbon")\n')
    # Reaching the second shelf is the first objective, and the fight's checkpoint.
    piece("UpTheShelf", "checkpoint", -21.5, 15, -26, 'radius = 1.9\nobjective = "Climb the bookcase"\n')
    prop("Matchbox", -18.5, 15.6, -26, "matchbox", "key_prop = true\n")
    # The fight.
    piece("TheyWake", "zone", -13, 15, -26, "size = Vector3(4, 4, 6)\n")
    line("VoiceDust", "A VOICE", "I do keep meaning to dust those shelves.", "tired", "TheyWake")
    piece("RiftWest", "rift", -5, 15, -26, "radius = 1.2\n")
    piece("RiftEast", "rift", 8, 15, -26.5, "radius = 1.0\n")
    piece("TheDust", "encounter", -3, 15, -26, 'waves = Array[ExtResource("wave")]([SubResource("waveOne"), SubResource("waveTwo")])\nrifts = Array[NodePath]([NodePath("../RiftWest"), NodePath("../RiftEast")])\ninputs = Array[NodePath]([NodePath("../TheyWake")])\nmax_at_once = 20\nrespawn_after = 10.0\nrestart_after = 4.0\nobjective = "Clear out the dust bunnies"\n')
    line("VoiceSneeze", "A VOICE", "Bless you. Was that you, Harold?", "tired", "TheDust", delay=1.0)
    for k, x in enumerate((-11, -8)):
        prop("ShelfDomino", x, 15.5, -25.5, "domino")
    prop("ShelfThimble", -10, 15.5, -27, "thimble")
    prop("ShelfThimble", -1.5, 15.5, -27.2, "thimble")
    prop("ShelfSugar", -7, 15.4, -27.3, "sugar_cube")
    # The bridge: weigh the plate down, once the dust's gone, and the big book topples to the desk.
    piece("LoosePlate", "plate", 0, 15, -26, 'required_mass = 20.0\nlatch = true\nobjective = "Weigh down the plate with something heavy"\n')
    piece("BigBook", "animated", 6, 15, -24, 'model = ExtResource("falling_book")\nplay = "once"\nlatch = true\n' + inp("TheDust", "LoosePlate"))
    line("VoiceBook", "A VOICE", "Harold! Stop throwing my books about.", "excited", "BigBook", delay=1.4)
    # The desk.
    piece("HerDiary", "note", 8, 15, -9, 'title = "Her Diary"\ntext = "Tuesday. Lost my glasses. Looked everywhere I could see, which wasn\'t far.\\n\\nWednesday. Buttered something at breakfast. It may have been the cat.\\n\\nThursday. I\'m sure I had them on in the KITCHEN. Or the kitchen had them on. Someone should go and look."\nmodel = ExtResource("diary")\nobjective = "Read her diary, on the desk"\n')
    piece("KnowsTheKitchen", "flag", 8, 15, -9, 'flag = "read_the_diary"\n' + inp("HerDiary"))
    line("MabelKitchen", "Mabel (from very far below)", "The kitchen! Jump down, you'll be fine, and out by the mouse hole! I've opened it!", "excited", "HerDiary", delay=0.5)
    # The way on.
    piece("MouseDoor", "door", 25, 0, 30.5, 'size = Vector3(6, 4, 1)\nopen_offset = Vector3(0, 3.9, 0)\ncolor = Color(0.35, 0.27, 0.2, 1)\n' + inp("HerDiary"))
    piece("Exit", "exit", 25, 0, 35, 'objective = "Out through the mouse hole"\n')

    ext = ['[gd_scene format=3]\n']
    for i, f in SCRIPTS:
        ext.append('[ext_resource type="Script" path="res://scripts/mapkit/%s.gd" id="%s"]' % (f, i))
    ext.append('[ext_resource type="Script" path="res://scripts/mapkit/encounter_wave.gd" id="wave"]')
    ext.append('[ext_resource type="Script" path="res://scripts/horde/monster_type.gd" id="monster"]')
    for f in ("sugar_cube", "thimble", "domino", "matchbox", "dust_bunny_type", "big_dust_bunny_type"):
        name = f.replace("_type", "")
        ext.append('[ext_resource type="Resource" path="%s/types/%s.tres" id="%s"]' % (RES, name, f))
    for f in ("ribbon", "falling_book", "diary"):
        ext.append('[ext_resource type="PackedScene" path="%s/models/%s.tscn" id="%s"]' % (RES, f, f))
    subs = '''
[sub_resource type="Resource" id="waveOne"]
script = ExtResource("wave")
own_monsters = Array[ExtResource("monster")]([ExtResource("dust_bunny_type")])
own_count = 8
spawn_gap = 0.4

[sub_resource type="Resource" id="waveTwo"]
script = ExtResource("wave")
own_monsters = Array[ExtResource("monster")]([ExtResource("dust_bunny_type"), ExtResource("big_dust_bunny_type")])
own_count = 3
spawn_gap = 0.5
'''
    write(ROOT + "/study.tscn", "\n".join(ext) + "\n" + subs + "\n" + "\n".join(nodes))


falling_book()
dust_bunny()
small_models()
monster_type("dust_bunny", "Dust Bunny", "runner", 14, 0.75, 3.2, "DUST BUNNIES!  Mind the edge")
monster_type("big_dust_bunny", "Big Dust Bunny", "shambler", 70, 1.5, 1.8, "A BIG ONE!  Years under there")
prop_type("thimble", "Thimble", "cylinder", (0.42, 0.45, 0.42), 8)
prop_type("domino", "Domino", "box", (1.0, 0.5, 0.22), 10)
prop_type("sugar_cube", "Sugar Cube", "box", (0.34, 0.34, 0.34), 2)
prop_type("matchbox", "Matchbox", "box", (1.1, 0.45, 0.75), 25)
study()
write("adventures/grandmas_glasses.adventure.tres", '''[gd_resource type="Resource" script_class="Adventure" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/mapkit/adventure.gd" id="adventure"]
[ext_resource type="Script" path="res://scripts/mapkit/adventure_chapter.gd" id="chapter"]

[sub_resource type="Resource" id="study"]
script = ExtResource("chapter")
map = "%s/study.tscn"
title = "The Study"
intro = "She's lost her glasses. She's also mistaken the lamp for her husband. You'd better find them."

[resource]
script = ExtResource("adventure")
display_name = "Grandma's Glasses"
description = "A very large old lady has lost her glasses in a very large house. So far: the study."
chapters = Array[ExtResource("chapter")]([SubResource("study")])
''' % RES)
print("wrote adventures/grandmas_glasses.adventure.tres, %s/study.tscn (%d pieces), models and types" % (ROOT, len(nodes)))
