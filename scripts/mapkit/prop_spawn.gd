@tool
class_name PropSpawn
extends Node3D
## A physics prop placed in the map. Map props respawn at this spot after they are
## destroyed or fall out of the world.

@export_enum("crate", "crate_big", "barrel", "boom_barrel", "ball", "beachball", "anvil", "plank", "couch", "tire", "cone", "fuse", "lost_yeet") var kind := "crate":
	set(v):
		kind = v
		_rebuild()

## A prop a puzzle needs: comes back here 2.5 s after it's destroyed or falls out of the
## level (other map props take 10-25 s), and a PuzzleReset puts it back home.
@export var key_prop := false

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()


func _rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		add_child(_preview, false, Node.INTERNAL_MODE_FRONT)
	var def: Dictionary = Prop.DEFS[kind]
	var s: Vector3 = def.size
	match def.shape:
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = s.x
			sm.height = s.x * 2.0
			_preview.mesh = sm
		"yeet":
			var cap := CapsuleMesh.new()
			cap.radius = s.x
			cap.height = s.y
			_preview.mesh = cap
		"cyl", "cone", "fuse":
			var cm := CylinderMesh.new()
			cm.top_radius = s.x if def.shape == "cyl" else 0.05
			cm.bottom_radius = s.x
			cm.height = s.y
			_preview.mesh = cm
		_:
			var bm := BoxMesh.new()
			bm.size = s
			_preview.mesh = bm
	_preview.material_override = Mats.plastic(def.color, 0.4)
