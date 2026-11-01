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
## Where it lies at rest (a Map Kit Vessel: where it was put, its bow along its +X); the swell
## is sampled under its hull there.
var home := Transform3D.IDENTITY
## High Seas' own ship: green water over the rail, rogue waves, spray off its hull (they're
## laid out for its size). A Vessel just rides the swell.
var high_seas := true
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
## The sea state (Liquid.SCULPTED key): stormy and extreme seas wash over the deck.
var sea := "ocean"
## A rogue wave's impact (wave time) and side: the ship lurches from then on, a damped roll
## and heave every peer computes from the shared clock.
var rogue_t := -1000.0
var rogue_side := 0.0
## The deck stays wet a while after green water (wave time); storms keep it wet.
var wet_until := -1000.0
var _clock := -1.0
const ROGUE_ROLL := 0.24
## Wet decks: things slide on less of a tilt (grip x this), players lose traction.
const WET_GRIP := 0.7

## Where on deck counts as aboard (local AABB) for sliding and pushing.
var deck_box := AABB(Vector3(-80, -2, -17), Vector3(160, 40, 34))
## The engine room below deck (ship-local; empty: none), and the ladders out of it (bots
## knocked down a hatch climb out).
var hold := AABB()
var hold_ladders: Array[Node3D] = []

## Downhill slope (sin of the angle) each kind needs before it starts to move: round things
## go first, heavy flat things last. Kinds not listed use DEFAULT_GRIP.
const GRIP := {
	"ball": 0.0, "beachball": 0.0, "barrel": 0.03, "boom_barrel": 0.03, "tire": 0.05,
	"cone": 0.08, "plank": 0.09, "crate": 0.11, "crate_big": 0.13, "couch": 0.13,
	"anvil": 0.2, "flag": 0.35, "debris": 0.15, "shard": 0.15, "container": 0.06,
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
		return Transform3D(home.basis, home.origin + Vector3(0, sea_level, 0))
	var ts := t - lag
	var hl := length * 0.42
	var hb := beam * 0.5
	var bow := ocean.swell_at(_flat(Vector3(hl, 0, 0)), ts)
	var stern := ocean.swell_at(_flat(Vector3(-hl, 0, 0)), ts)
	var port := ocean.swell_at(_flat(Vector3(0, 0, -hb)), ts)
	var star := ocean.swell_at(_flat(Vector3(0, 0, hb)), ts)
	var mid := ocean.swell_at(_flat(Vector3.ZERO), ts)
	var heave := (bow + stern + port + star + mid * 2.0) / 6.0 * heave_gain
	# Soft limits: big swells ease into the maximum instead of hitting a hard stop.
	var pitch := max_pitch * tanh(atan2(bow - stern, hl * 2.0) * pitch_gain / max_pitch)
	var roll := max_roll * tanh(-atan2(star - port, hb * 2.0) * roll_gain / max_roll)
	var since := t - rogue_t
	if since > 0.0 and since < 14.0: # (a rogue wave struck: she heels over away from it and rocks back)
		roll += rogue_side * ROGUE_ROLL * exp(-since * 0.4) * sin(since * 1.7)
		heave += 1.6 * exp(-since * 1.1) * sin(since * 2.4)
	var basis := Basis.from_euler(Vector3(roll, 0.0, pitch))
	return Transform3D(home.basis * basis, home.origin + Vector3(0, sea_level + heave, 0))


## A point of the hull at rest (ship-local), on the water's map (x, z).
func _flat(local: Vector3) -> Vector2:
	var p := home * local
	return Vector2(p.x, p.z)


## Wet deck: slippery (a storm's rain, green water a while ago).
func wet() -> bool:
	return (world != null and world.arena.storm) or Liquid.wave_time() < wet_until


## Which side is lower right now: +1 starboard, -1 port.
func low_side() -> float:
	var star: Vector3 = global_transform * Vector3(0, MapHighSeas.DECK, beam * 0.5)
	var port: Vector3 = global_transform * Vector3(0, MapHighSeas.DECK, -beam * 0.5)
	return 1.0 if star.y < port.y else -1.0


## Green water pours over the rail on `side` and across the deck (every peer).
func wash(side: float, center_x: float, half_width: float, strength: float) -> void:
	var w := ShipWash.new()
	w.ship = self
	w.side = side
	w.center_x = center_x
	w.half_width = half_width
	w.strength = strength
	add_child(w)
	wet_until = Liquid.wave_time() + 25.0


## A rogue wave on `side`, striking at wave time `hit` (every peer).
func rogue(side: float, hit: float) -> void:
	rogue_t = hit
	rogue_side = -side # (she heels away from it)
	var r := RogueWave.new()
	r.ship = self
	r.side = side
	r.hit_time = hit
	get_parent().add_child(r)


## How far the deck leans (radians).
func tilt() -> float:
	return global_transform.basis.y.angle_to(Vector3.UP)


func _physics_process(delta: float) -> void:
	# Its own clock, a tick at a time, eased onto the shared wave clock: that one is wall time,
	# and physics ticks don't come evenly in real time (a window catching up runs a few back to
	# back), so following it straight would move the deck in jerks and players standing on it
	# would keep losing their footing.
	var wt := Liquid.wave_time()
	if _clock < 0.0 or absf(wt - _clock) > 0.5:
		_clock = wt # (start, a wrap of the clock, or far off)
	else:
		_clock += delta
		_clock += (wt - _clock) * 0.05
	global_transform = pose(_clock)
	if world == null:
		return
	var n := global_transform.basis.y
	var downhill := Vector3.DOWN - n * Vector3.DOWN.dot(n) # gravity along the deck
	var slope := downhill.length() # sin(tilt)
	if slope < 0.001:
		return
	var dir := downhill / slope
	var inv := global_transform.affine_inverse()
	var wet := wet()
	if multiplayer.is_server():
		for p: Prop in world.props.values():
			if not is_instance_valid(p) or p.freeze or p.held_by != 0:
				continue
			var grip: float = GRIP.get(p.kind, DEFAULT_GRIP) * (WET_GRIP if wet else 1.0)
			if slope <= grip or not deck_box.has_point(inv * p.global_position):
				continue
			if p.get_contact_count() == 0:
				continue # in the air: gravity alone
			p.linear_velocity += dir * Player.GRAVITY * (slope - grip) * SLIP_GAIN * delta
	var player_grip := PLAYER_GRIP * (WET_GRIP if wet else 1.0)
	if slope > player_grip:
		for pl: Player in world.players.values():
			if pl.is_controlled_here() and pl.is_alive() and pl.is_on_floor() and deck_box.has_point(inv * pl.global_position):
				pl.velocity += dir * Player.GRAVITY * (slope - player_grip) * 1.5 * delta


## Below deck, in the engine room (a world position).
func in_hold(p: Vector3) -> bool:
	return hold.size != Vector3.ZERO and hold.has_point(global_transform.affine_inverse() * p)
