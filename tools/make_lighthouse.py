"""Writes custom/lighthouse_point/lighthouse_point.tscn: "Lighthouse Point", the map that
docs/MAKE_A_NEW_MAP.md builds: a small Capture the Flag map on a headland at sunset, with a bit
of everything. Red holds the lighthouse (a ladder up the tower to the gallery, its beam a
spotlight turning on a Spinner, a jump pad up), Blue the boathouse (a wooden door the gravity
gun rips off, a glass window, a humming generator, a jetty out to sea through its back doorway, a
jump pad onto its roof). Between them: a ruined brick wall, a campfire among boom barrels, lamp posts, a crane
swinging a load over the middle, rocks for cover. The sea round it is swimmable, with ladders
up out of it. The door's model is a copy of the starter one, in the map's own folder (a map
pack takes only what's in it).

Usage: python tools/make_lighthouse.py
"""
import math
import os
import shutil

DIR = 'custom/lighthouse_point/'
OUT = DIR + 'lighthouse_point.tscn'

ext = [
    ('Script', 'res://scripts/mapkit/map_settings.gd', 'settings'),
    ('Script', 'res://scripts/mapkit/arena_block.gd', 'block'),
    ('Script', 'res://scripts/mapkit/breakable_slab.gd', 'slab'),
    ('Script', 'res://scripts/mapkit/breakable_model.gd', 'bmodel'),
    ('Script', 'res://scripts/mapkit/spawn_point.gd', 'spawn'),
    ('Script', 'res://scripts/mapkit/flag_stand.gd', 'flag'),
    ('Script', 'res://scripts/mapkit/prop_spawn.gd', 'prop'),
    ('Script', 'res://scripts/mapkit/pickup_spawn.gd', 'pickup'),
    ('Script', 'res://scripts/mapkit/jump_pad.gd', 'pad'),
    ('Script', 'res://scripts/mapkit/ladder.gd', 'ladder'),
    ('Script', 'res://scripts/mapkit/crane.gd', 'crane'),
    ('Script', 'res://scripts/mapkit/hazard_volume.gd', 'hazard'),
    ('Script', 'res://scripts/mapkit/map_light.gd', 'light'),
    ('Script', 'res://scripts/mapkit/spinner.gd', 'spinner'),
    ('Script', 'res://scripts/mapkit/fixture.gd', 'fixture'),
    ('PackedScene', 'res://custom/lighthouse_point/models/door.glb', 'doormodel'),
]

nodes = []


def xf(x, y, z, yaw=0, pitch=0, roll=0):
    """A transform: yaw about Y, then pitch about X, then roll about Z (degrees), rows of the basis."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

    m = mul(mul(ry, rx), rz)
    vals = [m[r][c] for r in range(3) for c in range(3)]  # (a .tscn writes the basis by rows)
    return 'Transform3D(%s, %g, %g, %g)' % (', '.join('%g' % round(v, 6) for v in vals), x, y, z)


def node(name, script=None, parent='.', at=(0, 0, 0), yaw=0, pitch=0, roll=0, **props):
    ntype = 'StaticBody3D' if script == 'block' else 'Node3D'
    lines = ['[node name="%s" type="%s" parent="%s"]' % (name, ntype, parent)]
    lines.append('transform = ' + xf(*at, yaw, pitch, roll))
    if script:
        lines.append('script = ExtResource("%s")' % script)
    for k, v in props.items():
        lines.append('%s = %s' % (k, v))
    nodes.append('\n'.join(lines))


def group(name):
    nodes.append('[node name="%s" type="Node3D" parent="."]' % name)


def vec(x, y, z):
    return 'Vector3(%g, %g, %g)' % (x, y, z)


def color(r, g, b):
    return 'Color(%g, %g, %g, 1)' % (r, g, b)


GRASS = color(0.45, 0.62, 0.38)
SAND = color(0.86, 0.78, 0.56)
STONE = color(0.62, 0.6, 0.58)
WHITE = color(0.93, 0.92, 0.88)
RED = color(0.78, 0.25, 0.22)
WOOD = color(0.55, 0.4, 0.26)
BLUE = color(0.3, 0.45, 0.72)

nodes.append('[node name="LighthousePoint" type="Node3D"]')
nodes.append('\n'.join([
    '[node name="MapSettings" type="Node" parent="."]',
    'script = ExtResource("settings")',
    'map_name = "Lighthouse Point"',
    'author = "Yeetwork Map Kit"',
    'description = "A headland at sunset: Red holds the lighthouse, Blue the boathouse. A ruined wall, a campfire, a crane over the middle, and the sea all round."',
    'sky = "sunset"',
    'ocean = true',
    'ocean_level = -1.5',
    'ocean_swimmable = true',
    'kill_height = -20.0',
    'playtest_mode = 1',
    'playtest_bots = 5',
]))

# The headland: grass on top, a sandy beach on the south side.
group('Ground')
node('Headland', 'block', 'Ground', at=(0, -3, -2), size=vec(64, 6, 36), color=GRASS)
node('Beach', 'block', 'Ground', at=(0, -3.5, 19), size=vec(52, 6, 6), color=SAND)
for i, (x, z, yaw, s) in enumerate([(-6, -12, 20, (4, 2.2, 3)), (9, 8, -35, (3.5, 1.8, 3)), (-12, 10, 50, (3, 1.5, 2.5))]):
    node('Rock%d' % i, 'block', 'Ground', at=(x, s[1] * 0.35, z), yaw=yaw, roll=8, size=vec(*s), color=STONE)

# Red: the lighthouse on its yard, a ladder up its east face to the gallery.
group('Lighthouse')
node('Yard', 'block', 'Lighthouse', at=(-24, 0.5, 0), size=vec(14, 1, 16), color=STONE)
node('Tower', 'block', 'Lighthouse', at=(-27, 8, 0), size=vec(5, 14, 5), color=WHITE)
node('TowerBand', 'block', 'Lighthouse', at=(-27, 8, 0), size=vec(5.1, 2, 5.1), color=RED, solid='false')
node('Gallery', 'block', 'Lighthouse', at=(-28.25, 15.2, 0), size=vec(7.5, 0.4, 8), color=RED)
node('LampRoom', 'block', 'Lighthouse', at=(-27, 16.65, 0), size=vec(3, 2.5, 3), color=color(1, 0.85, 0.45), emission='1.5')
node('LampRoof', 'block', 'Lighthouse', at=(-27, 18.1, 0), size=vec(3.6, 0.4, 3.6), color=RED)
node('TowerLadder', 'ladder', 'Lighthouse', at=(-24.4, 1, 0), yaw=90, height='14.8', over_the_top='2.5')
node('ToTheGallery', 'pad', 'Lighthouse', at=(-19, 1, 6), target=vec(-6, 14.4, -3), arc_height='2.0')
# The beam: a spotlight on a Spinner turns round the lamp room (a piece made of two pieces).
node('Beam', 'spinner', 'Lighthouse', at=(-27, 16.9, 0), speed='0.6')
node('Spotlight', 'light', 'Lighthouse/Beam', at=(0, 0, -1.6), pitch=-8, kind='"spotlight"', color=color(1, 0.92, 0.7), energy='4.0', reach='60.0', breakable='false')
node('FlagRed', 'flag', 'Lighthouse', at=(-21, 1, 0), team='0')
node('TorchN', 'light', 'Lighthouse', at=(-17.5, 1, -7.5), kind='"torch"')
node('TorchS', 'light', 'Lighthouse', at=(-17.5, 1, 7.5), kind='"torch"')

# Blue: the boathouse, its door (the gun rips it off), a glass window, a jetty out to sea.
group('Boathouse')
node('BackWall', 'block', 'Boathouse', at=(30.25, 2.5, 0), size=vec(0.5, 5, 11), color=BLUE)
# Its back way out, to the jetty: an open doorway in the north wall.
node('NorthWallWest', 'block', 'Boathouse', at=(20.4, 2.5, -5.25), size=vec(4.8, 5, 0.5), color=BLUE)
node('NorthWallEast', 'block', 'Boathouse', at=(27.6, 2.5, -5.25), size=vec(4.8, 5, 0.5), color=BLUE)
node('OverTheBackDoor', 'block', 'Boathouse', at=(24, 4, -5.25), size=vec(2.4, 2, 0.5), color=BLUE)
node('SouthWall', 'block', 'Boathouse', at=(24, 2.5, 5.25), size=vec(12, 5, 0.5), color=BLUE)
node('Roof', 'block', 'Boathouse', at=(24, 5.2, 0), size=vec(13, 0.4, 11.5), color=WOOD)
node('FrontNorth', 'block', 'Boathouse', at=(17.75, 2.5, -3.13), size=vec(0.5, 5, 4.74), color=BLUE)
node('FrontSouthLow', 'block', 'Boathouse', at=(17.75, 0.5, 3.13), size=vec(0.5, 1, 4.74), color=BLUE)
node('FrontSouthHigh', 'block', 'Boathouse', at=(17.75, 4, 3.13), size=vec(0.5, 2, 4.74), color=BLUE)
node('OverTheDoor', 'block', 'Boathouse', at=(17.75, 3.73, 0), size=vec(0.5, 2.54, 1.52), color=BLUE)
node('Window', 'slab', 'Boathouse', at=(17.75, 2, 3.13), yaw=90, size='Vector2(4.74, 2)', thickness='0.15', material='"glass"',
     anchor_top='true', anchor_left='true', anchor_right='true')
node('Door', 'bmodel', 'Boathouse', at=(17.75, 0, 0), yaw=90, model='ExtResource("doormodel")', material='"wood"', tear_off='true')
node('FlagBlue', 'flag', 'Boathouse', at=(27, 0, 0), team='1')
node('Generator', 'fixture', 'Boathouse', at=(28.5, 0, 3.6), kind='"generator"', breakable='true')
node('Lamp', 'light', 'Boathouse', at=(24, 4.4, 0), kind='"bulb"', energy='1.5')
node('Jetty', 'block', 'Boathouse', at=(24, -0.2, -27), size=vec(3, 0.4, 14), color=WOOD)
for z in (-22, -27, -32):
    for x in (22.7, 25.3):
        node('JettyPost%d_%d' % (int(-z), int(x * 10)), 'block', 'Boathouse', at=(x, -2.5, z), size=vec(0.3, 4.6, 0.3), color=WOOD)
node('JettyLadder', 'ladder', 'Boathouse', at=(24, -3.8, -34.05), yaw=180, height='4.4', over_the_top='3.0')
node('ToTheRoof', 'pad', 'Boathouse', at=(12, 0, -9), target=vec(11, 5.4, 9), arc_height='2.0')

# The middle: a ruined brick wall, a campfire among boom barrels, lamp posts, the crane.
group('Middle')
node('RuinNorth', 'slab', 'Middle', at=(0, 1.5, -8), yaw=90, size='Vector2(8, 3)', thickness='0.6', material='"brick"', color=color(0.8, 0.5, 0.4))
node('RuinSouth', 'slab', 'Middle', at=(0, 1.0, 6), yaw=90, size='Vector2(6, 2)', thickness='0.6', material='"brick"', color=color(0.8, 0.5, 0.4))
node('Campfire', 'hazard', 'Middle', at=(4, 0, 14), kind='"fire"', size=vec(2, 1.5, 2))
node('LampWest', 'light', 'Middle', at=(-9, 0, 3), kind='"lamp_post"')
node('LampEast', 'light', 'Middle', at=(9, 0, -3), kind='"lamp_post"')
node('Crane', 'crane', 'Middle', at=(0, 0, -17), height='11.0', jib='12.0', cable='4.0', heading='-90.0', sweep='70.0', period='36.0')
node('SouthLadder', 'ladder', 'Middle', at=(-14, -4.0, 22.05), yaw=0, height='4.0', over_the_top='3.0')

group('Spawns')
for i, (x, y, z) in enumerate([(-22, 1, -5), (-22, 1, 5), (-19, 1, -2), (-19, 1, 2), (-25, 1, -6)]):
    node('Red%d' % i, 'spawn', 'Spawns', at=(x, y, z), team='1')
for i, (x, y, z) in enumerate([(26, 0, -2.5), (26, 0, 2.5), (22, 0, -3), (22, 0, 3), (15, 0, -7)]):
    node('Blue%d' % i, 'spawn', 'Spawns', at=(x, y, z), team='2')
for i, (x, z) in enumerate([(-8, -14), (8, 14), (-4, 0), (5, 0), (-14, 14), (14, -14)]):
    node('Any%d' % i, 'spawn', 'Spawns', at=(x, 0, z))

group('Props')
props = [('crate', -3, 0.5, -3), ('crate', -3, 1.5, -3), ('crate_big', 3, 0.7, 3), ('boom_barrel', 2.5, 0.6, 12.5),
         ('boom_barrel', 5.5, 0.6, 12), ('barrel', 23, 0.6, -24), ('barrel', 25, 0.6, -29), ('crate', -21, 1.5, -6.5),
         ('crate', 21, 0.5, -3.8), ('plank', -6, 0.1, 9), ('beachball', 0, 0.5, 19), ('tire', 12, 0.3, 4)]
for i, (k, x, y, z) in enumerate(props):
    node('%s%d' % (k.title().replace('_', ''), i), 'prop', 'Props', at=(x, y, z), kind='"%s"' % k)

group('Pickups')
for i, (k, x, y, z) in enumerate([('super', -29, 15.4, 2.5), ('speed', 24, 5.4, 2), ('health_big', 0, 0, -3),
                                  ('health', -16, 1, -7), ('health', 16, 0, 7), ('random', 24, 0, -33)]):
    node('Pickup%d' % i, 'pickup', 'Pickups', at=(x, y, z), kind='"%s"' % k)

os.makedirs(DIR + 'models', exist_ok=True)
if not os.path.exists(DIR + 'models/door.glb'):
    shutil.copy('custom/make_your_own/models/door.glb', DIR + 'models/door.glb')
out = ['[gd_scene load_steps=%d format=3]' % (len(ext) + 1), '']
for t, p, i in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i))
out.append('')
out.append('\n\n'.join(nodes))
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print('wrote', OUT)
