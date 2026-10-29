extends Node
## Procedurally synthesized sound effects (no audio assets needed) with a pool of 3D players.

const RATE := 22050
const POOL := 32

var _streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: AudioStreamPlayer
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 99
	_streams.jump = _make(0.12, func(t, _i): return _sine(t, lerpf(300, 620, t / 0.12)) * _env(t, 0.005, 0.11) * 0.4)
	_streams.land = _make(0.15, func(t, _i): return (_sine(t, 90) * 0.6 + _noise() * 0.4) * _env(t, 0.002, 0.14) * 0.6)
	_streams.thud = _make(0.3, func(t, _i): return (_sine(t, lerpf(120, 40, t / 0.3)) * 0.8 + _noise() * 0.5 * exp(-t * 30.0)) * _env(t, 0.001, 0.29))
	_streams.splat = _make(0.35, func(t, _i): return _noise() * (0.6 + 0.4 * sin(t * 180.0)) * _env(t, 0.002, 0.33) * 0.8 + _sine(t, lerpf(200, 60, t / 0.35)) * 0.4 * exp(-t * 12.0))
	_streams.boing = _make(0.45, func(t, _i): return _sine(t, 180.0 + 120.0 * sin(t * 40.0) * exp(-t * 4.0) + t * 200.0) * _env(t, 0.003, 0.44) * 0.5)
	_streams.zap = _make(0.18, func(t, _i): return (_saw(t, lerpf(200, 900, t / 0.18)) * 0.3 + _sine(t, lerpf(400, 1600, t / 0.18)) * 0.3) * _env(t, 0.003, 0.17))
	_streams.punt = _make(0.3, func(t, _i): return (_sine(t, lerpf(160, 50, t / 0.3)) * 0.8 + _noise() * exp(-t * 25.0) * 0.6) * _env(t, 0.001, 0.29))
	_streams.throw = _make(0.35, func(t, _i): return _noise() * sin(PI * t / 0.35) * 0.35 + _sine(t, lerpf(500, 200, t / 0.35)) * 0.15 * _env(t, 0.01, 0.34))
	_streams.boom = _make(1.2, func(t, _i): return (_noise() * exp(-t * 3.5) * 0.9 + _sine(t, lerpf(70, 30, t / 1.2)) * exp(-t * 2.5)) * _env(t, 0.001, 1.19))
	_streams.crack = _make(0.5, func(t, _i): return _noise() * (1.0 if _rng.randf() < exp(-t * 6.0) * 0.6 else 0.25) * _env(t, 0.001, 0.48) * 0.8)
	_streams.slide = _make(0.4, func(t, _i): return _noise() * 0.25 * _env(t, 0.03, 0.37))
	_streams.sizzle = _make(0.5, func(t, _i): return _noise() * (0.3 + 0.3 * float(_rng.randf() < 0.1)) * _env(t, 0.01, 0.48))
	_streams.death = _make(0.9, func(t, _i): return _sine(t, lerpf(1400, 250, pow(t / 0.9, 0.7)) + sin(t * 40.0) * 15.0) * _env(t, 0.01, 0.85) * 0.4)
	_streams.score = _make(0.6, func(t, _i): return _sine(t, [523.0, 659.0, 784.0, 1047.0][mini(int(t / 0.15), 3)]) * _env(fmod(t, 0.15), 0.005, 0.14) * 0.4)
	_streams.spawn = _make(0.25, func(t, _i): return _sine(t, lerpf(800, 300, t / 0.25)) * _env(t, 0.002, 0.24) * 0.35)
	_streams.hit = _make(0.2, func(t, _i): return (_noise() * 0.5 + _sine(t, 220)) * exp(-t * 20.0) * 0.6)
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 90.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)


func _sine(t: float, f: float) -> float:
	return sin(TAU * f * t)


func _saw(t: float, f: float) -> float:
	return fmod(t * f, 1.0) * 2.0 - 1.0


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _env(t: float, attack: float, length: float) -> float:
	if t < attack:
		return t / attack
	return clampf(1.0 - (t - attack) / maxf(length - attack, 0.001), 0.0, 1.0)


func _make(length: float, gen: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(gen.call(t, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func play3d(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound) or not is_inside_tree():
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.global_position = pos
	p.play()


func play_ui(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	_ui.stream = _streams[sound]
	_ui.volume_db = volume_db
	_ui.pitch_scale = pitch
	_ui.play()
