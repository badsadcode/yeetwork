class_name VolleyHalf
extends GoalZone
## One half of a YeetVolley court (made by its VolleyNet, not placed by hand): a "goal" in
## the sense the sports share, defended by its team. The ball landing in it scores for the
## other team; its mouth is the middle of the half, its +Z faces the net.

var net: VolleyNet


func _rebuild() -> void:
	pass # (the VolleyNet draws the court)


func contains_ball(_p: Vector3, _r: float) -> bool:
	return false


func mouth() -> Vector3:
	return global_position + Vector3.UP * 1.0
