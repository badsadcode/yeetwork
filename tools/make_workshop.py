"""Writes custom/make_your_own/workshop.tscn: the "Make Your Own Workshop", a small map that
shows the examples of docs/MAPPING.md's "Make your own versions" at work: a pipe of your own
pouring sideways out of a wall into a pool (its Spout), a drain with its Intake off to one
side, oil drums (a PropType) next to the built-in barrels, an energy drink (a PickupType), a
wooden fan (a PuzzleFan's Model) blowing at them, a brick wall to break (a BreakableSlab's
Custom Material), stone flag stands (CTF), a crane of your own swinging a crate, a bell (a
Horn), a swimmable sea round the island with a wooden ladder up out of it, the built-in ladder
up the pool's back wall, a door, a window and a fence that break part by part (BreakableModel),
a shed door the gravity gun rips off (Tear Off), glass cabinets that break into their parts
(a PropType), models playing their own animations (AnimatedModel): a windmill, a swinging
sign, a platform ferrying you out over the sea and back, a drawbridge a button lowers to an
islet,
and, for MegaYeet, a thorn bed (your own trap) and a built-in fire
grate on the monsters' way to the Heart, and Scarecrows (a MonsterType on the Heart's Monster
Types) in the waves.

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
    ('Resource', 'res://custom/make_your_own/glass_cabinet.tres', 'cabinet'),
    ('Script', 'res://scripts/mapkit/pickup_spawn.gd', 'pickup'),
    ('Script', 'res://scripts/mapkit/puzzle_fan.gd', 'fan'),
    ('Script', 'res://scripts/mapkit/flag_stand.gd', 'flag'),
    ('Script', 'res://scripts/mapkit/breakable_slab.gd', 'slab'),
    ('Resource', 'res://custom/make_your_own/energy_drink.tres', 'drink'),
    ('PackedScene', 'res://custom/make_your_own/models/fan.glb', 'fanmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/flag_stand.glb', 'flagmodel'),
    ('Material', 'res://custom/make_your_own/bricks.tres', 'bricks'),
    ('Script', 'res://scripts/mapkit/ladder.gd', 'ladder'),
    ('Script', 'res://scripts/mapkit/crane.gd', 'crane'),
    ('Script', 'res://scripts/mapkit/horn.gd', 'horn'),
    ('PackedScene', 'res://custom/make_your_own/models/ladder.glb', 'laddermodel'),
    ('PackedScene', 'res://custom/make_your_own/models/crane.glb', 'cranemodel'),
    ('PackedScene', 'res://custom/make_your_own/models/crate_load.glb', 'loadmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/bell.glb', 'bellmodel'),
    ('Script', 'res://scripts/mapkit/breakable_model.gd', 'bmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/door.glb', 'doormodel'),
    ('PackedScene', 'res://custom/make_your_own/models/window.glb', 'windowmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/fence.glb', 'fencemodel'),
    ('Script', 'res://scripts/mapkit/animated_model.gd', 'anim'),
    ('Script', 'res://scripts/mapkit/puzzle_button.gd', 'button'),
    ('PackedScene', 'res://custom/make_your_own/models/windmill.glb', 'windmillmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/sign.glb', 'signmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/platform.glb', 'platformmodel'),
    ('PackedScene', 'res://custom/make_your_own/models/drawbridge.glb', 'bridgemodel'),
    ('Script', 'res://scripts/horde/monster_type.gd', 'monstertype'),
    ('Resource', 'res://custom/make_your_own/scarecrow.tres', 'scarecrow'),
]

nodes = []


def xf(x, y, z, yaw=0):
    import math
    c, s = round(math.cos(math.radians(yaw)), 6), round(math.sin(math.radians(yaw)), 6)
    return 'Transform3D(%g, 0, %g, 0, 1, 0, %g, 0, %g, %g, %g, %g)' % (c, s, -s, c, x, y, z)  # (rows of the basis)


def node(name, script=None, parent='.', instance=None, at=(0, 0, 0), yaw=0, **props):
    head = '[node name="%s"' % name
    if instance:
        head += ' parent="%s" instance=ExtResource("%s")]' % (parent, instance)
    else:
        head += ' type="%s" parent="%s"]' % ('StaticBody3D' if script == 'block' else 'Node3D', parent)
    lines = [head, 'transform = ' + xf(*at, yaw)]
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
    'ocean = true',
    'ocean_level = -1.5',
    'ocean_preset = "calm"',
    'ocean_swimmable = true',
]))
for n in ['Blocks', 'Water', 'Props', 'MegaYeet', 'More']:
    nodes.append('[node name="%s" type="Node3D" parent="."]' % n)

# The ground.
node('Floor', 'block', 'Blocks', at=(0, -3, 0), size=vec(44, 6, 44), color=color(0.45, 0.5, 0.42))
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
# Glass cabinets (a PropType that breaks into its parts) beside them.
for i in range(2):
    node('Cabinet%d' % i, 'prop', 'Props', at=(0 + i * 1.2, 0.6, -12.5), type='ExtResource("cabinet")')
# MegaYeet: monsters from the far side to the Heart, over a thorn bed and a fire grate.
node('Heart', 'heart', 'MegaYeet', at=(10, 0, 14), radius='2.5',
     monster_types='Array[ExtResource("monstertype")]([ExtResource("scarecrow")])')
node('Rift', 'rift', 'MegaYeet', at=(10, 0, -18), radius='3.0')
node('ThornTrap', parent='MegaYeet', instance='thorns', at=(10, 0, -4))
node('FireGrate', 'trap', 'MegaYeet', at=(10, 0, 4), kind='"fire"', size=vec(4, 1, 4))
# A pickup of your own, a fan of your own (blowing at the drums), a brick wall, flag stands.
node('EnergyDrink', 'pickup', 'More', at=(0, 0, 8), type='ExtResource("drink")')
node('WoodenFan', 'fan', 'More', at=(4.5, 0, -4), model='ExtResource("fanmodel")', strength='20.0', reach='9.0')
node('BrickWall', 'slab', 'More', at=(-8, 0, 12), size='Vector2(6, 3)', thickness='0.4', material='"brick"',
     custom_material='ExtResource("bricks")', texture_size='1.5', hp_scale='0.6')
node('FlagRed', 'flag', 'More', at=(-16, 0, 16), team='0', model='ExtResource("flagmodel")')
node('FlagBlue', 'flag', 'More', at=(16, 0, -16), team='1', model='ExtResource("flagmodel")')
# Ladders: a wooden one of your own up out of the sea (east side), the built-in one up the
# outside of the pool's back wall. A crane of your own swinging a crate; a bell (a Horn).
node('SeaLadder', 'ladder', 'More', at=(22, -3.9, 4), yaw=90, height='4.0', model='ExtResource("laddermodel")')
node('WallLadder', 'ladder', 'More', at=(-12, 0, -6.5), yaw=180, height='4.0', over_the_top='2.0')
node('Crane', 'crane', 'More', at=(-18, 0, -14), height='8.0', jib='10.0', cable='3.0', heading='60.0', sweep='50.0',
     period='30.0', load_size='Vector3(3, 1.5, 1.5)', pedestal_size='Vector3(1.4, 0, 1.4)',
     model='ExtResource("cranemodel")', load_model='ExtResource("loadmodel")')
node('Bell', 'horn', 'More', at=(3, 0, 13), model='ExtResource("bellmodel")')
# Breakable models: a door of planks, a window, a fence.
node('Door', 'bmodel', 'More', at=(14, 0, 10), model='ExtResource("doormodel")', material='"wood"')
node('Window', 'bmodel', 'More', at=(17.5, 0, 10), model='ExtResource("windowmodel")', material='"glass"')
node('Fence', 'bmodel', 'More', at=(15, 0, 4), model='ExtResource("fencemodel")', material='"wood"')
# The same door again, on a shed: the gravity gun rips it off its frame (Tear Off).
node('ShedDoor', 'bmodel', 'More', at=(20.5, 0, 10), model='ExtResource("doormodel")', material='"wood"', tear_off='true')
# Models playing their own animations (AnimatedModel): a windmill, a swinging sign, a platform
# from the south shore out over the sea and back, and a drawbridge to an islet off the east
# shore, lowered and raised with a button (Use).
node('Windmill', 'anim', 'More', at=(-17, 0, 15), model='ExtResource("windmillmodel")')
node('InnSign', 'anim', 'More', at=(-2, 0, 11), model='ExtResource("signmodel")', play='"ping pong"')
# (the ferry starts just off the shore, all of it over the sea: a deck sliding inside the
# island's floor would leave whoever stands there behind on the floor)
node('Ferry', 'anim', 'More', at=(-14, 0, 23.55), yaw=-90, model='ExtResource("platformmodel")', play='"ping pong"', speed='0.6')
node('Islet', 'block', 'Blocks', at=(31, -3, -14), size=vec(6, 6, 6), color=color(0.55, 0.55, 0.5))
node('IsletPrize', 'pickup', 'More', at=(31, 0, -14), kind='"random"')
node('BridgeButton', 'button', 'More', at=(20, 0, -11), press='"use key"', label='"Drawbridge"')
node('Drawbridge', 'anim', 'More', at=(22, 0, -14), yaw=-90, model='ExtResource("bridgemodel")', play='"once"',
     inputs='Array[NodePath]([NodePath("../BridgeButton")])')
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
