class_name ShipCrane
extends Node3D
## A deck crane (High Seas): it slews to and fro on its own, and from the end of its jib a load
## hangs on a cable, swinging out as she rolls. It all runs off the ship's clock, so every peer
## sees the same crane with nothing sent. The load is solid: ride it, or get swept off a
## container stack when it comes round (a knock, harder the faster it's going; on the peer
## that controls you, like a wash). Its machinery house on the pedestal is a Fixture
## (MapHighSeas). Placed ship-local on the deck, a child of the ship. Off a ship (the Map Kit's
## Crane piece) it runs off the match clock and the load hangs plumb.
## model: your own crane instead of the built-in one: a part named "Turret" slews (its jib
## along the Turret's +X), an empty "Hook" on it is where the cable hangs from. load_model:
## what hangs (in a box of load_size, its origin in the middle).

var ship: Ship
var world: Node # (off a ship: the match, for the clock and the Yeets it sweeps)
var model: PackedScene
var load_model: PackedScene
var height := 12.0 # the pedestal's top above the deck
var jib := 14.0
var cable := 3.0
var slew_center := PI # the jib's heading (ship-local; 0: toward the bow), and how far it sweeps
var slew_amp := 1.2
var period := 48.0 # (a sweep there and back)
var swing := 1.8 # (how far the load swings out, over the tilt she has)
var load_size := Vector3(6.1, 2.6, 2.44) # a 20 ft container
var load_color := Color(0.95, 0.55, 0.1)

const YELLOW := Color(0.95, 0.75, 0.15)

var _slew: Node3D
var _slew_base := 0.0 # (a model's Turret: its own heading, the sweep goes on top)
var _hook: Node3D
var _cable: MeshInstance3D
var _load: AnimatableBody3D
var _prev := Vector3.INF
var _knocked := {} # player -> when
var _t := 0.0


func _ready() -> void:
	if world == null and ship:
		world = ship.world
	var yellow := Mats.world(YELLOW, 0.6)
	if model:
		_own_model()
	else:
		_built_in(yellow)
	# The cable and its load (in the world: it hangs plumb, not with the ship's tilt).
	_cable = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.0
	cyl.radial_segments = 6
	_cable.mesh = cyl
	_cable.material_override = Mats.world(Color(0.15, 0.15, 0.17), 0.4)
	_cable.top_level = true
	add_child(_cable)
	_load = AnimatableBody3D.new()
	_load.collision_layer = Game.L_WORLD
	_load.collision_mask = 0
	_load.sync_to_physics = true
	_load.top_level = true
	var look := load_model.instantiate() as Node3D if load_model else null
	if look:
		_load.add_child(look)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = load_size
		mi.mesh = bm
		mi.material_override = MapHighSeas.container_material(load_color)
		_load.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = load_size
	cs.shape = sh
	_load.add_child(cs)
	add_child(_load)
	_place()


## Your own crane: its Turret slews, its Hook holds the cable (no Turret: it stands still and
## the cable hangs from the Hook, or the jib's end).
func _own_model() -> void:
	var m := model.instantiate() as Node3D
	add_child(m)
	_slew = Looks.part(m, "Turret")
	_hook = Looks.part(m, "Hook")
	if _slew:
		_slew_base = _slew.rotation.y
	else:
		_slew = Node3D.new()
		_slew.position.y = height + 1.8
		add_child(_slew)


func _built_in(yellow: Material) -> void:
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 1.1
	cm.height = height
	ped.mesh = cm
	ped.position.y = height * 0.5
	ped.material_override = yellow
	add_child(ped)
	# The slewing part: a turntable, the jib (a lattice of two booms), its stay to a short mast.
	_slew = Node3D.new()
	_slew.position.y = height + 1.8
	add_child(_slew)
	_part(_slew, Vector3(0, -0.15, 0), Vector3(2.2, 0.3, 2.2), yellow)
	for s in [-0.35, 0.35]:
		_part(_slew, Vector3(jib * 0.5, 0.3, s), Vector3(jib, 0.3, 0.15), yellow)
	for i in int(jib / 1.4):
		_part(_slew, Vector3(0.7 + i * 1.4, 0.3, 0), Vector3(0.08, 0.3, 0.7), yellow)
	_part(_slew, Vector3(0, 1.5, 0), Vector3(0.4, 3.0, 0.4), yellow)
	var stay := _part(_slew, Vector3(jib * 0.5, 1.65, 0), Vector3(Vector2(jib, 2.7).length(), 0.06, 0.06), Mats.world(Color(0.2, 0.2, 0.22), 0.5))
	stay.rotation.z = -atan2(2.7, jib)
	_part(_slew, Vector3(jib, 0.0, 0), Vector3(0.6, 0.5, 0.9), Mats.world(Color(0.2, 0.2, 0.22), 0.5)) # (the sheave)


func _part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	var was := _load.global_position
	_place()
	if world == null or delta <= 0.0:
		return
	var vel := (_load.global_position - was) / delta
	_knock(vel)


## Where everything is right now, from the ship's clock (off a ship: the match's).
func _place() -> void:
	var t: float = ship._clock if ship else (world.net_time() if world else 0.0)
	var heading := slew_center + slew_amp * sin(TAU * t / period)
	_slew.rotation.y = _slew_base + heading
	var tip := global_transform * (_slew.position + Basis(Vector3.UP, heading) * Vector3(jib, -0.2, 0))
	if _hook:
		tip = _hook.global_position
	# Plumb, swung out past it by how she's tilting, and a little pendulum of its own.
	var down := Vector3.DOWN
	if ship:
		var local := ship.global_transform.basis.inverse() * Vector3.DOWN
		local.x *= swing
		local.z *= swing
		down = (ship.global_transform.basis * local).normalized()
	var w := sqrt(9.8 / cable)
	down = (down + Vector3(sin(t * w) * 0.06, 0, cos(t * w * 0.83) * 0.06)).normalized()
	var top := tip + down * cable
	var along := global_transform.basis * (Basis(Vector3.UP, heading) * Vector3.RIGHT)
	along.y = 0.0
	var yaw := atan2(-along.x, -along.z)
	# (hung crosswise under the jib, tipped with the cable)
	var b := Basis(Vector3.UP, yaw)
	var tilt := Quaternion(Vector3.DOWN, down)
	_load.global_transform = Transform3D(Basis(tilt) * b, top + down * load_size.y * 0.5)
	var span := tip.distance_to(top)
	var y := (top - tip) / maxf(span, 0.01)
	var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.9 else y.cross(Vector3.RIGHT).normalized()
	_cable.global_transform = Transform3D(Basis(x, y * span, x.cross(y)), (tip + top) * 0.5)


## Swept by the load: a Yeet it catches (from the side, not one riding on top) is knocked
## along with it.
func _knock(vel: Vector3) -> void:
	var speed := vel.length()
	if speed < 1.2:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var inv := _load.global_transform.affine_inverse()
	var half := load_size * 0.5
	for pl: Player in world.players.values():
		if not pl.is_controlled_here() or not pl.is_alive() or now - float(_knocked.get(pl, -10.0)) < 1.0:
			continue
		var l := inv * pl.body_center()
		if absf(l.x) < half.x + 0.6 and absf(l.z) < half.z + 0.6 and l.y > -half.y - 1.0 and l.y < half.y:
			_knocked[pl] = now
			var push := vel.normalized()
			push.y = 0.0
			pl.external_launch(push.normalized() * (4.0 + speed * 2.0) + Vector3.UP * 3.0, false, 1.0 if speed > 2.5 else 0.0)
			Sfx.play3d("metal", pl.body_center(), 0.0, 0.7)
