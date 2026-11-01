class_name Spinner
extends Node3D
## Slowly turns its children around its local Y axis in game (decorations: Prime's orb ring,
## Facing's crystal). Visual only: put no collision under it.

## How fast it turns its children about its Y, radians a second (negative: the other way).
@export var speed := 0.4


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_object_local(Vector3.UP, delta * speed)
