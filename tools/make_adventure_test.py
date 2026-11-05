"""Writes the Adventure mode's tiny test adventure, Two Small Rooms: adventures/two_small_rooms.
adventure.tres and its two chapters' maps in adventures/two_small_rooms/: a button that opens the
way to an exit; then a plate a crate holds down. It shows how an adventure is put together, and
the checks play through it. Plain Map Kit afterwards (rerunning this overwrites it).
    python tools/make_adventure_test.py
"""
import os

OUT = "adventures/two_small_rooms"
EXT = [("settings", "map_settings"), ("block", "arena_block"), ("spawn", "spawn_point"), ("prop", "prop_spawn"), ("button", "puzzle_button"),
       ("plate", "pressure_plate"), ("door", "puzzle_door"), ("exit", "puzzle_exit")]
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

os.makedirs(OUT, exist_ok=True)
open(OUT + "/room1.tscn", "w", encoding="utf-8", newline="\n").write(room(
    "Two Small Rooms: the Button", "Press the button; through the door.",
    '[node name="Button" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -4)\nscript = ExtResource("button")\npress = "use key"\nlabel = "Open the door"\n\n'
    + DOOR % ("Button", "Open the door")))
open(OUT + "/room2.tscn", "w", encoding="utf-8", newline="\n").write(room(
    "Two Small Rooms: the Plate", "Weigh the plate down; through the door.",
    '[node name="Plate" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1, 0, 4)\nscript = ExtResource("plate")\nrequired_mass = 20.0\n\n'
    '[node name="Crate" type="Node3D" parent="."]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -7, 0.6, 0)\nscript = ExtResource("prop")\nkind = "crate"\nkey_prop = true\n\n'
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
print("wrote adventures/two_small_rooms.adventure.tres and its two rooms")
