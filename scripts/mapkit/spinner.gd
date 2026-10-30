class_name Spinner
extends Node3D
## Slowly turns its children around its local Y axis in game (decorations: Prime's orb ring,
## Facing's crystal). Visual only: put no collision under it.

@export var speed := 0.4 # radians per second


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_object_local(Vector3.UP, delta * speed)
