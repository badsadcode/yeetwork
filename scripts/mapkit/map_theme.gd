@tool
class_name MapTheme
extends Resource
## A map's look in one file: a model for each kind of Map Kit piece and prop. Pick it in
## MapSettings > Theme and every jump pad, button, pipe, crate... on the map takes that look.
## Make one per theme (haunted, foundry, beach...): right-click a folder > Create New >
## Resource > MapTheme, then drag your models (.glb/.gltf/.blend/.tscn) onto the slots.
## - A piece's own Model slot wins over the theme; an empty theme slot keeps the built-in look.
## - Only the look changes: pieces work the same, props weigh and collide the same.
## - Moving parts are found by name in the model (see docs/MAPPING.md, "Themes"): a button's
##   "Cap", a plate's "Plate", a float switch's "Float", a valve's "Wheel", a seesaw's "Plank",
##   a reset post's "Cap", a volley net's "Net".

@export_group("Movement")
@export var jump_pad: PackedScene
@export var lift: PackedScene
@export var grapple_point: PackedScene
@export var rope_anchor: PackedScene

@export_group("Puzzle pieces")
@export var button: PackedScene
@export var pressure_plate: PackedScene
@export var door: PackedScene
@export var target: PackedScene
@export var receptacle: PackedScene
@export var exit: PackedScene
@export var checkpoint: PackedScene
@export var reset_post: PackedScene
@export var seesaw: PackedScene
@export var turntable: PackedScene
@export var pulley: PackedScene
@export var magnet: PackedScene

@export_group("Water, fire, power")
@export var valve: PackedScene
@export var drain: PackedScene
@export var float_switch: PackedScene
@export var beacon: PackedScene
@export var contacts: PackedScene

@export_group("Modes")
@export var flag_stand: PackedScene
@export var goal: PackedScene
@export var hoop: PackedScene
@export var volley_net: PackedScene

@export_group("Pickups")
@export var pickup_pad: PackedScene
@export var pickup_health: PackedScene
@export var pickup_health_big: PackedScene
@export var pickup_speed: PackedScene
@export var pickup_super: PackedScene
@export var pickup_feather: PackedScene
@export var pickup_iron: PackedScene

@export_group("Props")
@export var crate: PackedScene
@export var crate_big: PackedScene
@export var barrel: PackedScene
@export var boom_barrel: PackedScene
@export var ball: PackedScene
@export var beachball: PackedScene
@export var anvil: PackedScene
@export var plank: PackedScene
@export var couch: PackedScene
@export var tire: PackedScene
@export var cone: PackedScene
@export var boulder: PackedScene
@export var pumpkin: PackedScene
@export var gravestone: PackedScene
@export var coffin: PackedScene
@export var battery: PackedScene
@export var fuse: PackedScene
@export var fan: PackedScene
@export var flag: PackedScene
@export var yeetball: PackedScene
@export var basketball: PackedScene
@export var volleyball: PackedScene


## The theme of the map a node is part of (null: none). Looks for the map's MapSettings up
## the node's ancestors (in the editor and in the game).
static func of(n: Node) -> MapTheme:
	var a := n
	while a:
		for c in a.get_children():
			if c is MapSettings:
				return (c as MapSettings).theme
		if a.owner == null and not (a is Window): # a scene's root (or made in code): look all through it
			var s := _find_settings(a)
			if s:
				return s.theme
		a = a.get_parent()
		if a is Window:
			break
	return null


static func _find_settings(n: Node) -> MapSettings:
	for c in n.get_children():
		if c is MapSettings:
			return c
		var s := _find_settings(c)
		if s:
			return s
	return null


## The scene to show for a piece: its own model, else the map theme's (key: a slot above),
## else null (the built-in look).
static func pick(n: Node, key: String, own: PackedScene = null) -> PackedScene:
	if own:
		return own
	var t := of(n)
	return t.get(key) as PackedScene if t and key in t else null


## The theme's model for a prop kind (null: the built-in look).
func prop_model(kind: String) -> PackedScene:
	return get(kind) as PackedScene if kind in self else null
