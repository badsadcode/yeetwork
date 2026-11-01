"""Writes custom/make_your_own/boat.tscn: "Make Your Own Boat", a small map showing the Map
Kit's Vessel: a boat on the open swell built from ordinary pieces under one Vessel node (a hull,
deck and cabin of blocks, a mast, a ladder up from the sea, cargo, a bell, a little crane, a
breakable fence at the stern, spawn points on deck, Red's flag at the stern and Blue's at the
bow). Everything on it rides the swell.

Usage: python tools/make_boat.py
"""
import math

OUT = 'custom/make_your_own/boat.tscn'

ext = [
    ('Script', 'res://scripts/mapkit/map_settings.gd', 'settings'),
    ('Script', 'res://scripts/mapkit/vessel.gd', 'vessel'),
    ('Script', 'res://scripts/mapkit/arena_block.gd', 'block'),
    ('Script', 'res://scripts/mapkit/spawn_point.gd', 'spawn'),
    ('Script', 'res://scripts/mapkit/prop_spawn.gd', 'prop'),
    ('Script', 'res://scripts/mapkit/ladder.gd', 'ladder'),
    ('Script', 'res://scripts/mapkit/horn.gd', 'horn'),
    ('Script', 'res://scripts/mapkit/crane.gd', 'crane'),
    ('Script', 'res://scripts/mapkit/breakable_model.gd', 'bmodel'),
    ('Script', 'res://scripts/mapkit/flag_stand.gd', 'flag'),
    ('Resource', 'res://custom/make_your_own/oil_drum.tres', 'drum'),
    ('PackedScene', 'res://custom/make_your_own/models/bell.glb', 'bellmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/crane.glb', 'cranemodel'),
    ('PackedScene', 'res://custom/make_your_own/models/crate_load.glb', 'loadmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/fence.glb', 'fencemodel'),
]

nodes = []


def xf(x, y, z, yaw=0):
    c, s = round(math.cos(math.radians(yaw)), 6), round(math.sin(math.radians(yaw)), 6)
    return 'Transform3D(%g, 0, %g, 0, 1, 0, %g, 0, %g, %g, %g, %g)' % (c, s, -s, c, x, y, z)  # (rows of the basis)


def node(name, script=None, parent='.', at=(0, 0, 0), yaw=0, **props):
    kind = 'StaticBody3D' if script == 'block' else 'Node3D'
    lines = ['[node name="%s" type="%s" parent="%s"]' % (name, kind, parent), 'transform = ' + xf(*at, yaw)]
    if script:
        lines.append('script = ExtResource("%s")' % script)
    for k, v in props.items():
        lines.append('%s = %s' % (k, v))
    nodes.append('\n'.join(lines))


def vec(x, y, z):
    return 'Vector3(%g, %g, %g)' % (x, y, z)


def color(r, g, b):
    return 'Color(%g, %g, %g, 1)' % (r, g, b)


HULL = color(0.15, 0.3, 0.5)
DECK = color(0.62, 0.45, 0.28)
WHITE = color(0.92, 0.92, 0.9)

nodes.append('[node name="MakeYourOwnBoat" type="Node3D"]')
nodes.append('\n'.join([
    '[node name="MapSettings" type="Node" parent="."]',
    'script = ExtResource("settings")',
    'map_name = "Make Your Own Boat"',
    'author = "Yeetwork Map Kit"',
    'description = "A Vessel: a boat built from ordinary Map Kit pieces under one node, riding the swell. Fall in, swim to the ladder, climb back aboard."',
    'sky = "day"',
    'kill_height = -25.0',
    'ocean = true',
    'ocean_level = 0.0',
    'ocean_preset = "ocean"',
    'ocean_swimmable = true',
]))
# The boat: everything under the Vessel rides the swell (its origin on the waterline, bow +X).
node('Boat', 'vessel', '.', length='26.0', beam='9.0', roll='3.0', max_roll_degrees='12.0', max_pitch_degrees='5.0')
B = 'Boat'
node('Hull', 'block', B, at=(0, -0.25, 0), size=vec(24, 3.5, 8), color=HULL)
node('Bow', 'block', B, at=(13.2, 0.2, 0), yaw=0, size=vec(2.4, 2.6, 5), color=HULL)
node('Deck', 'block', B, at=(0, 1.55, 0), size=vec(24, 0.1, 8), color=DECK)
for s, z in (('Port', -3.85), ('Starboard', 3.85)):
    node('Rail' + s, 'block', B, at=(0, 2.0, z), size=vec(24, 0.8, 0.3), color=WHITE)
node('Cabin', 'block', B, at=(-3, 3.1, 0), size=vec(5, 3, 5), color=WHITE)
node('CabinRoof', 'block', B, at=(-3, 4.75, 0), size=vec(5.6, 0.3, 5.6), color=HULL)
node('Mast', 'block', B, at=(3, 5.6, 0), size=vec(0.35, 8, 0.35), color=DECK)
# Up out of the sea: a ladder on the starboard side (its +Z out from the hull).
node('Ladder', 'ladder', B, at=(1.5, -1.6, 4.15), height='4.4', over_the_top='5.0')  # (its top clears the rail)
node('Bell', 'horn', B, at=(0.8, 1.6, 2.9), model='ExtResource("bellmodel")')
node('Crane', 'crane', B, at=(9, 1.6, -2), height='8.0', jib='10.0', cable='2.5', heading='0.0', sweep='60.0',
     period='26.0', load_size='Vector3(3, 1.5, 1.5)', pedestal_size='Vector3(1.4, 0, 1.4)',
     model='ExtResource("cranemodel")', load_model='ExtResource("loadmodel")')
node('SternFence', 'bmodel', B, at=(-11.8, 1.6, 0), yaw=90, model='ExtResource("fencemodel")', material='"wood"')
for i in range(3):
    node('Crate%d' % i, 'prop', B, at=(5.5 + i * 1.2, 2.2, 1.5), kind='"crate"')
node('Drum', 'prop', B, at=(1.2, 2.2, -2.8), type='ExtResource("drum")')
node('Barrel', 'prop', B, at=(2.4, 2.2, -2.8), kind='"barrel"')
node('FlagRed', 'flag', B, at=(-9, 1.6, 0), team='0')
node('FlagBlue', 'flag', B, at=(10.5, 1.6, 1.5), team='1')
for i, (x, z, team) in enumerate([(-7, -2.5, 0), (-7, 2.5, 0), (5, -2.5, 0), (0.5, 0.8, 0),
        (-10, -2.8, 1), (-10, 2.8, 1), (11.2, -2.6, 2), (7.5, -2.8, 2)]):
    node('Spawn%d' % i, 'spawn', B, at=(x, 1.6, z), team=str(team))

out = ['[gd_scene load_steps=%d format=3]' % (len(ext) + 1), '']
for t, p, i in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i))
out.append('')
out.append('\n\n'.join(nodes))
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print('wrote', OUT)
