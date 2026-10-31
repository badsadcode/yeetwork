class_name ShipWash
extends Node3D
## Green water over the deck (High Seas): a surge of sea pours in over the low side's rail and
## runs across the deck to the other side in `duration` seconds, over a stretch `half_width`
## either side of `center_x` (ship-local). Whoever it reaches is shoved along with it (the peer
## that controls them; props on the server), harder for a bigger wave (`strength`: 1 a wash
## in a storm, 3 a rogue wave, which knocks Yeets down); fires it passes are put out. World
## starts it on every peer.

var ship: Ship
var side := 1.0 # where it comes in: +1 starboard (+z), -1 port
var center_x := 0.0
var half_width := 12.0
var strength := 1.0
var duration := 1.6
var _t := 0.0
var _hit := {}
var _sheet: MeshInstance3D
var _mat: ShaderMaterial

const BEAM := 15.6 # (inside the rails)


func _ready() -> void:
	_sheet = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half_width * 2.0, 0.9 + strength * 0.35, 3.5 + strength)
	_sheet.mesh = bm
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/world/green_water.gdshader")
	_mat.set_shader_parameter("flow", -side)
	_mat.render_priority = 2 # (over the sea and the spray)
	_sheet.material_override = _mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	_place(0.0)
	# It breaks over the rail: spray along it, and the roar.
	var world = ship.world
	var rail := MapHighSeas.DECK + 1.2
	var x := center_x - half_width
	while x <= center_x + half_width:
		var at: Vector3 = ship.global_transform * Vector3(x, rail, side * 16.0)
		world.fx.splash(at, 6.0 + strength * 4.0, Color(0.6, 0.85, 0.9))
		x += 5.0
	var mid: Vector3 = ship.global_transform * Vector3(center_x, rail, side * 16.0)
	Sfx.play3d("splash", mid, 6.0 + strength * 3.0, 0.7 / sqrt(strength))
	Sfx.play3d("whoosh", mid, 2.0 + strength * 2.0, 0.6)


func _physics_process(delta: float) -> void:
	_t += delta
	var u := _t / duration
	if u >= 1.0:
		queue_free()
		return
	_place(u)
	var world = ship.world
	var inv := ship.global_transform.affine_inverse()
	var front := side * BEAM - side * BEAM * 2.0 * u
	var push: Vector3 = ship.global_transform.basis * Vector3(0, 0, -side)
	for pl: Player in world.players.values():
		if _hit.has(pl) or not pl.is_controlled_here() or not pl.is_alive():
			continue
		if _reached(inv * pl.global_position, front):
			_hit[pl] = true
			# (a hurricane's wash takes you off your feet; a rogue wave sends you flying)
			var knock := 1.3 if strength >= 2.0 else (0.6 if strength >= 1.5 else 0.0)
			# (harder for bigger waves, but not linearly: a rogue wave throws you over the far
			# rail, not a hundred metres out to sea)
			var k := sqrt(strength)
			pl.external_launch(push * 9.0 * k + Vector3.UP * 3.0 * k, false, knock)
	if world.multiplayer.is_server():
		for p: Prop in world.props.values():
			if _hit.has(p) or not is_instance_valid(p) or p.freeze:
				continue
			if _reached(inv * p.global_position, front):
				_hit[p] = true
				p.linear_velocity += push * 8.0 * strength + Vector3.UP * 2.0 * strength
				p.sleeping = false
				if world.is_burning(p):
					world._server_put_out(0, p.prop_id, p.global_position)


## Within the stretch, on deck, and the surge front at it right now.
func _reached(local: Vector3, front: float) -> bool:
	return absf(local.x - center_x) < half_width and absf(local.z - front) < 1.6 + strength * 0.4 \
		and local.y > MapHighSeas.DECK - 1.0 and local.y < MapHighSeas.DECK + 3.0 + strength


func _place(u: float) -> void:
	var front := side * BEAM - side * BEAM * 2.0 * u
	_sheet.position = Vector3(center_x, MapHighSeas.DECK + 0.3 + strength * 0.15 - u * 0.3, front)
	_mat.set_shader_parameter("fade", clampf((1.0 - u) * 1.6, 0.0, 1.0))
