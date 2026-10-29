"""Builds the gravity gun in Blender: art/gravity_gun/gravity_gun.blend and the game model
assets/models/gravity_gun.glb (plus an optional preview render).

    blender --background --python tools/make_gravity_gun.py -- <repo root> [preview.png]

Chunky toy sci-fi style: a faceted yellow drum, a glowing blue core in the front ring,
three dark claws with glowing pads, a red energy cell with a glowing tube, a yellow end cap,
a carry handle, a red knob, a black grip with a red trigger and hoses.
The gun points along +Y (glTF/Godot: -Z). Nodes the game animates:
  Muzzle (where the beam starts), Core (pulses), ClawPivot0..2 > ClawHinge (opens around X).
Orange parts use the "Accent" material: the game tints it with the team colour.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
root = argv[0]
preview = argv[1] if len(argv) > 1 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
        m.surface_render_method = "BLENDED"
    return m


YELLOW = mat("Yellow", (1.0, 0.62, 0.08), 0.55)
ACCENT = mat("Accent", (1.0, 0.36, 0.04), 0.5)
DARK = mat("Dark", (0.06, 0.06, 0.075), 0.6)
RED = mat("Red", (0.75, 0.04, 0.05), 0.45)
STEEL = mat("Steel", (0.62, 0.64, 0.68), 0.3, 0.85)
GLOW = mat("Glow", (0.1, 0.5, 1.0), 0.3, emit=(0.1, 0.55, 1.0), strength=4.0)
GLASS = mat("Glass", (0.55, 0.85, 1.0), 0.05, alpha=0.35)


def finish(obj, material, bevel=0.008, parent=None):
    obj.data.materials.append(material)
    if bevel > 0.0:
        m = obj.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 2
        m.limit_method = "ANGLE"
    if parent:
        obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def cyl(name, r, depth, loc, material, verts=10, bevel=0.008, axis="Y", parent=None, r2=None):
    rot = (math.pi / 2, 0, 0) if axis == "Y" else ((0, math.pi / 2, 0) if axis == "X" else (0, 0, 0))
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, material, bevel, parent)


def box(name, size, loc, material, rot=(0, 0, 0), bevel=0.008, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, bevel, parent)


def torus(name, r, thick, loc, material, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, location=loc, rotation=(math.pi / 2, 0, 0), major_segments=32, minor_segments=8)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    if parent:
        o.parent = parent
    return o


def empty(name, loc, parent=None, rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    o.rotation_euler = rot
    o.empty_display_size = 0.05
    scene.collection.objects.link(o)
    if parent:
        o.parent = parent
    return o


gun = empty("GravityGun", (0, 0, 0))

# --- Front: ring housing, glowing core, brackets ---------------------------------------
cyl("FrontRing", 0.17, 0.11, (0, 0.24, 0), YELLOW, verts=12, parent=gun)
cyl("FrontRim", 0.145, 0.03, (0, 0.305, 0), DARK, verts=24, bevel=0.004, parent=gun)
cyl("CoreDisc", 0.12, 0.02, (0, 0.31, 0), GLOW, verts=32, bevel=0.0, parent=gun)
torus("CoreRing1", 0.09, 0.008, (0, 0.322, 0), mat("GlowBright", (0.4, 0.85, 1.0), 0.3, emit=(0.35, 0.85, 1.0), strength=6.0), parent=gun)
torus("CoreRing2", 0.055, 0.007, (0, 0.322, 0), DARK, parent=gun)
core = bpy.data.objects.new("Core", None)
# The pulsing core: a glowing ball in the middle of the disc.
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(0, 0.315, 0), segments=16, ring_count=8)
core = bpy.context.object
core.name = "Core"
core.data.materials.append(mat("CoreGlow", (0.5, 0.9, 1.0), 0.2, emit=(0.45, 0.9, 1.0), strength=7.0))
core.parent = gun
empty("Muzzle", (0, 0.36, 0), gun)
for i in range(4):
    a = math.pi / 4 + i * math.pi / 2
    box(f"Bracket{i}", (0.06, 0.13, 0.05), (math.cos(a) * 0.175, 0.24, math.sin(a) * 0.175), ACCENT, rot=(0, -a, 0), parent=gun)
    cyl(f"BracketBolt{i}", 0.012, 0.02, (math.cos(a) * 0.2, 0.24, math.sin(a) * 0.2), DARK, verts=8, bevel=0.0, axis="X", parent=gun).rotation_euler = (0, -a + math.pi / 2, 0)

# --- Claws: three pivots around the barrel, each with a hinge that opens ---------------
for i in range(3):
    a = math.pi / 2 + i * 2 * math.pi / 3  # first claw on top
    pivot = empty(f"ClawPivot{i}", (0, 0.26, 0), gun, rot=(0, -(a - math.pi / 2), 0))
    hinge = empty("ClawHinge", (0, 0, 0.17), pivot)
    hinge.name = f"ClawHinge{i}"
    box("Knuckle", (0.07, 0.07, 0.06), (0, 0.02, 0.0), ACCENT, parent=hinge)
    box("Arm", (0.035, 0.16, 0.035), (0, 0.1, 0.03), DARK, rot=(0.35, 0, 0), parent=hinge)
    box("Elbow", (0.05, 0.05, 0.05), (0, 0.18, 0.06), ACCENT, parent=hinge)
    tip = box("Tip", (0.09, 0.14, 0.055), (0, 0.27, 0.05), DARK, rot=(-0.25, 0, 0), bevel=0.012, parent=hinge)
    box("TipGlow", (0.022, 0.1, 0.012), (0, 0.27, 0.018), GLOW, rot=(-0.25, 0, 0), bevel=0.0, parent=hinge)

# --- Body: faceted drum with a warning sign, dark band ----------------------------------
cyl("Drum", 0.2, 0.28, (0, 0.04, 0), YELLOW, verts=10, bevel=0.012, parent=gun)
cyl("DrumLip", 0.185, 0.03, (0, 0.18, 0), DARK, verts=10, parent=gun)
cyl("Band", 0.17, 0.06, (0, -0.13, 0), DARK, verts=12, parent=gun)
for side in (-1, 1):
    # Warning sign: dark triangle with a yellow inset and a dark bar.
    sx = side * 0.197
    tri = bpy.data.meshes.new("Warning")
    s = 0.055
    pts = [(0, 0, s), (0, -s * 0.9, -s * 0.6), (0, s * 0.9, -s * 0.6)]
    tri.from_pydata(pts, [], [(0, 1, 2) if side > 0 else (0, 2, 1)])
    o = bpy.data.objects.new("Warning", tri)
    o.location = (sx + side * 0.004, 0.06, 0.03)
    o.data.materials.append(DARK)
    o.parent = gun
    scene.collection.objects.link(o)
    box("WarningMark", (0.004, 0.012, 0.035), (sx + side * 0.006, 0.06, 0.035), YELLOW, bevel=0.0, parent=gun)
box("TopPlate", (0.14, 0.2, 0.04), (0, 0.04, 0.2), ACCENT, parent=gun)

# --- Rear: red energy cell with a glowing tube, rods, end cap ----------------------------
cyl("CellFront", 0.165, 0.045, (0, -0.18, 0), RED, verts=12, parent=gun)
cyl("CellBack", 0.165, 0.045, (0, -0.4, 0), RED, verts=12, parent=gun)
cyl("CellTube", 0.11, 0.18, (0, -0.29, 0), GLASS, verts=24, bevel=0.0, parent=gun)
cyl("CellGlow", 0.07, 0.17, (0, -0.29, 0), GLOW, verts=16, bevel=0.0, parent=gun)
for i in range(4):
    a = math.pi / 4 + i * math.pi / 2
    cyl(f"Rod{i}", 0.014, 0.2, (math.cos(a) * 0.135, -0.29, math.sin(a) * 0.135), STEEL, verts=8, bevel=0.0, parent=gun)
box("CellBar", (0.06, 0.22, 0.05), (0, -0.29, 0.155), RED, parent=gun)
cyl("EndCap", 0.18, 0.1, (0, -0.47, 0), YELLOW, verts=10, bevel=0.012, parent=gun)
cyl("EndPlate", 0.12, 0.03, (0, -0.53, 0), DARK, verts=16, parent=gun)
for i in range(4):
    a = i * math.pi / 2
    cyl(f"EndBolt{i}", 0.018, 0.02, (math.cos(a) * 0.15, -0.525, math.sin(a) * 0.15), DARK, verts=8, bevel=0.0, parent=gun)
cyl("Knob", 0.045, 0.05, (0, -0.42, 0.205), RED, verts=12, axis="Z", parent=gun)
cyl("KnobTop", 0.03, 0.02, (0, -0.42, 0.24), RED, verts=12, axis="Z", parent=gun)

# --- Carry handle, grip, trigger, hoses ------------------------------------------------
for y in (-0.06, -0.26):
    box(f"HandlePost{y}", (0.045, 0.045, 0.1), (0, y, 0.24), DARK, parent=gun)
box("HandleBar", (0.05, 0.25, 0.045), (0, -0.16, 0.3), DARK, parent=gun)
box("HandleCapF", (0.06, 0.05, 0.03), (0, -0.04, 0.32), ACCENT, parent=gun)
box("Grip", (0.075, 0.1, 0.22), (0, -0.36, -0.25), DARK, rot=(-0.3, 0, 0), bevel=0.012, parent=gun)
box("GripBase", (0.085, 0.13, 0.03), (0, -0.4, -0.36), DARK, rot=(-0.3, 0, 0), parent=gun)
box("Trigger", (0.025, 0.035, 0.08), (0, -0.27, -0.2), RED, rot=(0.25, 0, 0), parent=gun)
box("TriggerGuard", (0.03, 0.14, 0.02), (0, -0.28, -0.25), DARK, parent=gun)
for i, x in enumerate((-0.05, 0.05)):
    curve = bpy.data.curves.new(f"Hose{i}", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.02
    curve.bevel_resolution = 2
    sp = curve.splines.new("BEZIER")
    sp.bezier_points.add(1)
    p0, p1 = sp.bezier_points
    p0.co = (x, 0.12, -0.17)
    p0.handle_left = (x, 0.16, -0.12)
    p0.handle_right = (x, 0.08, -0.32)
    p1.co = (x * 0.8, -0.3, -0.16)
    p1.handle_left = (x * 0.8, -0.1, -0.36)
    p1.handle_right = (x * 0.8, -0.35, -0.1)
    o = bpy.data.objects.new(f"Hose{i}", curve)
    o.data.materials.append(DARK)
    o.parent = gun
    scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o.select_set(False)

bpy.ops.object.select_all(action="DESELECT")
blend_path = f"{root}/art/gravity_gun/gravity_gun.blend"
import os
os.makedirs(os.path.dirname(blend_path), exist_ok=True)
os.makedirs(f"{root}/assets/models", exist_ok=True)

# Preview camera and lights (kept in the .blend).
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
cam.location = (1.7, 0.9, 0.55)
cam.data.lens = 40
scene.collection.objects.link(cam)
track = cam.constraints.new("TRACK_TO")
track.target = gun
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
sun.data.energy = 3.5
sun.data.color = (1.0, 0.88, 0.72)
sun.rotation_euler = (0.8, 0.3, 1.2)
scene.collection.objects.link(sun)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
fill.data.energy = 1.2
fill.data.color = (0.5, 0.65, 1.0)
fill.rotation_euler = (1.0, 0.0, -2.0)
scene.collection.objects.link(fill)
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.16, 0.35, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
scene.world = world
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = 1200
scene.render.resolution_y = 800
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print("Saved", blend_path)

# Game model: everything under GravityGun, modifiers applied.
for o in scene.objects:
    o.select_set(o == gun or o.parent is not None and o.type in ("MESH", "EMPTY") and o.name not in ("Camera",))
glb = f"{root}/assets/models/gravity_gun.glb"
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_cameras=False, export_lights=False)
print("Exported", glb)
if preview:
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print("Rendered", preview)
