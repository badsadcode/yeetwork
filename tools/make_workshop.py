"""Writes custom/make_your_own/workshop.tscn: the "Make Your Own Workshop", a small map that
shows the examples of docs/MAPPING.md's "Make your own versions" at work: a pipe of your own
pouring sideways out of a wall into a pool (its Spout), a drain with its Intake off to one
side, oil drums (a PropType) next to the built-in barrels, and, for MegaYeet, a thorn bed
(your own trap) and a built-in fire grate on the monsters' way to the Heart.

Usage: python tools/make_workshop.py
"""

OUT = 'custom/make_your_own/workshop.tscn'

ext = [
    ('Script', 'res://scripts/mapkit/map_settings.gd', 'settings'),
    ('Script', 'res://scripts/mapkit/arena_block.gd', 'block'),
    ('Script', 'res://scripts/mapkit/spawn_point.gd', 'spawn'),
    ('Script', 'res://scripts/mapkit/prop_spawn.gd', 'prop'),
    ('Script', 'res://scripts/mapkit/flood_zone.gd', 'flood'),
    ('Script', 'res://scripts/mapkit/fortress_heart.gd', 'heart'),
    ('Script', 'res://scripts/mapkit/monster_spawn.gd', 'rift'),
    ('Script', 'res://scripts/mapkit/trap_spot.gd', 'trap'),
    ('PackedScene', 'res://custom/make_your_own/my_pipe.tscn', 'pipe'),
    ('PackedScene', 'res://custom/make_your_own/my_drain.tscn', 'drain'),
    ('PackedScene', 'res://custom/make_your_own/thorn_trap.tscn', 'thorns'),
    ('Resource', 'res://custom/make_your_own/oil_drum.tres', 'drum'),
]

nodes = []


def xf(x, y, z):
    return 'Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % (x, y, z)


def node(name, script=None, parent='.', instance=None, at=(0, 0, 0), **props):
    head = '[node name="%s"' % name
    if instance:
        head += ' parent="%s" instance=ExtResource("%s")]' % (parent, instance)
    else:
        head += ' type="%s" parent="%s"]' % ('StaticBody3D' if script == 'block' else 'Node3D', parent)
    lines = [head, 'transform = ' + xf(*at)]
    if script:
        lines.append('script = ExtResource("%s")' % script)
    for k, v in props.items():
        lines.append('%s = %s' % (k, v))
    nodes.append('\n'.join(lines))


def vec(x, y, z):
    return 'Vector3(%g, %g, %g)' % (x, y, z)


def color(r, g, b):
    return 'Color(%g, %g, %g, 1)' % (r, g, b)


nodes.append('[node name="MakeYourOwnWorkshop" type="Node3D"]')
nodes.append('\n'.join([
    '[node name="MapSettings" type="Node" parent="."]',
    'script = ExtResource("settings")',
    'map_name = "Make Your Own Workshop"',
    'author = "Yeetwork Map Kit"',
    'description = "The Make Your Own examples at work: a pipe of your own pouring out of a wall, a drain, oil drums next to the barrels, and (MegaYeet) a thorn bed trap."',
    'sky = "day"',
    'kill_height = -20.0',
]))
for n in ['Blocks', 'Water', 'Props', 'MegaYeet']:
    nodes.append('[node name="%s" type="Node3D" parent="."]' % n)

# The ground.
node('Floor', 'block', 'Blocks', at=(0, -0.5, 0), size=vec(44, 1, 44), color=color(0.45, 0.5, 0.42))
# The pool: low walls round a 12 x 12 m basin (x -14..-2, z -6..6), a tall back wall with the
# pipe on it.
node('BackWall', 'block', 'Blocks', at=(-8, 2, -6.25), size=vec(12.5, 4, 0.5), color=color(0.6, 0.55, 0.5))
node('FrontWall', 'block', 'Blocks', at=(-8, 0.5, 6.25), size=vec(12.5, 1, 0.5), color=color(0.6, 0.55, 0.5))
node('LeftWall', 'block', 'Blocks', at=(-14.25, 0.5, 0), size=vec(0.5, 1, 12), color=color(0.6, 0.55, 0.5))
node('RightWall', 'block', 'Blocks', at=(-1.75, 0.5, 0), size=vec(0.5, 1, 12), color=color(0.6, 0.55, 0.5))
node('Pool', 'flood', 'Water', at=(-8, 0, 0), size=vec(12, 4, 12))
node('MyPipe', parent='Water', instance='pipe', at=(-8, 2.6, -6))
node('MyDrain', parent='Water', instance='drain', at=(-11, 0, 3))
# Props: oil drums of your own next to the built-in barrels.
for i in range(4):
    node('OilDrum%d' % i, 'prop', 'Props', at=(3 + i * 1.3, 0.6, -10), type='ExtResource("drum")')
for i in range(2):
    node('Barrel%d' % i, 'prop', 'Props', at=(3 + i * 1.3, 0.6, -12.5), kind='"barrel"')
# MegaYeet: monsters from the far side to the Heart, over a thorn bed and a fire grate.
node('Heart', 'heart', 'MegaYeet', at=(10, 0, 14), radius='2.5')
node('Rift', 'rift', 'MegaYeet', at=(10, 0, -18), radius='3.0')
node('ThornTrap', parent='MegaYeet', instance='thorns', at=(10, 0, -4))
node('FireGrate', 'trap', 'MegaYeet', at=(10, 0, 4), kind='"fire"', size=vec(4, 1, 4))
# Where the Yeets start.
for i, x in enumerate([-3, 0, 3, 6]):
    node('Spawn%d' % i, 'spawn', '.', at=(x, 0, 16))

out = ['[gd_scene load_steps=%d format=3]' % (len(ext) + 1), '']
for t, p, i in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i))
out.append('')
out.append('\n\n'.join(nodes))
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print('wrote', OUT)
