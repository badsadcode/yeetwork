@tool
class_name BreakableModel
extends Node3D
## Your own model, breakable: a door of planks, a window (frame, glass, bars), a fence. Every
## separate part of it (every object in Blender: a plank, a pane, a post, a knob) breaks on
## its own, and how it breaks comes from its name:
## - What it's made of: "glass", "wood", "metal", "stone", "concrete", "brick", "plaster" or
##   "ice" anywhere in its name ("Glass_Pane", "Wood_Plank3"): how tough, how it shatters
##   (glass into thin shards, wood into splinters along the part's longest side), its sound.
##   A part named none of them: Material below.
## - "Fixed" in its name ("Fixed_Frame"): it never breaks (and holds up what touches it).
## - "Collision": hidden (use it in a prop, not here).
## Parts hold onto the fixed parts, the ground (the model's lowest parts, with Anchor To
## Ground) and each other; a part left holding onto nothing falls off whole (a prop: grab it,
## throw it). A small part (under 0.3 m: a knob, a hinge) comes off whole when hit. The pieces
## of a broken part are cut from its own shape, from the hit outward, in its own material.
## Works like a BreakableSlab: everyone sees the same, monsters batter it (a MegaYeet gate),
## the shop repairs it, wood burns. Tear Off: the gravity gun rips it off (a door off its
## hinges): its loose parts (not the Fixed ones) come away together as one prop to carry and
## throw, and thrown hard it comes apart into its parts.

## Your model (.glb, .blend, .tscn): every separate part breaks on its own, named for what it's
## made of (see above).
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()
## What a part with no material in its name is made of.
@export_enum("wood", "glass", "metal", "concrete", "brick", "plaster", "ice") var material := "wood"
## Toughness: multiplies every part's material (0.5 half as tough, 10 ten times).
@export_range(0.1, 50.0, 0.05, "or_greater") var hp_scale := 1.0
## Its lowest parts stand on the ground and hold up the rest (a fence's posts, a door's
## frame); off: only the Fixed parts hold it (a sign hanging from a fixed bracket).
@export var anchor_to_ground := true
## The gravity gun can rip it off: its loose parts come away together as one prop.
@export var tear_off := false
## The dust when a part breaks, and the colour fire and fragments fall back to.
@export var color := Color(0.6, 0.45, 0.3)

var _preview: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview:
		_preview.queue_free()
		_preview = null
	if model:
		_preview = model.instantiate() as Node3D
		if _preview:
			add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
