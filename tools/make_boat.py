"""Writes custom/make_your_own/boat.tscn: "Make Your Own Boat", a small map showing the Map
Kit's Vessel beside dry land: a boat on the swell built from ordinary pieces under one Vessel
node (a hull, deck and cabin of blocks, a mast, a ladder up from the sea, cargo, a bell, a
little crane, a breakable fence at the stern, Blue's base and flag at the bow), and an island
with a pier out to it (a jump pad at its end throws you aboard), crates on the pier, a ladder
up out of the sea, and Red's base and flag. Everything on the boat rides the swell; the island
stays put.

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
    ('Script', 'res://scripts/mapkit/jump_pad.gd', 'pad'),
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
    'description = "A Vessel beside dry land: a boat of ordinary Map Kit pieces riding the swell, an island with a pier (jump aboard from its end). Red on the island, Blue on the boat."',
    'sky = "day"',
    'kill_height = -25.0',
    'ocean = true',
    'ocean_level = 0.0',
    'ocean_preset = "ocean"',
    'ocean_swimmable = true',
]))
# The boat: everything under the Vessel rides the swell (its origin on the waterline, bow +X).
node('Boat', 'vessel', '.', length='26.0', beam='9.0', roll='2.2', max_roll_degrees='8.0', max_pitch_degrees='4.0')
B = 'Boat'
node('Hull', 'block', B, at=(0, -0.25, 0), size=vec(24, 3.5, 8), color=HULL)
node('Bow', 'block', B, at=(13.2, 0.2, 0), yaw=0, size=vec(2.4, 2.6, 5), color=HULL)
node('Deck', 'block', B, at=(0, 1.55, 0), size=vec(24, 0.1, 8), color=DECK)
for s, z in (('Port', -3.85), ('Starboard', 3.85)):
    node('Rail' + s, 'block', B, at=(0, 2.2, z), size=vec(24, 1.2, 0.3), color=WHITE)  # (high enough to keep sliding cargo aboard)
node('Cabin', 'block', B, at=(-3, 3.1, 0), size=vec(5, 3, 5), color=WHITE)
node('CabinRoof', 'block', B, at=(-3, 4.75, 0), size=vec(5.6, 0.3, 5.6), color=HULL)
node('Mast', 'block', B, at=(3, 5.6, 0), size=vec(0.35, 8, 0.35), color=DECK)
# Up out of the sea: a ladder on the starboard side (its +Z out from the hull).
node('Ladder', 'ladder', B, at=(1.5, -1.6, 4.15), height='4.8', over_the_top='5.0')  # (its top clears the rail)
node('Bell', 'horn', B, at=(0.8, 1.6, 2.9), model='ExtResource("bellmodel")')
node('Crane', 'crane', B, at=(9, 1.6, -2), height='8.0', jib='10.0', cable='2.5', heading='0.0', sweep='60.0',
     period='26.0', load_size='Vector3(3, 1.5, 1.5)', pedestal_size='Vector3(1.4, 0, 1.4)',
     model='ExtResource("cranemodel")', load_model='ExtResource("loadmodel")')
node('SternFence', 'bmodel', B, at=(-11.8, 1.6, 0), yaw=90, model='ExtResource("fencemodel")', material='"wood"')
for i in range(3):
    node('Crate%d' % i, 'prop', B, at=(5.5 + i * 1.2, 2.2, 1.5), kind='"crate"')
node('Drum', 'prop', B, at=(1.2, 2.2, -2.8), type='ExtResource("drum")')
node('Barrel', 'prop', B, at=(2.4, 2.2, -2.8), kind='"barrel"')
node('FlagBlue', 'flag', B, at=(10.5, 1.6, 1.5), team='1')
for i, (x, z, team) in enumerate([(-7, -2.5, 0), (5, -2.5, 0), (11.2, -2.6, 2), (7.5, -2.8, 2)]):
    node('Spawn%d' % i, 'spawn', B, at=(x, 1.6, z), team=str(team))
# Dry land (not under the Vessel: it stays put): an island west of the boat, a pier toward it.
SAND = color(0.85, 0.78, 0.55)
nodes.append('[node name="Island" type="Node3D" parent="."]')
node('Ground', 'block', 'Island', at=(-52, -2.0, 0), size=vec(30, 6, 30), color=SAND)
node('Hut', 'block', 'Island', at=(-58, 2.5, -6), size=vec(6, 3, 5), color=color(0.6, 0.45, 0.3))
node('Pier', 'block', 'Island', at=(-30.5, 1.2, 0), size=vec(13, 0.4, 3), color=DECK)
for x in (-35, -30, -25.5):
    for z in (-1.3, 1.3):
        node('PierPost%d_%d' % (int(-x), int(z * 10)), 'block', 'Island', at=(x, -1.0, z), size=vec(0.3, 4.2, 0.3), color=DECK)
# From the pier's end, a pad throws you aboard (its target: where you land, relative to it).
node('ToTheBoat', 'pad', 'Island', at=(-25, 1.4, 0), target='Vector3(16, 1.2, 0)', arc_height='3.0')
node('IslandLadder', 'ladder', 'Island', at=(-52, -1.6, 15.05), height='4.0', over_the_top='4.0')
node('FlagRed', 'flag', 'Island', at=(-56, 1.0, 4), team='0')
for i, (x, z, team) in enumerate([(-48, -4, 0), (-46, 6, 0), (-60, 2, 1), (-58, 8, 1)]):
    node('LandSpawn%d' % i, 'spawn', 'Island', at=(x, 1.0, z), team=str(team))
for i in range(3):
    node('PierCrate%d' % i, 'prop', 'Island', at=(-33 + i * 1.3, 1.95, 0.6), kind='"crate"')

out = ['[gd_scene load_steps=%d format=3]' % (len(ext) + 1), '']
for t, p, i in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i))
out.append('')
out.append('\n\n'.join(nodes))
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print('wrote', OUT)
