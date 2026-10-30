@tool
class_name Receptacle
extends PuzzleNode
## Somewhere to bring things: a fuse box that wants its fuses, a rescue mat for Lost Yeets.
## Props of the right Kind set down (not held) inside the zone are locked in a slot for good:
## they can't be grabbed or blown away again. On once Required of them are in. The counter
## shows how many are in, and the objective can say it too: "Fuses: {count}/{required}".
## Zone: Size around this node, standing on its floor (local +Y is up).

@export_enum("fuse", "lost_yeet", "any", "crate", "crate_big", "barrel", "ball", "beachball", "anvil", "couch", "tire", "cone", "boulder") var kind := "fuse":
	set(v):
		kind = v
		_rebuild()
@export_range(1, 12, 1) var required := 1:
	set(v):
		required = v
		_rebuild()
@export var size := Vector3(3.0, 2.5, 1.6):
	set(v):
		size = v
		_rebuild()
## Over the counter, e.g. "FUSES" or "RESCUE" ("" for the kind's name).
@export var title := ""

var delivered: Array[int] = [] # prop ids, in slot order (synced as the machine state)
var _parts: Node3D
var _slot_mats: Array[StandardMaterial3D] = []
var _label: Label3D
var _flash := 0.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_slot_mats.clear()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	var mat_kind := kind == "lost_yeet"
	# A low base, one glowing socket per slot, and the counter above.
	_parts.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.1, size.z), Mats.world(Color(0.22, 0.6, 0.35) if mat_kind else Color(0.3, 0.32, 0.38), 0.6, 0.2), Vector3(0, 0.05, 0)))
	for i in required:
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		_slot_mats.append(m)
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = minf(0.42 if mat_kind else 0.3, size.x / required * 0.4)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.04
		ring.mesh = cm
		ring.material_override = m
		ring.position = slot_position(i) * Vector3(1, 0, 1) + Vector3(0, 0.12, 0)
		_parts.add_child(ring)
	_label = Label3D.new()
	_label.font_size = 72
	_label.outline_size = 16
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, size.y + 0.4, 0)
	_parts.add_child(_label)
	_tint()


## Slot i's spot (this node's space), where the prop's centre goes.
func slot_position(i: int) -> Vector3:
	var x := (i + 0.5) / required * size.x - size.x * 0.5
	var h := 0.5
	if Prop.DEFS.has(kind):
		h = (Prop.DEFS[kind].size as Vector3).y * 0.5
	return Vector3(x, 0.12 + h, 0)


func _tint() -> void:
	if _label == null:
		return
	for i in _slot_mats.size():
		var c := Color(0.35, 1.0, 0.45) if i < delivered.size() else Color(1.0, 0.7, 0.2)
		_slot_mats[i].albedo_color = c
		_slot_mats[i].emission = c
		_slot_mats[i].emission_energy_multiplier = 2.5 if i < delivered.size() else 1.0
	var t := title
	if t == "":
		t = "RESCUE" if kind == "lost_yeet" else (str(Prop.DEFS[kind].label).to_upper() + "S" if Prop.DEFS.has(kind) else "")
	_label.text = "%s  %d/%d" % [t, delivered.size(), required]
	_label.modulate = Color(0.45, 1.0, 0.55) if active else Color(1.0, 0.85, 0.35)


func objective_text() -> String:
	return objective.replace("{count}", str(delivered.size())).replace("{required}", str(required))


func is_machine() -> bool:
	return true


func machine_state() -> PackedFloat32Array:
	return PackedFloat32Array(delivered)


func apply_machine_state(s: PackedFloat32Array) -> void:
	if s.size() == delivered.size():
		return
	var before := delivered.size()
	delivered.clear()
	for v in s:
		delivered.append(int(v))
		var p: Prop = world.get_prop(int(v)) if world else null
		if p:
			p.set_meta("delivered", true)
	if delivered.size() > before:
		_flash = 1.0
		Sfx.play3d("zap", global_position, -2.0, 1.3)
	_tint()


func evaluate() -> bool:
	if delivered.size() < required:
		var inv := global_transform.affine_inverse()
		for p: Prop in world.props.values():
			if not is_instance_valid(p) or p.held_by != 0 or p.has_meta("delivered") or not (kind == "any" or p.kind == kind):
				continue
			var l: Vector3 = inv * p.global_position
			if absf(l.x) < size.x * 0.5 and absf(l.z) < size.z * 0.5 and l.y > -0.3 and l.y < size.y:
				_server_deliver(p)
				if delivered.size() >= required:
					break
	return delivered.size() >= required


## Locks the prop into the next free slot.
func _server_deliver(p: Prop) -> void:
	p.set_meta("delivered", true)
	p.freeze = true
	p.frozen_by_player = false
	p.linear_velocity = Vector3.ZERO
	p.angular_velocity = Vector3.ZERO
	p.global_transform = Transform3D(global_transform.basis.orthonormalized(), global_transform * slot_position(delivered.size()))
	world.server_fx("spawn", p.global_position, Vector3.UP, 1.0)
	delivered.append(p.prop_id)
	_flash = 1.0
	_tint()


func _state_changed(play_fx: bool) -> void:
	_tint()
	if play_fx and active:
		Sfx.play3d("zap", global_position, 0.0, 1.6)


func _process(delta: float) -> void:
	if _label == null or _flash <= 0.0:
		return
	_flash = maxf(_flash - delta * 2.0, 0.0)
	_label.scale = Vector3.ONE * (1.0 + _flash * 0.4)


func problems() -> Array[String]:
	var out := super.problems()
	if size.x < 0.5 or size.z < 0.5:
		out.append("%s: the zone is too small." % name)
	return out
