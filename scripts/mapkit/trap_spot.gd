@tool
class_name TrapSpot
extends PuzzleNode
## MegaYeet: a place for a trap (a box, Size, its bottom on the node). Between waves a Yeet
## builds it with Use (or from the shop), paying its Cost out of the Fortress meter (or their
## Y$, by the match's Economy); built, it works on every
## monster that walks into it until the fortress falls:
## - spikes: monsters crossing them are hurt and slowed.
## - fire: a burning grate; monsters crossing catch fire.
## - mine: blows up under the first monsters to step on it (then it's gone: build it again).
## Put them where monsters will come: behind a gate, in a passage. Not built, it shows as a
## faint outline. (On or off like any puzzle piece: on while built.)
## Your own trap (Your Own Trap): your model for it built, its name (the Use prompt, the
## shop), and what it does to a monster in it: damage a second, how fast it lets one cross,
## how long it sets one alight, how big a blast it goes off with (then it's gone). Kind gives
## the numbers you leave at -1. Save the spot as a scene (right-click > Save Branch as Scene)
## and it's a new trap you can put anywhere; the shop lists it apart, with your model.

@export_enum("spikes", "fire", "mine") var kind := "spikes":
	set(v):
		kind = v
		_rebuild()
@export var size := Vector3(4, 1, 4):
	set(v):
		size = v
		_rebuild()
## What it costs from the Fortress meter (0: the kind's usual: spikes 80, fire 120, mine 60).
@export_range(0.0, 2000.0, 5.0) var cost := 0.0

@export_group("Your own trap")
## Its name (empty: the kind's).
@export var trap_name := ""
## Your model for it, built (its origin in the middle of the spot, on the ground).
@export var model: PackedScene:
	set(v):
		model = v
		_rebuild()
## Hurt a second (-1: the kind's: spikes 30).
@export_range(-1.0, 1000.0, 1.0) var damage := -1.0
## How fast a monster crosses it, 1 full speed (-1: the kind's: spikes 0.4).
@export_range(-1.0, 1.0, 0.05) var slows_to := -1.0
## Sets them alight for this many seconds (-1: the kind's: fire 4). Fire hurts ghosts too.
@export_range(-1.0, 30.0, 0.5) var burn := -1.0
## Goes off under the first one with a blast this big (metres; -1: the kind's: a mine 6),
## then it's gone (build it again).
@export_range(-1.0, 20.0, 0.5) var blast := -1.0

const COSTS := {"spikes": 80.0, "fire": 120.0, "mine": 60.0}
const NAMES := {"spikes": "Spikes", "fire": "Fire grate", "mine": "Mine"}
## What each kind does (the numbers left at -1).
const STATS := {
	"spikes": {"damage": 30.0, "slows_to": 0.4, "burn": 0.0, "blast": 0.0},
	"fire": {"damage": 0.0, "slows_to": 1.0, "burn": 4.0, "blast": 0.0},
	"mine": {"damage": 0.0, "slows_to": 1.0, "burn": 0.0, "blast": 6.0},
}

var built := false # (server: what evaluate() says)
var owner_id := 0 # (server: who built it, for the kills)
var _parts: Node3D
var _ghost: Node3D
var _real: Node3D
var _fx: CPUParticles3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_rebuild()


func price() -> float:
	return cost if cost > 0.0 else COSTS[kind]


## Its name: yours, or the kind's.
func title() -> String:
	return trap_name if trap_name != "" else NAMES[kind]


## One of its numbers: damage, slows_to, burn, blast (yours, or the kind's).
func stat(what: String) -> float:
	var v: float = get(what)
	return v if v >= 0.0 else float(STATS[kind][what])


## What makes it a kind of trap for the shop (spots with the same name and model are one).
func type_key() -> String:
	return title() + "|" + (model.resource_path if model else kind)


func evaluate() -> bool:
	return built


func usable() -> bool:
	if active or world == null or world.mode != Game.Mode.MEGAYEET:
		return false
	return int(world.mode_state.get("phase", -1)) == ModeMegaYeet.Phase.BREAK


func use_label() -> String:
	return "Build %s  (%s)" % [title(), ModeMegaYeet.price_text(world, price())]


func use_point() -> Vector3:
	return global_position + Vector3.UP * 0.8


func server_used(pl: Player) -> void:
	var mode := world.mode_logic as ModeMegaYeet
	if mode and not built and mode.buy(pl, price(), "built %s" % title().to_lower()):
		built = true
		owner_id = pl.player_id


## Server: a mine went off (or the fortress fell): not built any more.
func server_clear() -> void:
	built = false
	owner_id = 0


## Inside its box (a world point)?
func has_point(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 and l.y >= -0.5 and l.y <= size.y + 1.0


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	_ghost = Node3D.new()
	_parts.add_child(_ghost)
	_real = Node3D.new()
	_parts.add_child(_real)
	# Not built: a faint outline on the ground, the trap's colour.
	var c := {"spikes": Color(0.8, 0.85, 0.9), "fire": Color(1.0, 0.5, 0.15), "mine": Color(1.0, 0.25, 0.2)}[kind] as Color
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(c, 0.45)
	line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var w := 0.12
	for s in [-1, 1]:
		_ghost.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.02, w), line, Vector3(0, 0.03, s * (size.z * 0.5 - w * 0.5))))
		_ghost.add_child(PuzzleNode.box_mesh(Vector3(w, 0.02, size.z), line, Vector3(s * (size.x * 0.5 - w * 0.5), 0.03, 0)))
	var mark := MeshInstance3D.new() # (a little sign in the middle: what goes here)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = 0.02
	mark.mesh = cm
	mark.position.y = 0.03
	mark.material_override = line
	_ghost.add_child(mark)
	# Built.
	var steel := Mats.plastic(Color(0.6, 0.62, 0.66), 0.3)
	var dark := Mats.plastic(Color(0.15, 0.15, 0.17), 0.7)
	match kind:
		"spikes":
			_real.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.08, size.z), dark, Vector3(0, 0.04, 0)))
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.07
			spike.height = 0.45
			spike.radial_segments = 5
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = spike
			var nx := maxi(int(size.x / 0.45), 1)
			var nz := maxi(int(size.z / 0.45), 1)
			mm.instance_count = nx * nz
			for i in nx:
				for k in nz:
					var p := Vector3((i + 0.5) / nx * size.x - size.x * 0.5, 0.3, (k + 0.5) / nz * size.z - size.z * 0.5)
					mm.set_instance_transform(i * nz + k, Transform3D(Basis.IDENTITY, p))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = steel
			_real.add_child(mmi)
		"fire":
			_real.add_child(PuzzleNode.box_mesh(Vector3(size.x, 0.1, size.z), dark, Vector3(0, 0.05, 0)))
			var bars := maxi(int(size.x / 0.35), 2)
			for i in bars:
				_real.add_child(PuzzleNode.box_mesh(Vector3(0.08, 0.06, size.z), steel, Vector3((i + 0.5) / bars * size.x - size.x * 0.5, 0.13, 0)))
			var coals := Mats.plastic(Color(1.0, 0.35, 0.05), 0.5, 2.5)
			_real.add_child(PuzzleNode.box_mesh(Vector3(size.x * 0.9, 0.04, size.z * 0.9), coals, Vector3(0, 0.1, 0)))
		"mine":
			var disc := MeshInstance3D.new()
			var dm := CylinderMesh.new()
			dm.top_radius = 0.45
			dm.bottom_radius = 0.55
			dm.height = 0.18
			disc.mesh = dm
			disc.position.y = 0.09
			disc.material_override = dark
			_real.add_child(disc)
			var lamp := Mats.plastic(Color(1.0, 0.15, 0.1), 0.3, 3.0)
			_real.add_child(PuzzleNode.box_mesh(Vector3(0.12, 0.08, 0.12), lamp, Vector3(0, 0.22, 0)))
	if not Engine.is_editor_hint():
		if kind == "fire":
			_fx = CPUParticles3D.new()
			_fx.amount = 24
			_fx.lifetime = 0.8
			_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			_fx.emission_box_extents = Vector3(size.x * 0.45, 0.05, size.z * 0.45)
			_fx.direction = Vector3.UP
			_fx.spread = 10.0
			_fx.initial_velocity_min = 1.0
			_fx.initial_velocity_max = 2.2
			_fx.gravity = Vector3(0, 1.0, 0)
			_fx.scale_amount_min = 0.3
			_fx.scale_amount_max = 0.6
			var q := QuadMesh.new()
			_fx.mesh = q
			var fm := StandardMaterial3D.new()
			fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.vertex_color_use_as_albedo = true
			_fx.material_override = fm
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.7, 0.2, 0.9))
			g.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
			_fx.color_ramp = g
			_fx.position.y = 0.15
			_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_fx.emitting = false
			_real.add_child(_fx)
		if kind != "spikes":
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.45, 0.15) if kind == "fire" else Color(1.0, 0.15, 0.1)
			_light.omni_range = 4.0 if kind == "fire" else 2.0
			_light.light_energy = 1.5 if kind == "fire" else 0.6
			_light.position.y = 0.6
			_real.add_child(_light)
	Looks.apply(_real, MapTheme.pick(self, "trap_" + kind, model)) # (its lights and flames stay)
	_show()


func _state_changed(play_fx: bool) -> void:
	_show()
	if play_fx and is_inside_tree():
		Sfx.play3d("metal" if active else "hit", global_position + Vector3.UP * 0.5, -2.0, 0.8 if active else 1.2)
		if active and world:
			world.fx.puffs(global_position + Vector3.UP * 0.3, Vector3.UP, 10, [Color(0.8, 0.8, 0.8, 0.6), Color(0.6, 0.6, 0.6, 0.0)], 0.3, 0.7, 1.0, 2.5, 1.0)


func _show() -> void:
	if _real == null:
		return
	var on := active or Engine.is_editor_hint()
	_real.visible = on
	_ghost.visible = not active
	if _fx:
		_fx.emitting = active


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not active or kind != "mine" or _light == null:
		return
	_t += delta
	_light.light_energy = 0.6 if fmod(_t, 1.0) < 0.5 else 0.05
