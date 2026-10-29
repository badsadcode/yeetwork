class_name Ship
extends AnimatableBody3D
## A ship riding the ocean (High Seas): heave, pitch and roll follow the ocean's long swell
## (Liquid.swell_at), sampled under the hull a moment ago (the hull's inertia). It is a
## function of the shared wave clock only, so every peer moves the ship identically without
## sending anything. Players and props ride it like any moving platform.
## The server also lets loose cargo slide and roll downhill once the deck tilts past each
## kind's grip, and pushes players a little when the deck tilts steeply.

## Hull length (along X, bow at +X) and beam (along Z) used to sample the swell.
var length := 140.0
var beam := 32.0
## Ocean surface height at rest; the ship's origin sits on the waterline.
var sea_level := 0.0
var ocean: Liquid
var world: Node
## How strongly it answers the swell (roll is amplified: ships roll more than they pitch).
var heave_gain := 0.8
var pitch_gain := 1.0
var roll_gain := 3.2
var max_roll := deg_to_rad(16.0)
var max_pitch := deg_to_rad(6.0)
## Seconds the hull lags behind the water.
var lag := 0.8
## Where on deck counts as aboard (local AABB) for sliding and pushing.
var deck_box := AABB(Vector3(-80, -2, -17), Vector3(160, 40, 34))

## Downhill slope (sin of the angle) each kind needs before it starts to move: round things
## go first, heavy flat things last. Kinds not listed use DEFAULT_GRIP.
const GRIP := {
	"ball": 0.0, "beachball": 0.0, "barrel": 0.03, "boom_barrel": 0.03, "tire": 0.05,
	"cone": 0.08, "plank": 0.09, "crate": 0.11, "crate_big": 0.13, "couch": 0.13,
	"anvil": 0.2, "flag": 0.35, "debris": 0.15, "shard": 0.15,
}
const DEFAULT_GRIP := 0.12
const SLIP_GAIN := 2.2
## Players keep their footing below this slope (about 9 degrees).
const PLAYER_GRIP := 0.16


func _ready() -> void:
	collision_layer = Game.L_WORLD
	collision_mask = 0
	sync_to_physics = true
	global_transform = pose(Liquid.wave_time())


## Where the ship is at wave time t.
func pose(t: float) -> Transform3D:
	if ocean == null:
		return Transform3D(Basis.IDENTITY, Vector3(0, sea_level, 0))
	var ts := t - lag
	var hl := length * 0.42
	var hb := beam * 0.5
	var bow := ocean.swell_at(Vector2(hl, 0), ts)
	var stern := ocean.swell_at(Vector2(-hl, 0), ts)
	var port := ocean.swell_at(Vector2(0, -hb), ts)
	var star := ocean.swell_at(Vector2(0, hb), ts)
	var mid := ocean.swell_at(Vector2.ZERO, ts)
	var heave := (bow + stern + port + star + mid * 2.0) / 6.0 * heave_gain
	# Soft limits: big swells ease into the maximum instead of hitting a hard stop.
	var pitch := max_pitch * tanh(atan2(bow - stern, hl * 2.0) * pitch_gain / max_pitch)
	var roll := max_roll * tanh(-atan2(star - port, hb * 2.0) * roll_gain / max_roll)
	var basis := Basis.from_euler(Vector3(roll, 0.0, pitch))
	return Transform3D(basis, Vector3(0, sea_level + heave, 0))


## How far the deck leans (radians).
func tilt() -> float:
	return global_transform.basis.y.angle_to(Vector3.UP)


func _physics_process(delta: float) -> void:
	global_transform = pose(Liquid.wave_time())
	if world == null:
		return
	var n := global_transform.basis.y
	var downhill := Vector3.DOWN - n * Vector3.DOWN.dot(n) # gravity along the deck
	var slope := downhill.length() # sin(tilt)
	if slope < 0.001:
		return
	var dir := downhill / slope
	var inv := global_transform.affine_inverse()
	if multiplayer.is_server():
		for p: Prop in world.props.values():
			if not is_instance_valid(p) or p.freeze or p.held_by != 0:
				continue
			var grip: float = GRIP.get(p.kind, DEFAULT_GRIP)
			if slope <= grip or not deck_box.has_point(inv * p.global_position):
				continue
			if p.get_contact_count() == 0:
				continue # in the air: gravity alone
			p.linear_velocity += dir * Player.GRAVITY * (slope - grip) * SLIP_GAIN * delta
	if slope > PLAYER_GRIP:
		for pl: Player in world.players.values():
			if pl.is_controlled_here() and pl.is_alive() and pl.is_on_floor() and deck_box.has_point(inv * pl.global_position):
				pl.velocity += dir * Player.GRAVITY * (slope - PLAYER_GRIP) * 1.5 * delta
