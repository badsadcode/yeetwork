@tool
class_name PuzzleNode
extends Node3D
## Base of the puzzle pieces (PressurePlate, PuzzleDoor, PuzzleLogic, Checkpoint, PuzzleExit).
## Every piece is on or off. The server decides (World checks the pieces ten times a second)
## and every player sees the same. Pieces with Inputs turn on from other pieces: a door
## opens while its plates are pressed.

## Other puzzle pieces that switch this one on.
@export var inputs: Array[NodePath] = []
## all: every input must be on (AND). any: one is enough (OR).
@export_enum("all", "any") var combine := "all"
## Once on, stay on (a door that stays open after the puzzle is solved).
@export var latch := false
## In the Puzzle mode, shown at the top of the screen while this piece is still off, e.g.
## "Open the gate" (the first unfinished objective in the scene is shown).
@export var objective := ""

var active := false
var puzzle_index := -1
var world: Node


## The objective as shown (a Receptacle fills in its count).
func objective_text() -> String:
	return objective


## After the map is built (BreakableSlabs have become Destructibles): find what you watch.
func link() -> void:
	pass


## Machines (seesaws, turntables) move every frame: the server simulates them and streams
## their state (machine_state) to everyone about 20 times a second.
func is_machine() -> bool:
	return false


func machine_state() -> PackedFloat32Array:
	return PackedFloat32Array()


## Clients: the latest state from the server (smooth toward it yourself).
func apply_machine_state(_s: PackedFloat32Array) -> void:
	pass


## Server, once the match starts: spawn the props this piece brings (a fan).
func server_spawn_props() -> void:
	pass


## Pieces players press with the Use key (E): the Reset button, use-key buttons.
func usable() -> bool:
	return false


## What the prompt says: "[E] <use_label>".
func use_label() -> String:
	return "Use"


## Where the player has to look (world space).
func use_point() -> Vector3:
	return global_position


## Server: a player pressed Use on this piece.
func server_used(_pl: Player) -> void:
	pass


## Server: this piece just switched (on every peer already).
func server_switched(_on: bool) -> void:
	pass


## The state the server wants this piece in now (inputs by default).
func evaluate() -> bool:
	return inputs_on()


func inputs_on() -> bool:
	if inputs.is_empty():
		return false
	var all := true
	var any := false
	for np in inputs:
		var n := get_node_or_null(np) as PuzzleNode
		var on := n != null and n.active
		all = all and on
		any = any or on
	return all if combine == "all" else any


## Every peer: the synced state changed (play_fx: false when joining a match in progress).
func set_active(on: bool, play_fx := true) -> void:
	if on == active:
		return
	active = on
	_state_changed(play_fx)


func _state_changed(_play_fx: bool) -> void:
	pass


## Problems for --validate.
func problems() -> Array[String]:
	var out: Array[String] = []
	for np in inputs:
		if not get_node_or_null(np) is PuzzleNode:
			out.append("%s: input %s is not a puzzle piece." % [name, np])
	return out


static func box_mesh(size: Vector3, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	return mi


## Players (alive) inside a box of `size` centred at `center` (this piece's space).
func players_in(center: Vector3, size: Vector3) -> Array:
	var out := []
	if world == null:
		return out
	var inv := global_transform.affine_inverse()
	for pl: Player in world.players.values():
		if not pl.is_alive():
			continue
		var p: Vector3 = inv * pl.body_center() - center
		if absf(p.x) < size.x * 0.5 and absf(p.y) < size.y * 0.5 and absf(p.z) < size.z * 0.5:
			out.append(pl)
	return out
