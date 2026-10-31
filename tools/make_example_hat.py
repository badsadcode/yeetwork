# Builds the example custom hat (a pirate tricorn) on the Yeet's head in
# art/characters/characters.blend and exports it the way docs/CHARACTERS.md describes:
# only the hat's objects, glTF binary, +Y up, into assets/characters/hats/pirate_hat.glb.
# The .blend itself isn't saved (it's made from the game's code).
#
#   blender --background art/characters/characters.blend --python tools/make_example_hat.py
import math
import os
import bpy

OUT = os.path.join(os.path.dirname(bpy.data.filepath), "..", "..", "assets", "characters", "hats", "pirate_hat.glb")
HEAD = (0.0, 0.0, 1.55)  # the head's centre on a standing Yeet (it faces +Y here)


def material(name, rgb, rough=0.7, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return m


felt = material("Felt", (0.06, 0.05, 0.06), 0.85)
gold = material("Gold", (1.0, 0.72, 0.2), 0.3, 0.8)
band = material("Shirt", (0.8, 0.2, 0.2), 0.6)  # "Shirt": the game paints it the team colour

col = bpy.data.collections.new("Pirate hat")
bpy.context.scene.collection.children.link(col)
made = []


def add(obj, mat):
    obj.data.materials.append(mat)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)
    bpy.ops.object.shade_smooth()
    made.append(obj)
    return obj


hx, hy, hz = HEAD
# The crown: a squashed dome over the top of the head.
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.34, location=(hx, hy, hz + 0.2))
crown = add(bpy.context.object, felt)
crown.scale = (1.0, 1.0, 0.82)
# The band round the crown (team colour).
bpy.ops.mesh.primitive_torus_add(major_radius=0.335, minor_radius=0.04, location=(hx, hy, hz + 0.19))
add(bpy.context.object, band)
# Three flaps turned up round it (a tricorn): one corner points forward (+Y), so the flaps
# face back and to the front corners.
for k in range(3):
    a = math.radians(180 + k * 120)  # (the middle of each flap, round the crown)
    dx, dy = math.sin(a), math.cos(a)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(hx + dx * 0.4, hy + dy * 0.4, hz + 0.26))
    flap = add(bpy.context.object, felt)
    flap.scale = (0.62, 0.05, 0.2)
    flap.rotation_euler = (math.radians(-35), 0, -a)  # tilted out, turned to face outward
    bev = flap.modifiers.new("Round", "BEVEL")
    bev.width = 0.05
    bev.segments = 4
    # A gold edge along its top.
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.016, depth=0.6,
                                        location=(hx + dx * 0.44, hy + dy * 0.44, hz + 0.355))
    trim = add(bpy.context.object, gold)
    trim.rotation_euler = (0, math.radians(90), -a)
# A gold badge on the front corner.
bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.016, location=(hx, hy + 0.33, hz + 0.3))
badge = add(bpy.context.object, gold)
badge.rotation_euler = (math.radians(90), 0, 0)

bpy.ops.object.select_all(action="DESELECT")
for o in made:
    o.select_set(True)
bpy.context.view_layer.objects.active = made[0]
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True)
print("Exported", os.path.abspath(OUT))
