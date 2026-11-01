class_name ModelDestructible
extends Destructible
## A breakable model (the Map Kit's BreakableModel): a door, a window, a fence you modelled,
## each separate part of it (each mesh: a plank, a pane, a post, a knob) one cell of a
## Destructible, so it breaks, syncs, is battered by monsters and repaired like a slab.
## A part's name says what it's made of ("Glass_Pane", "Wood_Plank3": glass, wood, metal,
## stone, concrete, brick, plaster, ice; none: the piece's Material) and a part named
## "Fixed..." never breaks (a window's frame). Broken, a part shatters into pieces cut from
## its own outline from the hit outward (Fracture.shatter in its own plane: its two longest
## sides, the longest along the grain), in its own material; a small one (a knob) comes off
## whole. Parts hold onto the fixed parts and the ground (its lowest parts) and onto each
## other; a part left holding onto nothing falls off whole, a prop you can grab.

## A part this small (its longest side, metres) comes off whole instead of shattering.
const SMALL := 0.3
const WORDS := ["glass", "wood", "metal", "stone", "concrete", "brick", "plaster", "ice"]

var part_meshes: Array[MeshInstance3D] = []
var part_frames: Array[Transform3D] = [] # (local) a part's plane: its outline in XY, thickness along Z
var part_thick := PackedFloat32Array()
var part_mats := PackedStringArray()
var part_c3 := PackedVector3Array() # (local) its middle
var part_r := PackedFloat32Array() # half its longest side
var part_small := PackedByteArray()
var part_rect: Array[Rect2] = [] # its outline's box in its own plane
var _box := AABB()
var _hp_scale := 1.0


## Builds it from `model` (already instanced; it's added here as it is).
func setup_model(id: int, model: Node3D, p_material: String, p_color: Color, hp_scale: float, ground := true) -> void:
	wall_id = id
	_hp_scale = hp_scale
	material = p_material
	matdef = Fracture.mat(material)
	color = p_color
	name = "D%d" % id
	add_child(model)
	var inv := global_transform.affine_inverse()
	var boxes: Array[AABB] = []
	var fixed_boxes: Array[AABB] = []
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var lower := _names(mi, model).to_lower()
		if lower.contains("collision"):
			mi.visible = false
			continue
		var xf := inv * mi.global_transform
		var box := xf * mi.get_aabb()
		_box = box if first else _box.merge(box)
		first = false
		if lower.contains("fixed"):
			fixed_boxes.append(box)
			_fixed_body(mi, xf)
			continue
		_add_part(mi, xf, _word(lower))
		boxes.append(box)
	size = Vector2(_box.size.x, _box.size.y)
	thickness = maxf(_box.size.z, 0.05)
	var count := cells.size()
	_hp.resize(count)
	_alive.resize(count)
	_anchored.resize(count)
	damage.resize(count)
	neighbors.resize(count)
	var floor_y := _box.position.y + 0.05
	for i in count:
		_hp[i] = Fracture.mat(part_mats[i]).hp * hp_scale
		_alive[i] = 1
		var held := ground and boxes[i].position.y <= floor_y
		for f in fixed_boxes:
			if boxes[i].grow(0.03).intersects(f):
				held = true
		_anchored[i] = 1 if held else 0
		var near := PackedInt32Array()
		for j in count:
			if j != i and boxes[i].grow(0.03).intersects(boxes[j]):
				near.append(j)
		neighbors[i] = near
		_bodies.append(_make_body(i))
	max_hp = matdef.hp * hp_scale
	_radius = 0.1 # (distances are to the parts themselves)


## What its node and its parents up to the model are called (a Blender object's name can
## sit on the mesh or on a parent).
static func _names(n: Node, top: Node) -> String:
	var out := ""
	while n and n != top:
		out += String(n.name) + " "
		n = n.get_parent()
	return out


static func _word(lower: String) -> String:
	for w: String in WORDS:
		if lower.contains(w):
			return "concrete" if w == "stone" else w
	return ""


## A part: its plane (its two longest sides; the longest along Y, the grain), its outline
## there (the hull of its vertices), its thickness.
func _add_part(mi: MeshInstance3D, xf: Transform3D, word: String) -> void:
	var aabb := mi.get_aabb()
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var lens := []
	for k in 3:
		lens.append(aabb.size[k] * (xf.basis * axes[k]).length())
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return lens[a] > lens[b])
	var uy: Vector3 = (xf.basis * axes[order[0]]).normalized() # the longest: the grain
	var ux: Vector3 = (xf.basis * axes[order[1]]).normalized()
	var uz := ux.cross(uy).normalized()
	var center := xf * aabb.get_center()
	var frame := Transform3D(Basis(ux, uy, uz), center)
	var pts := PackedVector2Array()
	var finv := frame.affine_inverse()
	for s in mi.mesh.get_surface_count():
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var l := finv * (xf * v)
			pts.append(Vector2(l.x, l.y))
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	if hull.size() < 3:
		var hw: float = lens[order[1]] * 0.5
		var hh: float = lens[order[0]] * 0.5
		hull = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	var rect := Rect2(hull[0], Vector2.ZERO)
	for p in hull:
		rect = rect.expand(p)
	part_rect.append(rect)
	cells.append(hull)
	outlines.append(hull)
	centers.append(Fracture.centroid(hull))
	areas.append(Fracture.area(hull))
	part_meshes.append(mi)
	part_frames.append(frame)
	part_thick.append(maxf(float(lens[order[2]]), 0.01))
	part_mats.append(word if word != "" else material)
	part_c3.append(center)
	part_r.append(float(lens[order[0]]) * 0.5)
	part_small.append(1 if float(lens[order[0]]) < SMALL else 0)


## A fixed part: solid, never breaks.
func _fixed_body(mi: MeshInstance3D, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	cs.transform = xf
	body.add_child(cs)
	add_child(body)


func _make_body(i: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Game.L_WORLD
	body.collision_mask = 0
	body.set_meta("destructible", self)
	body.set_meta("cell", i)
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = Fracture.prism_points(cells[i], part_thick[i])
	cs.shape = shape
	cs.transform = part_frames[i]
	body.add_child(cs)
	add_child(body)
	return body


## How far a point (local) is from the part itself (its box in its own frame): a hit on one
## plank isn't a hit on the plank next to it.
func _distance(local: Vector3, i: int) -> float:
	var l := part_frames[i].affine_inverse() * local
	var r := part_rect[i]
	var dx := maxf(maxf(r.position.x - l.x, l.x - r.end.x), 0.0)
	var dy := maxf(maxf(r.position.y - l.y, l.y - r.end.y), 0.0)
	var dz := maxf(absf(l.z) - part_thick[i] * 0.5, 0.0)
	return Vector3(dx, dy, dz).length()


func cell_world(i: int) -> Vector3:
	return global_transform * part_c3[i]


func island_center(island: PackedInt32Array) -> Vector2:
	var c := Vector3.ZERO
	for i in island:
		c += part_c3[i]
	c /= maxf(island.size(), 1.0)
	return Vector2(c.x, c.y)


func cell_frame(i: int) -> Transform3D:
	return global_transform * part_frames[i]


func cell_thickness(i: int) -> float:
	return part_thick[i]


func cell_material(i: int) -> String:
	return part_mats[i]


func cell_matdef(i: int) -> Dictionary:
	return Fracture.mat(part_mats[i])


## The part's own material (its pieces look like it).
func cell_face(i: int) -> Material:
	var mi := part_meshes[i]
	if mi.material_override:
		return mi.material_override
	if mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0):
		return mi.get_surface_override_material(0)
	return mi.mesh.surface_get_material(0) if mi.mesh.get_surface_count() > 0 else null


func cell_side(i: int) -> Material:
	return cell_face(i)


func fragment_extra(i: int) -> Dictionary:
	return {"t": part_thick[i], "mat": part_mats[i], "mwall": wall_id, "part": i}


func has_material(m: String) -> bool:
	for i in cells.size():
		if part_mats[i] == m and is_alive(i):
			return true
	return false


func bounds() -> AABB:
	return _box


## A part comes off whole (a knob, or one left hanging onto nothing): where its mesh is.
func part_transform(i: int) -> Transform3D:
	return part_meshes[i].global_transform


func remove_cells(list: PackedInt32Array) -> void:
	super(list)
	for i in list:
		part_meshes[i].visible = false


func restore_all() -> void:
	super()
	for i in cells.size():
		_hp[i] = Fracture.mat(part_mats[i]).hp * _hp_scale
		part_meshes[i].visible = true


func _rebuild_mesh() -> void:
	pass # (its parts are its own meshes)
