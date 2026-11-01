@tool
class_name PropType
extends Resource
## Your own prop, next to the built-in ones: a new crate, barrel, ball... It behaves like the
## built-in prop you pick (Behaves Like: a crate breaks into boards, a boom barrel blows up, a
## beach ball floats down, a battery powers a socket) with your model and your numbers.
## Make one: right-click a folder > Create New > Resource > PropType, save it next to your
## model, fill it in, and put it on a Prop Spawn's Type slot.
## - Model: its origin in the middle of the prop (where it turns about).
## - Size: the box it fills, in metres (0: the built-in one's); its collision is that box, a
##   ball or a cylinder (Shape), or a mesh named "Collision" in your model (hidden in the game,
##   made convex: keep it to a simple shape).
## - Everything at 0 (or -1) is the built-in one's.

@export var display_name := ""
@export_enum("crate", "crate_big", "barrel", "boom_barrel", "ball", "beachball", "anvil", "plank", "couch", "tire", "cone", "fuse", "boulder", "platform", "battery", "gravestone", "coffin", "pumpkin", "iron_ball") var behaves_like := "crate"
@export var model: PackedScene
@export var size := Vector3.ZERO
## auto: the "Collision" mesh in your model if it has one, otherwise the built-in one's shape.
@export_enum("auto", "box", "ball", "cylinder") var shape := "auto"
## Kilograms (a crate 25, a barrel 40, an anvil 300; one gun lifts up to about 400).
@export_range(0.0, 3000.0, 0.5) var mass := 0.0
## 0 dead, 1 a superball (-1: the built-in one's).
@export_range(-1.0, 1.0, 0.05) var bounce := -1.0
## How hard a hit it takes to break it (impact energy, joules: a crate 9000, a barrel 15000);
## only for props that break (crates, barrels, planks, pumpkins, gravestones, coffins).
@export_range(0.0, 100000.0, 100.0) var toughness := 0.0
@export var unbreakable := false
## When it breaks, it comes apart into its model's parts (each object in it: a plank, a pane,
## a hinge, named for what they're made of like a BreakableModel's: "Glass_", "Wood_",
## "Metal_"...): each flies off whole (a prop), glass shatters; instead of the built-in one's
## way of breaking. Behaves Like has to be a prop that breaks (a crate, a plank...).
@export var breaks_into_parts := false
## The colour of what it breaks into, and of the built-in look if there's no model.
@export var color := Color(0, 0, 0, 0)


static var _parts := {} # path -> [model instance, parts]


## Its model's parts, every peer the same: [mesh, where it sits in the model, what it's made
## of] each (not the Collision mesh).
static func parts_of(path: String) -> Array:
	if _parts.has(path):
		return _parts[path][1]
	var out := []
	var t := load(path) as PropType if ResourceLoader.exists(path) else null
	var root: Node = t.model.instantiate() if t and t.model else null
	if root:
		var base := "metal" if Prop.DEFS.get(t.behaves_like, {}).get("metal", false) else "wood"
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var names := ModelDestructible._names(mi, root).to_lower()
			if mi.mesh == null or names.contains("collision"):
				continue
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != root:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var word := ModelDestructible._word(names)
			out.append([mi, xf, word if word != "" else base])
	_parts[path] = [root, out]
	var tree := Engine.get_main_loop() as SceneTree
	if tree and root is Node3D:
		(root as Node3D).visible = false
		tree.root.add_child.call_deferred(root)
	return out


## The built-in prop's numbers with yours on top (what Prop.def is).
func def() -> Dictionary:
	var base: Dictionary = Prop.DEFS.get(behaves_like, Prop.DEFS.crate)
	var d := base.duplicate()
	if display_name != "":
		d.label = display_name
	var sh: String = {"box": "box", "ball": "sphere", "cylinder": "cyl"}.get(shape, base.shape)
	if size != Vector3.ZERO or sh != base.shape:
		var box := size if size != Vector3.ZERO else _to_box(base.size, base.shape)
		d.shape = sh
		d.size = _from_box(box, sh)
	if mass > 0.0:
		d.mass = mass
	if bounce >= 0.0:
		d.bounce = bounce
	if unbreakable:
		d.erase("fragile")
	elif toughness > 0.0 and d.has("fragile"):
		d.fragile = toughness
	if color.a > 0.0:
		d.color = color
	return d


## A box (the size it fills) in a shape's own terms: a ball's or a cylinder's is radius,
## height, radius.
static func _from_box(box: Vector3, sh: String) -> Vector3:
	match sh:
		"sphere", "pumpkin":
			var r := maxf(box.x, maxf(box.y, box.z)) * 0.5
			return Vector3(r, r, r)
		"cyl", "cone", "fuse", "yeet":
			return Vector3(box.x * 0.5, box.y, box.z * 0.5)
	return box


static func _to_box(s: Vector3, sh: String) -> Vector3:
	match sh:
		"sphere", "pumpkin":
			return Vector3.ONE * s.x * 2.0
		"cyl", "cone", "fuse", "yeet":
			return Vector3(s.x * 2.0, s.y, s.z * 2.0)
	return s
