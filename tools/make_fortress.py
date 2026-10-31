"""Builds maps/fortress.tscn, MegaYeet's test fortress, from Map Kit pieces: three square
rings of walls (outer walls, courtyard, keep) with gates, the Heart in the middle, zones,
six rifts outside, spawns, jump pads up onto the walls, props. Run from the repo root:
    python tools/make_fortress.py
The map is plain Map Kit afterwards: edit it in Godot as you like (rerunning this overwrites it).
"""
import math

out = []
ext = [("settings", "map_settings"), ("block", "arena_block"), ("slab", "breakable_slab"), ("spawn", "spawn_point"),
       ("prop", "prop_spawn"), ("pad", "jump_pad"), ("zone", "defense_zone"), ("rift", "monster_spawn"), ("heart", "fortress_heart"), ("trap", "trap_spot")]
out.append('[gd_scene format=3]\n')
for i, f in ext:
    out.append('[ext_resource type="Script" path="res://scripts/mapkit/%s.gd" id="%s"]' % (f, i))
out.append('')
out.append('[node name="Fortress" type="Node3D"]\n')
out.append('''[node name="MapSettings" type="Node" parent="."]
script = ExtResource("settings")
map_name = "The Fortress"
author = "Yeetwork"
description = "MegaYeet's proving ground: three rings of walls round the Heart. Hold the gates, throw things off the walls."
sky = "sunset"
kill_height = -20.0
playtest_mode = 8
playtest_bots = 3
''')
for g in ["Geometry", "Gates", "Zones", "Rifts", "Spawns", "Props", "Pads", "Traps"]:
    out.append('[node name="%s" type="Node3D" parent="."]\n' % g)

n = {"i": 0}
STONE = "Color(0.64, 0.6, 0.55, 1)"
DARK = "Color(0.5, 0.47, 0.44, 1)"


def xf(x, y, z, rot=False):
    b = "0, 0, -1, 0, 1, 0, 1, 0, 0" if rot else "1, 0, 0, 0, 1, 0, 0, 0, 1"
    return "Transform3D(%s, %g, %g, %g)" % (b, x, y, z)


def block(x, y, z, sx, sy, sz, color=STONE, name=None):
    n["i"] += 1
    out.append('[node name="%s" type="StaticBody3D" parent="Geometry"]\ntransform = %s\nscript = ExtResource("block")\nsize = Vector3(%g, %g, %g)\ncolor = %s\n'
               % (name or "Block%d" % n["i"], xf(x, y, z), sx, sy, sz, color))


def gate(name, x, z, rot, w, h, material, color):
    out.append('[node name="%s" type="Node3D" parent="Gates"]\ntransform = %s\nscript = ExtResource("slab")\nsize = Vector2(%g, %g)\nthickness = 0.5\nmaterial = "%s"\ncolor = %s\nanchor_bottom = true\nanchor_top = true\nanchor_left = true\nanchor_right = true\n'
               % (name, xf(x, h * 0.5, z, rot), w, h, material, color))


def node(parent, name, script, x, y, z, extra="", rot=False):
    out.append('[node name="%s" type="Node3D" parent="%s"]\ntransform = %s\nscript = ExtResource("%s")\n%s' % (name, parent, xf(x, y, z, rot), script, extra))


# Ground.
block(0, -1, 0, 160, 2, 160, "Color(0.42, 0.5, 0.36, 1)", "Ground")

T = 3.0
GAP = 5.0
GATE_H = 4.5
rings = [("Outer", 38.0, 7.0, "wood", "Color(0.6, 0.42, 0.25, 1)"), ("Inner", 22.0, 7.5, "wood", "Color(0.55, 0.38, 0.22, 1)"), ("Keep", 9.0, 1.1, "metal", "Color(0.45, 0.47, 0.5, 1)")]
for rname, R, H, mat, gcol in rings:
    # Along X at z = +-R (full length, corners included), along Z at x = +-R (between them).
    for s in (-1, 1):
        seg = R + T / 2 - GAP / 2
        for side in (-1, 1):
            block(side * (GAP / 2 + seg / 2), H / 2, s * R, seg, H, T)
            seg2 = R - T / 2 - GAP / 2
            block(s * R, H / 2, side * (GAP / 2 + seg2 / 2), T, H, seg2)
        # Lintels over the gates (a low wall has none: you hop over it, monsters can't), the gates.
        gh = min(GATE_H, H)
        if H > GATE_H:
            block(0, (GATE_H + H) / 2, s * R, GAP, H - GATE_H, T, DARK)
            block(s * R, (GATE_H + H) / 2, 0, T, H - GATE_H, GAP, DARK)
        gate("%sGate%s" % (rname, "S" if s > 0 else "N"), 0, s * R, False, GAP, gh, mat, gcol)
        gate("%sGate%s" % (rname, "E" if s > 0 else "W"), s * R, 0, True, GAP, gh, mat, gcol)
    # Battlements: a low parapet round the outside edge of the wall top.
    if rname != "Keep":
        for s in (-1, 1):
            block(0, H + 0.4, s * (R + T / 2 - 0.25), 2 * R + T, 0.8, 0.5, DARK)
            block(s * (R + T / 2 - 0.25), H + 0.4, 0, 0.5, 0.8, 2 * R + T - 1.0, DARK)
# Towers at the outer corners.
for sx in (-1, 1):
    for sz in (-1, 1):
        block(sx * 38, 5.5, sz * 38, 7, 11, 7, DARK)

# Zones (deepest wins where they overlap).
for lvl, (rname, R, H, _m, _c) in zip((1, 2, 3), rings):
    size = 2 * R + T
    names = {1: "the outer walls", 2: "the courtyard", 3: "the keep"}
    node("Zones", "Zone%d" % lvl, "zone", 0, -0.5, 0, 'level = %d\nsize = Vector3(%g, 14, %g)\nzone_name = "%s"\n' % (lvl, size, size, names[lvl]))

node(".", "Heart", "heart", 0, 0, 0, "radius = 2.5\n")

# Rifts: six round the outside, two opening from wave 3.
for k in range(6):
    a = k * math.pi / 3 + math.pi / 6
    node("Rifts", "Rift%d" % k, "rift", round(math.cos(a) * 62, 2), 0, round(math.sin(a) * 62, 2), "radius = 3.5\n" + ("from_wave = 3\n" if k in (1, 4) else ""))

# Trap spots just inside the gates (built between waves): spikes and fire grates behind the
# outer gates, mines behind the inner ones.
for name, (x, z), kind in [("SpikesN", (0, -33.5), "spikes"), ("SpikesS", (0, 33.5), "spikes"), ("FireE", (33.5, 0), "fire"), ("FireW", (-33.5, 0), "fire"),
                           ("MineN", (0, -17.5), "mine"), ("MineS", (0, 17.5), "mine"), ("MineE", (17.5, 0), "mine"), ("MineW", (-17.5, 0), "mine")]:
    node("Traps", name, "trap", x, 0, z, 'kind = "%s"\nsize = Vector3(4, 1, 4)\n' % kind)

# Player spawns round the Heart, inside the keep.
for k, (x, z) in enumerate([(4, 4), (-4, 4), (4, -4), (-4, -4), (5.5, 0), (-5.5, 0), (0, 5.5), (0, -5.5)]):
    node("Spawns", "Spawn%d" % k, "spawn", x, 0, z)

# Jump pads up onto the walls (inside each ring, by the walls).
pads = 0
for R, H in ((38.0, 7.0), (22.0, 7.5)):
    for s in (-1, 1):
        for (x, z, tx, tz) in ((10, s * (R - 4.5), 0, s * 4.5), (s * (R - 4.5), 10, s * 4.5, 0)):
            pads += 1
            node("Pads", "Pad%d" % pads, "pad", x, 0, z, "target = Vector3(%g, %g, %g)\n" % (tx, H + 0.2, tz))

# Props: blast barrels and crates up on the walls (to drop and throw), things in the courtyard.
props = []
for R, H in ((38.0, 7.0), (22.0, 7.5)):
    for s in (-1, 1):
        for off in (-14, 14):
            props.append(("boom_barrel", off, H + 0.7, s * R))
            props.append(("crate", s * R, H + 0.6, off))
for (x, z) in ((12, 12), (-12, 12), (12, -12), (-12, -12)):
    props.append(("crate", x, 0.6, z))
    props.append(("crate", x + 1.2, 0.6, z))
    props.append(("barrel", x, 0.7, z + 1.5))
for (x, z) in ((28, 28), (-28, 28), (28, -28), (-28, -28)):
    props.append(("anvil", x, 0.3, z))
    props.append(("crate_big", x + 2, 0.9, z))
    props.append(("boom_barrel", x - 2, 0.7, z))
# Two iron balls in courtyard corners (team lift: too heavy for one gun), off the ways
# between the gates and the pads (a bot walking into one ends up rolling it about on top).
props.append(("iron_ball", 15.5, 1.2, -15.5))
props.append(("iron_ball", -15.5, 1.2, 15.5))
for k, (kind, x, y, z) in enumerate(props):
    node("Props", "Prop%d" % k, "prop", x, y, z, 'kind = "%s"\n' % kind)

open("maps/fortress.tscn", "w", encoding="utf-8", newline="\n").write("\n".join(out))
print(len(props), "props,", n["i"], "blocks")
