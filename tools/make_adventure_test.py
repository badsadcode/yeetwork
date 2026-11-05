"""Writes the Adventure mode's tiny test adventures, for showing how one's put together and for
the checks to play through. Plain Map Kit afterwards (rerunning this overwrites them).
Two Small Rooms (adventures/two_small_rooms.adventure.tres, its maps in adventures/two_small_rooms/):
a button that opens the way to an exit; then a plate a crate holds down.
The Cellar (adventures/the_cellar.adventure.tres and adventures/the_cellar/cellar.tscn): two fights
(Encounter): monsters hunting the Yeets through two waves; then a boss and monsters of the map's
own, let out of a cage, heading for a spot.
    python tools/make_adventure_test.py
"""
import os

OUT = "adventures/two_small_rooms"
EXT = [("settings", "map_settings"), ("block", "arena_block"), ("spawn", "spawn_point"), ("prop", "prop_spawn"), ("button", "puzzle_button"),
       ("plate", "pressure_plate"), ("door", "puzzle_door"), ("exit", "puzzle_exit"),
       ("note", "story_note"), ("line", "story_line"), ("zone", "story_zone"), ("flag", "story_flag"), ("talker", "talking_yeet")]
FLOOR = "Color(0.52, 0.5, 0.48, 1)"
WALL = "Color(0.45, 0.5, 0.62, 1)"


def room(name, description, pieces):
    out = ['[gd_scene format=3]\n']
    for i, f in EXT:
        out.append('[ext_resource type="Script" path="res://scripts/mapkit/%s.gd" id="%s"]' % (f, i))
    out.append('\n[node name="%s" type="Node3D"]\n' % name.replace(" ", ""))
    out.append('[node name="MapSettings" type="Node" parent="."]\nscript = ExtResource("settings")\nmap_name = "%s"\nauthor = "Yeetwork"\ndescription = "%s"\nsky = "day"\npuzzle = true\nkill_height = -20.0\n' % (name, description))

    def block(n, x, y, z, sx, sy, sz, color):
        out.append('[node name="%s" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)\nscript = ExtResource("block")\nsize = Vector3(%g, %g, %g)\ncolor = %s\n' % (n, x, y, z, sx, sy, sz, color))

    block("Floor", 0, -0.5, 0, 26, 1, 16, FLOOR)
    block("WallNorth", 0, 2.5, -8.25, 26, 5, 0.5, WALL)
    block("WallSouth", 0, 2.5, 8.25, 26, 5, 0.5, WALL)
    block("WallWest", -13.25, 2.5, 0, 0.5, 5, 16, WALL)
    block("WallEast", 13.25, 2.5, 0, 0.5, 5, 16, WALL)
    # The dividing wall, a door's gap in it.
    block("DividerNorth", 4, 2.5, -5, 0.5, 5, 6, WALL)
    block("DividerSouth", 4, 2.5, 5, 0.5, 5, 6, WALL)
    block("DividerTop", 4, 4.5, 0, 0.5, 1, 4, WALL)
    for k, z in enumerate((-4.5, -1.5, 1.5, 4.5)):
        out.append('[node name="Spawn%d" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10, 0, %g)\nscript = ExtResource("spawn")\n' % (k, z))
    out.append(pieces)
    out.append('[node name="Exit" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10, 0, 0)\nscript = ExtResource("exit")\n')
    return "\n".join(out)


DOOR = '''[node name="Door" type="Node3D" parent="."]
transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 4, 0, 0)
script = ExtResource("door")
size = Vector3(4, 4, 0.5)
inputs = Array[NodePath]([NodePath("../%s")])
objective = "%s"
'''

PIECE = '[node name="%s" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, 0, %g)\nscript = ExtResource("%s")\n%s\n'
os.makedirs(OUT, exist_ok=True)
open(OUT + "/room1.tscn", "w", encoding="utf-8", newline="\n").write(room(
    "Two Small Rooms: the Button", "Press the button; through the door.",
    '[node name="Button" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -4)\nscript = ExtResource("button")\npress = "use key"\nlabel = "Open the door"\n\n'
    + PIECE % ("Note", -6, -6, "note", 'title = "A Note"\ntext = "Whoever finds this: DO NOT press the button.\\n\\nActually, do. Otherwise you\'re stuck in here."\n')
    + PIECE % ("Bob", -2, 4, "talker", 'display_name = "Bob"\nlines = PackedStringArray("Oh! Visitors. Nobody ever visits.", "The button? Over there. I would not know why.")\nshirt = Color(0.85, 0.45, 0.2, 1)\n')
    + PIECE % ("MetBob", -2, 6, "flag", 'flag = "met_bob"\ninputs = Array[NodePath]([NodePath("../Bob")])\n')
    + PIECE % ("NearDoor", 1.5, 0, "zone", 'size = Vector3(3, 3, 8)\n')
    + PIECE % ("DoorLine", 1.5, 0, "line", 'speaker = "Bob"\ntext = "Mind the door. It sticks."\nvoice = "excited"\ninputs = Array[NodePath]([NodePath("../NearDoor")])\n')
    + DOOR % ("Button", "Open the door")))
open(OUT + "/room2.tscn", "w", encoding="utf-8", newline="\n").write(room(
    "Two Small Rooms: the Plate", "Weigh the plate down; through the door.",
    '[node name="Plate" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1, 0, 4)\nscript = ExtResource("plate")\nrequired_mass = 20.0\n\n'
    '[node name="Crate" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7, 0.6, 0)\nscript = ExtResource("prop")\nkind = "crate"\nkey_prop = true\n\n'
    + PIECE % ("YouMetBob", -6, -6, "flag", 'flag = "met_bob"\naction = "check"\n')
    + PIECE % ("BobRemembers", -6, -6, "line", 'speaker = "A voice"\ntext = "Bob says hello. He says you were very polite."\nvoice = "tired"\ndelay = 1.0\ninputs = Array[NodePath]([NodePath("../YouMetBob")])\n')
    + DOOR % ("Plate", "Weigh the plate down")))
open("adventures/two_small_rooms.adventure.tres", "w", encoding="utf-8", newline="\n").write('''[gd_resource type="Resource" script_class="Adventure" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/mapkit/adventure.gd" id="adventure"]
[ext_resource type="Script" path="res://scripts/mapkit/adventure_chapter.gd" id="chapter"]

[sub_resource type="Resource" id="one"]
script = ExtResource("chapter")
map = "res://adventures/two_small_rooms/room1.tscn"
title = "The Button"
intro = "There's a button. It's probably fine."

[sub_resource type="Resource" id="two"]
script = ExtResource("chapter")
map = "res://adventures/two_small_rooms/room2.tscn"
title = "The Plate"
intro = "No button this time. Someone's taken it. There's a crate, though."

[resource]
script = ExtResource("adventure")
display_name = "Two Small Rooms (test)"
description = "The smallest adventure there is: it shows how one's put together."
chapters = Array[ExtResource("chapter")]([SubResource("one"), SubResource("two")])
''')


# --- The Cellar: three rooms in a row, west to east, a door between each.
CELLAR_EXT = EXT + [("encounter", "encounter"), ("checkpoint", "checkpoint")]


def node(name, kind, x, y, z, body="", basis="1, 0, 0, 0, 1, 0, 0, 0, 1"):
    return '[node name="%s" type="Node3D" parent="."]\ntransform = Transform3D(%s, %g, %g, %g)\nscript = ExtResource("%s")\n%s\n' % (name, basis, x, y, z, kind, body)


def marker(name, x, y, z):
    return '[node name="%s" type="Marker3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)\n' % (name, x, y, z)


def solid(n, x, y, z, sx, sy, sz, color):
    return '[node name="%s" type="StaticBody3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)\nscript = ExtResource("block")\nsize = Vector3(%g, %g, %g)\ncolor = %s\n' % (n, x, y, z, sx, sy, sz, color)


def cross_wall(n, x):
    # A wall across the cellar with a door's gap in it.
    return [solid(n + "North", x, 2.5, -5, 0.5, 5, 6, WALL), solid(n + "South", x, 2.5, 5, 0.5, 5, 6, WALL), solid(n + "Top", x, 4.5, 0, 0.5, 1, 4, WALL)]


CROSS_DOOR = "0, 0, 1, 0, 1, 0, -1, 0, 0"
cellar = ['[gd_scene format=3]\n']
for i, f in CELLAR_EXT:
    cellar.append('[ext_resource type="Script" path="res://scripts/mapkit/%s.gd" id="%s"]' % (f, i))
cellar.append('[ext_resource type="Script" path="res://scripts/mapkit/encounter_wave.gd" id="wave"]')
cellar.append('[ext_resource type="Script" path="res://scripts/horde/monster_type.gd" id="monster"]')
cellar.append('''
[sub_resource type="Resource" id="first"]
script = ExtResource("wave")
shamblers = 4
runners = 2

[sub_resource type="Resource" id="second"]
script = ExtResource("wave")
runners = 3
ghosts = 1
bombers = 1

[sub_resource type="Resource" id="bunny"]
script = ExtResource("monster")
display_name = "Dust Bunny"
behaves_like = "runner"
hit_points = 12.0
size = 0.6
announce = "DUST BUNNIES!  Small, and everywhere"

[sub_resource type="Resource" id="boss"]
script = ExtResource("wave")
boss = "ram"
boss_health = 600.0
own_monsters = Array[ExtResource("monster")]([SubResource("bunny")])
own_count = 4
''')
cellar.append('[node name="TheCellar" type="Node3D"]\n')
cellar.append('[node name="MapSettings" type="Node" parent="."]\nscript = ExtResource("settings")\nmap_name = "The Cellar"\nauthor = "Yeetwork"\ndescription = "Two fights, three rooms."\nsky = "day"\npuzzle = true\nkill_height = -20.0\n')
cellar.append(solid("Floor", 9, -0.5, 0, 44, 1, 16, FLOOR))
cellar.append(solid("WallNorth", 9, 2.5, -8.25, 44, 5, 0.5, WALL))
cellar.append(solid("WallSouth", 9, 2.5, 8.25, 44, 5, 0.5, WALL))
cellar.append(solid("WallWest", -13.25, 2.5, 0, 0.5, 5, 16, WALL))
cellar.append(solid("WallEast", 31.25, 2.5, 0, 0.5, 5, 16, WALL))
cellar += cross_wall("WallOne", 4) + cross_wall("WallTwo", 18)
# The cage, in the second room's north side: a wall with a door's gap, the rift behind it.
cellar.append(solid("CageWest", 8, 2.5, -4, 8, 5, 0.5, WALL))
cellar.append(solid("CageEast", 17, 2.5, -4, 2, 5, 0.5, WALL))
cellar.append(solid("CageTop", 14, 4.5, -4, 4, 1, 0.5, WALL))
for k, z in enumerate((-4.5, -1.5, 1.5, 4.5)):
    cellar.append(node("Spawn%d" % k, "spawn", -10, 0, z))
for k, (x, z) in enumerate(((-7, -6), (-7, 6), (-3, -6), (-3, 6), (1, -3))):
    cellar.append(node("Crate%d" % k, "prop", x, 0.6, z, 'kind = "crate"'))
for k, z in enumerate((-2, 2)):
    cellar.append(node("Barrel%d" % k, "prop", -5, 0.6, z, 'kind = "boom_barrel"'))
for k, (x, z) in enumerate(((7, 6), (11, 6), (15, 6))):
    cellar.append(node("BossBarrel%d" % k, "prop", x, 0.6, z, 'kind = "boom_barrel"'))
# The first fight: walk into the room's middle, they come through two rifts for you.
cellar.append(node("RiftNorth", "rift", 1, 0, -6, "radius = 1.5"))
cellar.append(node("RiftSouth", "rift", 1, 0, 6, "radius = 1.5"))
cellar.append(node("TheyWake", "zone", -6, 0, 0, "size = Vector3(4, 4, 16)"))
cellar.append(node("Fight", "encounter", -2, 0, 0, 'waves = Array[ExtResource("wave")]([SubResource("first"), SubResource("second")])\nrifts = Array[NodePath]([NodePath("../RiftNorth"), NodePath("../RiftSouth")])\ninputs = Array[NodePath]([NodePath("../TheyWake")])\nrespawn_after = 8.0\nrestart_after = 3.0'))
cellar.append(node("WayOn", "door", 4, 0, 0, 'size = Vector3(4, 4, 0.5)\ninputs = Array[NodePath]([NodePath("../Fight")])\nobjective = "Beat what\'s down here"', CROSS_DOOR))
# The second: a checkpoint; the cage door opens and the ram and its bunnies head for a spot.
cellar.append(node("HalfWay", "checkpoint", 6.5, 0, 3))
cellar.append(node("RiftCage", "rift", 14, 0, -6, "radius = 1.5"))
cellar.append(marker("WhereTheyGo", 11, 0, 3))
cellar.append(node("BossWakes", "zone", 8, 0, 3, "size = Vector3(8, 4, 8)")) # (all round the checkpoint: everyone landing there is in it)
cellar.append(node("CageDoor", "door", 14, 0, -4, 'size = Vector3(4, 4, 0.5)\ninputs = Array[NodePath]([NodePath("../BossWakes")])'))
cellar.append(node("BossFight", "encounter", 11, 0, 0, 'waves = Array[ExtResource("wave")]([SubResource("boss")])\nrifts = Array[NodePath]([NodePath("../RiftCage")])\ngoal = NodePath("../WhereTheyGo")\ninputs = Array[NodePath]([NodePath("../BossWakes")])\nstart_delay = 1.5\nrespawn_after = 8.0\nrestart_after = 3.0'))
cellar.append(node("WayOut", "door", 18, 0, 0, 'size = Vector3(4, 4, 0.5)\ninputs = Array[NodePath]([NodePath("../BossFight")])\nobjective = "Beat the Ram"', CROSS_DOOR))
cellar.append(node("Exit", "exit", 25, 0, 0))
# The rift script's name: the id above needs adding to the list.
text = "\n".join(cellar).replace('[ext_resource type="Script" path="res://scripts/mapkit/encounter_wave.gd" id="wave"]', '[ext_resource type="Script" path="res://scripts/mapkit/monster_spawn.gd" id="rift"]\n[ext_resource type="Script" path="res://scripts/mapkit/encounter_wave.gd" id="wave"]')
os.makedirs("adventures/the_cellar", exist_ok=True)
open("adventures/the_cellar/cellar.tscn", "w", encoding="utf-8", newline="\n").write(text)
open("adventures/the_cellar.adventure.tres", "w", encoding="utf-8", newline="\n").write('''[gd_resource type="Resource" script_class="Adventure" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/mapkit/adventure.gd" id="adventure"]
[ext_resource type="Script" path="res://scripts/mapkit/adventure_chapter.gd" id="chapter"]

[sub_resource type="Resource" id="one"]
script = ExtResource("chapter")
map = "res://adventures/the_cellar/cellar.tscn"
title = "Down Here"
intro = "Something's down here. Quite a lot of things."

[resource]
script = ExtResource("adventure")
display_name = "The Cellar (test)"
description = "Two small fights: it shows how an Encounter's put together."
chapters = Array[ExtResource("chapter")]([SubResource("one")])
''')
print("wrote adventures/two_small_rooms.adventure.tres and its two rooms, adventures/the_cellar.adventure.tres and its map")
