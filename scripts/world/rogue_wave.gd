class_name RogueWave
extends Node3D
## A rogue wave bearing down on the ship (High Seas): a long wall of water rises out of the
## sea on one side and runs at the hull until `hit_time` (wave time), when it breaks over the
## whole deck (a ShipWash at strength 3) and the ship lurches (Ship.rogue_t). World starts it
## on every peer with a warning.

var ship: Ship
var side := 1.0
var hit_time := 0.0
var _start := 0.0
var _wall: MeshInstance3D
var _mat: ShaderMaterial
var _broke := false

const RUN := 5.0 # seconds from first sight to impact
const FROM := 120.0 # metres off the hull at first sight


func _ready() -> void:
	top_level = true
	_start = hit_time - RUN
	_wall = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 32
	cm.rings = 2
	_wall.mesh = cm
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/world/green_water.gdshader")
	_mat.set_shader_parameter("clarity", 0.15)
	_mat.set_shader_parameter("water", Color(0.05, 0.3, 0.36))
	_mat.render_priority = 2 # (after the ocean, which writes depth: only the part above the sea shows)
	_wall.material_override = _mat
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)
	_place()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	var t := Liquid.wave_time()
	var u := clampf((t - _start) / RUN, 0.0, 1.0)
	if t >= hit_time and not _broke:
		_broke = true
		var w := ShipWash.new()
		w.ship = ship
		w.side = side
		w.center_x = 0.0
		w.half_width = 70.0
		w.strength = 3.0
		w.duration = 1.4
		ship.add_child(w)
		var mid: Vector3 = ship.global_transform * Vector3(0, MapHighSeas.DECK, side * 16.0)
		Sfx.play3d("boom", mid, 6.0, 0.45)
		Sfx.play3d("thunder", mid, 2.0, 1.3)
		var lp = ship.world.local_player
		if lp:
			lp.shake(0.9)
	# Rising and running in, then sinking away past the hull.
	var after := maxf(t - hit_time, 0.0)
	if after > 2.5:
		queue_free()
		return
	var height := lerpf(1.0, 11.0, smoothstep(0.0, 0.7, u)) * (1.0 - clampf(after / 1.5, 0.0, 1.0))
	var dist := lerpf(FROM, 14.0, u) - after * 12.0
	var xf: Transform3D = ship.global_transform
	var at := xf * Vector3(0, 0, side * (16.0 + dist))
	at.y = height * 0.35 - 1.0
	_wall.global_transform = Transform3D(xf.basis.orthonormalized() * Basis(Vector3(0, 0, 1), PI * 0.5) * Basis.from_scale(Vector3(height, 230.0, height * 1.5)), at)
	_mat.set_shader_parameter("flow", -side)
	_mat.set_shader_parameter("fade", clampf(u * 3.0, 0.0, 1.0) * (1.0 - clampf(after / 2.0, 0.0, 1.0)))
