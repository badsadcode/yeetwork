@tool
class_name PropSpawn
extends Node3D
## A physics prop placed in the map. Map props respawn at this spot after they are
## destroyed or fall out of the world.

@export_enum("crate", "crate_big", "barrel", "boom_barrel", "ball", "beachball", "anvil", "plank", "couch", "tire", "cone") var kind := "crate":
	set(v):
		kind = v
		_rebuild()

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
		"cyl", "cone":
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
