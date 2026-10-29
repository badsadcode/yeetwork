extends Node
## Procedurally synthesized sound effects (no audio assets). Each sound has several
## variants so repeated hits never sound identical. Impacts are layered by material and
## energy: a transient (click/crunch), a material body (stone grit, wood knock, metal
## ring, flesh smack) and, for heavy hits, a sub-bass thud. Everything runs through an
## "SFX" bus with compression and a touch of reverb so hits feel weighty.

const RATE := 22050
const POOL := 40
const VARIANTS := 4

var _streams := {} # name -> Array[AudioStreamWAV]
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: AudioStreamPlayer
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 99
	_setup_buses()
	_add("thud", 0.5, _thud.bind(75.0, 38.0, 9.0))
	_add("thud_heavy", 1.0, _thud_heavy)
	_add("land", 0.25, _thud.bind(110.0, 60.0, 18.0))
	_add("smack", 0.3, _smack)
	_add("crunch", 0.35, _crunch)
	_add("stone", 0.45, _stone)
	_add("wood", 0.4, _wood)
	_add("metal", 1.0, _metal)
	_add("boing", 0.45, _boing)
	_add("glass", 0.7, _glass)
	_add("splat", 0.45, _splat)
	_add("crack", 0.6, _crack)
	_add("splinter", 0.5, _splinter)
	_add("creak", 0.8, _creak)
	_add("boom", 1.6, _boom)
	_add("punt", 0.45, _punt)
	_add("throw", 0.4, _whoosh.bind(0.4))
	_add("whoosh", 0.6, _whoosh.bind(0.6))
	_add("jump", 0.14, _blip.bind(300.0, 620.0, 0.14, 0.35))
	_add("zap", 0.2, _zap)
	_add("spawn", 0.25, _blip.bind(800.0, 300.0, 0.25, 0.3))
	_add("slide", 0.45, _slide)
	_add("sizzle", 0.6, _sizzle)
	_add("death", 0.9, _death)
	_add("score", 0.6, _score)
	_add("squelch", 0.6, _squelch)
	_add("pickup", 0.18, _blip.bind(900.0, 1500.0, 0.18, 0.3))
	_add("wind", 4.0, _wind)
	for w: AudioStreamWAV in _streams.wind:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = w.data.size() / 2 - int(RATE * 0.5) # see _wind crossfade
	_streams.hit = _streams.smack
	_streams.clang = _streams.metal
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 9.0
		p.max_distance = 110.0
		p.attenuation_filter_cutoff_hz = 7000.0
		p.attenuation_filter_db = -18.0
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	_ui.bus = "SFX"
	add_child(_ui)


func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -16.0
	comp.ratio = 4.0
	comp.attack_us = 2000.0
	comp.release_ms = 180.0
	comp.gain = 4.0
	AudioServer.add_bus_effect(idx, comp)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.6
	rev.wet = 0.12
	rev.dry = 1.0
	AudioServer.add_bus_effect(idx, rev)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, lim)


# --- Synthesis helpers --------------------------------------------------------------

func _add(sound: String, length: float, gen: Callable) -> void:
	var list: Array[AudioStreamWAV] = []
	for v in VARIANTS:
		var n := int(length * RATE)
		var buf := PackedFloat32Array()
		buf.resize(n)
		gen.call(buf, v)
		list.append(_to_wav(buf))
	_streams[sound] = list


func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		# Gentle saturation adds punch without hard clipping.
		var v := tanh(buf[i] * 1.3) / tanh(1.3)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _lp_noise(n: int, cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in n:
		y += (_rng.randf_range(-1.0, 1.0) - y) * a
		out[i] = y
	# Normalize-ish: lowpassed noise loses amplitude.
	var g := clampf(sqrt(1.0 / maxf(a, 0.001)) * 0.6, 1.0, 12.0)
	for i in n:
		out[i] *= g
	return out


func _bp_noise(n: int, center: float) -> PackedFloat32Array:
	var lo := _lp_noise(n, center * 1.6)
	var lo2 := _lp_noise(n, center * 0.6)
	for i in n:
		lo[i] -= lo2[i] * 0.8
	return lo


## Sine with exponentially falling pitch (the core of every thud).
func _drop(buf: PackedFloat32Array, f_start: float, f_end: float, pitch_rate: float, decay: float, amp: float) -> void:
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := f_end + (f_start - f_end) * exp(-t * pitch_rate)
		phase += TAU * f / RATE
		buf[i] += sin(phase) * exp(-t * decay) * amp


func _modes(buf: PackedFloat32Array, freqs: Array, decay: float, amp: float) -> void:
	for k in freqs.size():
		var f: float = freqs[k] * _rng.randf_range(0.96, 1.04)
		var d := decay * (1.0 + k * 0.35)
		var a := amp / (1.0 + k * 0.6)
		for i in buf.size():
			var t := float(i) / RATE
			buf[i] += sin(TAU * f * t) * exp(-t * d) * a


func _add_noise(buf: PackedFloat32Array, noise: PackedFloat32Array, decay: float, amp: float, attack := 0.0) -> void:
	for i in buf.size():
		var t := float(i) / RATE
		var env := exp(-t * decay)
		if attack > 0.0 and t < attack:
			env *= t / attack
		buf[i] += noise[i] * env * amp


func _vr(v: int, spread: float) -> float:
	return 1.0 + (v - (VARIANTS - 1) * 0.5) * spread


# --- Sounds ------------------------------------------------------------------------

func _thud(buf: PackedFloat32Array, v: int, f0: float, f1: float, decay: float) -> void:
	_drop(buf, f0 * 2.2 * _vr(v, 0.08), f1 * _vr(v, 0.05), 28.0, decay, 0.95)
	_add_noise(buf, _lp_noise(buf.size(), 1400.0), 55.0, 0.6)
	_add_noise(buf, _lp_noise(buf.size(), 6000.0), 400.0, 0.35)


func _thud_heavy(buf: PackedFloat32Array, v: int) -> void:
	_drop(buf, 140.0 * _vr(v, 0.06), 30.0 * _vr(v, 0.04), 14.0, 4.0, 1.0)
	_drop(buf, 60.0, 26.0, 6.0, 2.6, 0.5)
	_add_noise(buf, _lp_noise(buf.size(), 260.0), 3.5, 0.45)
	_add_noise(buf, _lp_noise(buf.size(), 2500.0), 40.0, 0.55)


func _smack(buf: PackedFloat32Array, v: int) -> void:
	_add_noise(buf, _bp_noise(buf.size(), 1100.0 * _vr(v, 0.1)), 32.0, 0.9)
	_drop(buf, 230.0 * _vr(v, 0.07), 70.0, 30.0, 18.0, 0.8)


func _squelch(buf: PackedFloat32Array, v: int) -> void:
	_splat(buf, v)
	_drop(buf, 260.0 * _vr(v, 0.1), 70.0, 12.0, 10.0, 0.6)
	_crunch(buf, v)


## Seamless howling wind for spooky ambience (fades to match its own start).
func _wind(buf: PackedFloat32Array, v: int) -> void:
	var n := buf.size()
	var a := _bp_noise(n, 500.0 * _vr(v, 0.1))
	var b := _lp_noise(n, 180.0)
	for i in n:
		var t := float(i) / n
		var howl := 0.5 + 0.5 * sin(TAU * t * 2.0 + v) * sin(TAU * t * 3.0)
		buf[i] += a[i] * 0.22 * howl + b[i] * 0.18
	# Crossfade the tail into the head so the loop is seamless.
	var fade := int(RATE * 0.5)
	for i in fade:
		var k := float(i) / fade
		buf[i] = buf[i] * k + buf[n - fade + i] * (1.0 - k)


func _crunch(buf: PackedFloat32Array, v: int) -> void:
	var n := buf.size()
	var hp := _bp_noise(n, 2600.0)
	var clicks := 6 + v * 2
	for c in clicks:
		var start := int(_rng.randf_range(0.0, 0.16) * RATE)
		var amp := _rng.randf_range(0.4, 1.0)
		for i in range(start, mini(start + int(0.012 * RATE), n)):
			var t := float(i - start) / RATE
			buf[i] += hp[i] * exp(-t * 300.0) * amp
	_drop(buf, 180.0, 80.0, 20.0, 22.0, 0.35)


func _stone(buf: PackedFloat32Array, v: int) -> void:
	_drop(buf, 160.0 * _vr(v, 0.08), 55.0, 26.0, 14.0, 0.75)
	_modes(buf, [310.0 * _vr(v, 0.05), 520.0, 860.0], 22.0, 0.25)
	_add_noise(buf, _bp_noise(buf.size(), 1800.0), 22.0, 0.55)
	_add_noise(buf, _lp_noise(buf.size(), 900.0), 9.0, 0.18)


func _wood(buf: PackedFloat32Array, v: int) -> void:
	_modes(buf, [190.0 * _vr(v, 0.07), 420.0, 770.0, 1210.0], 26.0, 0.55)
	_drop(buf, 200.0, 80.0, 30.0, 20.0, 0.5)
	_add_noise(buf, _bp_noise(buf.size(), 2200.0), 70.0, 0.5)


func _metal(buf: PackedFloat32Array, v: int) -> void:
	var base := 380.0 * _vr(v, 0.12)
	_modes(buf, [base, base * 2.76, base * 5.4, base * 8.93], 3.5, 0.45)
	_add_noise(buf, _bp_noise(buf.size(), 3500.0), 90.0, 0.6)
	_drop(buf, 200.0, 70.0, 25.0, 15.0, 0.45)


func _boing(buf: PackedFloat32Array, v: int) -> void:
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := (170.0 + v * 15.0) + 110.0 * sin(t * 38.0) * exp(-t * 5.0) + t * 180.0
		phase += TAU * f / RATE
		buf[i] += sin(phase) * exp(-t * 7.0) * 0.6
	_drop(buf, 160.0, 60.0, 30.0, 25.0, 0.4)


func _glass(buf: PackedFloat32Array, v: int) -> void:
	var n := buf.size()
	var hp := _bp_noise(n, 5000.0)
	for c in 14 + v * 3:
		var start := int(_rng.randf_range(0.0, 0.45) * RATE)
		var f := _rng.randf_range(2500.0, 6500.0)
		var amp := _rng.randf_range(0.15, 0.45) * exp(-float(start) / RATE * 3.0)
		for i in range(start, mini(start + int(0.09 * RATE), n)):
			var t := float(i - start) / RATE
			buf[i] += (sin(TAU * f * t) * 0.6 + hp[i] * 0.5) * exp(-t * 45.0) * amp
	_add_noise(buf, hp, 18.0, 0.5)


func _splat(buf: PackedFloat32Array, v: int) -> void:
	var n := buf.size()
	var wet := _lp_noise(n, 1600.0 * _vr(v, 0.1))
	for i in n:
		var t := float(i) / RATE
		buf[i] += wet[i] * (0.6 + 0.4 * sin(t * (140.0 + v * 30.0))) * exp(-t * 9.0) * 0.8
	_drop(buf, 160.0, 50.0, 20.0, 14.0, 0.6)


func _crack(buf: PackedFloat32Array, v: int) -> void:
	_crunch(buf, v)
	_add_noise(buf, _lp_noise(buf.size(), 700.0), 6.0, 0.35)
	_drop(buf, 120.0, 45.0, 15.0, 8.0, 0.55)


func _splinter(buf: PackedFloat32Array, v: int) -> void:
	_crunch(buf, v)
	_modes(buf, [240.0, 530.0, 980.0], 18.0, 0.3)
	_drop(buf, 150.0, 60.0, 20.0, 12.0, 0.4)


func _creak(buf: PackedFloat32Array, v: int) -> void:
	var n := buf.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 55.0 + v * 8.0 + sin(t * 7.0) * 18.0 + t * 20.0
		phase += TAU * f / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var env := clampf(t / 0.1, 0.0, 1.0) * clampf((0.8 - t) / 0.2, 0.0, 1.0)
		buf[i] += saw * env * 0.3 * (0.7 + 0.3 * sin(t * 90.0))
	_add_noise(buf, _lp_noise(n, 500.0), 3.0, 0.15)


func _boom(buf: PackedFloat32Array, v: int) -> void:
	_drop(buf, 110.0 * _vr(v, 0.08), 28.0, 8.0, 2.2, 1.0)
	_add_noise(buf, _lp_noise(buf.size(), 900.0), 2.6, 0.9)
	_add_noise(buf, _lp_noise(buf.size(), 180.0), 1.6, 0.6)
	_add_noise(buf, _bp_noise(buf.size(), 3000.0), 25.0, 0.5)


func _punt(buf: PackedFloat32Array, v: int) -> void:
	_drop(buf, 210.0 * _vr(v, 0.06), 45.0, 18.0, 9.0, 0.9)
	_whoosh(buf, v, 0.45)


func _whoosh(buf: PackedFloat32Array, v: int, length: float) -> void:
	var n := buf.size()
	var noise := _bp_noise(n, 900.0 * _vr(v, 0.15))
	for i in n:
		var t := float(i) / RATE
		buf[i] += noise[i] * sin(PI * clampf(t / length, 0.0, 1.0)) * 0.45


func _blip(buf: PackedFloat32Array, v: int, f0: float, f1: float, length: float, amp: float) -> void:
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / length) * _vr(v, 0.04) / RATE
		buf[i] += sin(phase) * clampf(1.0 - t / length, 0.0, 1.0) * amp


func _zap(buf: PackedFloat32Array, v: int) -> void:
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := lerpf(220.0, 1200.0, t / 0.2) * _vr(v, 0.05)
		phase += TAU * f / RATE
		buf[i] += (sin(phase) * 0.3 + (fmod(phase / TAU, 1.0) * 2.0 - 1.0) * 0.2) * clampf(1.0 - t / 0.2, 0.0, 1.0)


func _slide(buf: PackedFloat32Array, _v: int) -> void:
	_add_noise(buf, _lp_noise(buf.size(), 1500.0), 4.0, 0.3, 0.04)


func _sizzle(buf: PackedFloat32Array, _v: int) -> void:
	var hp := _bp_noise(buf.size(), 4000.0)
	for i in buf.size():
		var t := float(i) / RATE
		buf[i] += hp[i] * (0.4 + 0.6 * float(_rng.randf() < 0.15)) * exp(-t * 4.0) * 0.5


func _death(buf: PackedFloat32Array, v: int) -> void:
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := lerpf(1400.0, 250.0, pow(t / 0.9, 0.7)) * _vr(v, 0.05) + sin(t * 40.0) * 15.0
		phase += TAU * f / RATE
		buf[i] += sin(phase) * clampf(1.0 - t / 0.9, 0.0, 1.0) * 0.35


func _score(buf: PackedFloat32Array, _v: int) -> void:
	var notes := [523.0, 659.0, 784.0, 1047.0]
	for i in buf.size():
		var t := float(i) / RATE
		var k := mini(int(t / 0.15), 3)
		var lt := t - k * 0.15
		buf[i] += sin(TAU * notes[k] * t) * exp(-lt * 10.0) * 0.4


# --- Playback -----------------------------------------------------------------------

func play3d(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound) or not is_inside_tree():
		return
	var list: Array = _streams[sound]
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = list[_rng.randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.global_position = pos
	p.play()


var _ambient: AudioStreamPlayer


## Looping background ambience ("" stops it).
func set_ambience(sound: String, volume_db := -12.0) -> void:
	if _ambient == null:
		_ambient = AudioStreamPlayer.new()
		_ambient.bus = "SFX"
		add_child(_ambient)
	if sound == "" or not _streams.has(sound):
		_ambient.stop()
		return
	_ambient.stream = _streams[sound][0]
	_ambient.volume_db = volume_db
	_ambient.play()


func play_ui(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var list: Array = _streams[sound]
	_ui.stream = list[_rng.randi() % list.size()]
	_ui.volume_db = volume_db
	_ui.pitch_scale = pitch
	_ui.play()


## Layered physical impact. `strength` ~ 0.05 (tap) .. 3 (huge). Heavier hits are louder,
## lower-pitched and gain a sub-bass thud and a crunchy transient.
func impact(material: String, pos: Vector3, strength: float) -> void:
	var s := clampf(strength, 0.0, 3.0)
	var vol := -14.0 + 10.0 * log(1.0 + s * 8.0) / log(25.0)
	var pitch := clampf(1.15 - s * 0.12, 0.72, 1.2)
	var body := "stone"
	match material:
		"wood":
			body = "wood"
		"metal":
			body = "metal"
		"rubber":
			body = "boing"
		"glass":
			body = "glass"
		"body":
			body = "smack"
		"soft":
			body = "thud"
	play3d(body, pos, vol, pitch)
	if s > 0.15 and material != "rubber":
		play3d("thud", pos, vol - 2.0, pitch)
	if s > 0.7:
		play3d("thud_heavy", pos, vol - 1.0 + s, clampf(1.1 - s * 0.1, 0.75, 1.1))
	if s > 1.0 and material in ["body", "stone", "wood"]:
		play3d("crunch", pos, vol - 3.0, pitch)
