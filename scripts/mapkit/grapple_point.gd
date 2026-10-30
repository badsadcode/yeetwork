@tool
class_name GrapplePoint
extends Node3D
## A ring to grapple onto. On maps whose MapSettings Grapple is "grapple points" the hook
## only takes hold on these (and on props and friends); aiming near one is enough.
## Hang them from ceilings, beams and ledge edges.

var _parts: Node3D


func _ready() -> void:
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.34
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.material_override = Mats.plastic(Color(1.0, 0.78, 0.2), 0.3, 1.2)
	_parts.add_child(ring)
	var mount := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.5
	mount.mesh = cm
	mount.position.y = 0.55
	mount.material_override = Mats.plastic(Color(0.35, 0.37, 0.42), 0.4)
	_parts.add_child(mount)
	if not Engine.is_editor_hint():
		add_to_group("grapple_points")
