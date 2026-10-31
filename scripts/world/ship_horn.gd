class_name ShipHorn
extends PuzzleNode
## The ship's horn on the bridge's console (High Seas): walk up and press Use to sound it, a
## deep blast everyone hears. A lever on a post; not too often (a few seconds between blasts).

const COOLDOWN := 4.0

var _next := 0.0
var _lever: Node3D


func _ready() -> void:
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.12
	pm.height = 1.0
	post.mesh = pm
	post.position = Vector3(0, 0.5, 0)
	post.material_override = Mats.plastic(Color(0.3, 0.32, 0.36), 0.4)
	add_child(post)
	_lever = Node3D.new()
	_lever.position = Vector3(0, 1.0, 0)
	add_child(_lever)
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.06, 0.4, 0.06)
	arm.mesh = am
	arm.position = Vector3(0, 0.2, 0)
	arm.material_override = Mats.plastic(Color(0.75, 0.76, 0.8), 0.3)
	_lever.add_child(arm)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.08
	km.height = 0.16
	knob.mesh = km
	knob.position = Vector3(0, 0.42, 0)
	knob.material_override = Mats.plastic(Color(0.85, 0.12, 0.1), 0.2)
	_lever.add_child(knob)
	_lever.rotation.z = -0.4


func usable() -> bool:
	return true


func use_label() -> String:
	return "Sound the horn"


func use_point() -> Vector3:
	return _lever.global_position + global_transform.basis.y * 0.3 if _lever else global_position


func server_used(_pl: Player) -> void:
	if world == null or world.now() < _next:
		return
	_next = world.now() + COOLDOWN
	world.server_fx("ship_horn", use_point(), Vector3.UP, 1.0)


## (World: on every peer when it sounds) the lever pulled down and back.
func pull() -> void:
	if _lever:
		var tw := create_tween()
		tw.tween_property(_lever, "rotation:z", 0.5, 0.12)
		tw.tween_interval(1.6)
		tw.tween_property(_lever, "rotation:z", -0.4, 0.4)
