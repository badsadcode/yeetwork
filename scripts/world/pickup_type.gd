@tool
class_name PickupType
extends Resource
## Your own pickup, next to the built-in ones: a first aid kit or a power-up with your model,
## name and numbers. Gives: what it does (health heals; speed, super, feather, iron give that
## boost, see Pickups). Make one: right-click a folder > Create New > Resource > PickupType,
## fill it in, and put it on a PickupSpawn's Type slot.
## - Model: what floats over the pad (its origin in its middle; about half a metre across).
## - Everything at 0 is the built-in one's.

@export var display_name := ""
@export_enum("health", "speed", "super", "feather", "iron") var gives := "health"
## Health it gives back (health only; 0: 50).
@export_range(0.0, 100.0, 1.0) var heal := 0.0
## Seconds the boost lasts (power-ups; 0: the boost's usual).
@export_range(0.0, 120.0, 0.5) var lasts := 0.0
## Seconds until it's back after someone takes it (0: the usual).
@export_range(0.0, 300.0, 1.0) var respawn := 0.0
@export var model: PackedScene
## The glowing ring under it (and the HUD's colour for it; clear: the boost's).
@export var color := Color(0, 0, 0, 0)
