@tool
class_name BreakableSlab
extends Node3D
## A destructible wall, floor or bridge. In game it becomes an irregular fractured slab.
## WALL: the slab stands upright, width along local X, height along local Y, thickness
## along local Z. FLOOR: lies flat, length along local X, width along local -Z.
## The editor preview shows the fracture style (the in-game pattern is seeded per map).

enum Layout { WALL, FLOOR }

@export var orientation: Layout = Layout.WALL:
	set(v):
		orientation = v
		_rebuild()
## Width x height (WALL) or length x width (FLOOR), meters.
@export var size := Vector2(6, 3):
	set(v):
		size = v.max(Vector2.ONE * 0.5)
		_rebuild()
@export_range(0.05, 3.0, 0.05) var thickness := 0.6:
	set(v):
		thickness = v
		_rebuild()
@export_enum("plaster", "concrete", "brick", "wood", "glass", "metal", "ice") var material := "plaster":
	set(v):
		material = v
		_rebuild()
@export var color := Color(0.95, 0.86, 0.66):
	set(v):
		color = v
		_rebuild()
## Edges attached to the world. Pieces cut off from every anchored edge fall/crumble.
@export var anchor_bottom := true
@export var anchor_top := false
@export var anchor_left := false
@export var anchor_right := false
## Multiplies the material's toughness.
@export_range(0.1, 5.0, 0.05) var hp_scale := 1.0

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func slab_basis() -> Basis:
	var b := global_transform.basis.orthonormalized()
	if orientation == Layout.FLOOR:
		b = b * Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return b


func anchors() -> Array:
	var a := []
	if anchor_bottom:
		a.append("bottom")
	if anchor_top:
		a.append("top")
	if anchor_left:
		a.append("left")
	if anchor_right:
		a.append("right")
	return a


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var md := Fracture.mat(material)
	var cells: float = (size.x * size.y) / (md.cell.x * md.cell.y)
	if cells > 900:
		push_warning("%s: ~%d fracture cells is a lot; consider splitting the slab or a coarser material." % [name, int(cells)])
	var v := Fracture.voronoi(size.x, size.y, md, 12345)
	var mb := Fracture.MeshBuilder.new()
	for poly in v.polys:
		mb.add_prism(Fracture.jagged(poly, size.x, size.y, md.jag), thickness * 0.5, -thickness * 0.5)
	_preview.mesh = mb.commit(Mats.slab(color, material), Mats.slab(color, material, true))
	_preview.transform = Transform3D.IDENTITY if orientation == Layout.WALL else Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
