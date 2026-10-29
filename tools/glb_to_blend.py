"""Turns the exported characters.glb into an organized .blend for customizing characters.

    blender --background --python tools/glb_to_blend.py -- <characters.glb> <out.blend> [preview.png]

Collections: Body (the base character), Hats/<hat>, Head extras/<extra>, Outfits/<outfit>,
Characters/<character> (whole special characters, e.g. Noor Yeet, standing beside the body). Every hat and head
extra sits on the head already; show one of each (eye icon) to compose a character.
The game still builds characters in code (scripts/player/character_model.gd); this file is
the editable copy of the same parts, for making new hats and extras or replacing parts.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
glb, out_blend = argv[0], argv[1]
preview = argv[2] if len(argv) > 2 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
scene = bpy.context.scene
root_coll = scene.collection


def top_group(obj):
    """Returns (category, group) from the object's ancestry: Body / Hats->Hat_X / HeadExtras->Extra_X."""
    chain = []
    o = obj
    while o:
        chain.append(o.name)
        o = o.parent
    chain.reverse()
    if "Hats" in chain:
        i = chain.index("Hats")
        return "Hats", chain[i + 1] if i + 1 < len(chain) else None
    if "Characters" in chain:
        i = chain.index("Characters")
        return "Characters", chain[i + 1] if i + 1 < len(chain) else None
    if "Outfits" in chain:
        i = chain.index("Outfits")
        return "Outfits", chain[i + 1] if i + 1 < len(chain) else None
    if "HeadExtras" in chain:
        i = chain.index("HeadExtras")
        return "Head extras", chain[i + 1] if i + 1 < len(chain) else None
    if "Body" in chain:
        return "Body", None
    return None, None


def nice(name):
    """'Hat-Top_hat' -> 'Top hat'."""
    return name.split("-", 1)[-1].split(".")[0].replace("_", " ")


colls = {}


def coll(path):
    if path in colls:
        return colls[path]
    parent = root_coll if "/" not in path else coll(path.rsplit("/", 1)[0])
    c = bpy.data.collections.new(path.rsplit("/", 1)[-1])
    parent.children.link(c)
    colls[path] = c
    return c


for obj in list(bpy.data.objects):
    cat, group = top_group(obj)
    if cat is None:
        continue
    target = coll(cat if group is None else f"{cat}/{nice(group)}")
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    target.objects.link(obj)

# Show the body with one hat and no extra; everything else is one click away.
shown = {"Hats/Top hat"}
layer = bpy.context.view_layer
for path, c in colls.items():
    if "/" in path:
        hidden = path not in shown
        c.hide_render = hidden

        def find(lc):
            if lc.collection == c:
                return lc
            for ch in lc.children:
                r = find(ch)
                if r:
                    return r
            return None
        lc = find(layer.layer_collection)
        if lc:
            lc.hide_viewport = hidden

# Turntable-ready camera and lights for previews.
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
cam.location = (0.0, 5.2, 1.4)  # characters face +Y here (Godot's -Z)
cam.rotation_euler = (1.5, 0.0, 3.14159)
cam.data.lens = 70
root_coll.objects.link(cam)
scene.camera = cam
sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
sun.data.energy = 3.5
sun.data.color = (1.0, 0.87, 0.7)
sun.rotation_euler = (0.9, 0.2, 2.6)
root_coll.objects.link(sun)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
fill.data.energy = 1.2
fill.data.color = (0.55, 0.68, 1.0)
fill.rotation_euler = (1.1, 0.0, -0.5)
root_coll.objects.link(fill)
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.4, 0.62, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scene.world = world
scene.render.resolution_x = 900
scene.render.resolution_y = 1100

bpy.ops.wm.save_as_mainfile(filepath=out_blend)
print("Saved", out_blend)
if preview:
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("Rendered", preview)
