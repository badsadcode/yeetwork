class_name Ambience
## Looping ambient sounds for set dressing (Fixture's Sound): a machine's hum, an electric
## buzz, a diesel engine, a fan, a steam leak, a radio's static. Made at startup on a worker
## thread (Sfx), two takes of each; a recording in assets/sounds/ named after one (hum.ogg,
## hum_1.ogg...) replaces it. Each loops seamlessly: tones are whole cycles over the loop's
## length, noise has its tail cross-faded into its head (the loop ends before the tail).

const KINDS := ["hum", "buzz", "engine", "fan", "steam", "radio"]
const LENGTH := 3.0
const FADE := 0.5 # (seconds of tail cross-faded into the head)


## Fills `buf` with take `v` of `kind`; returns where the loop ends (frames).
static func make(kind: String, buf: PackedFloat32Array, v: int, rng: RandomNumberGenerator, rate: int) -> int:
	var n := buf.size()
	match kind:
		"hum": # a machine's mains hum: 50 Hz and its harmonics, slowly breathing
			var f0 := 50.0 + v * 4.0 # (whole cycles in LENGTH: seamless without a fade)
			var amps := [1.0, 0.6, 0.35, 0.25, 0.12, 0.08]
			for i in n:
				var t := float(i) / rate
				var s := 0.0
				for h in amps.size():
					s += sin(TAU * f0 * (h + 1) * t) * amps[h]
				buf[i] = s * 0.16 * (1.0 + 0.15 * sin(TAU * t / LENGTH))
			return n
		"buzz": # an electric buzz: a raspy 120 Hz with crackles
			var f0 := 120.0 + v * 20.0
			for i in n:
				var t := float(i) / rate
				var s := 0.0
				for h in range(1, 14):
					s += sin(TAU * f0 * h * t) / h
				buf[i] = s * 0.12
			for k in int(LENGTH * 6.0): # crackles
				var at := rng.randi_range(0, n - 400)
				for j in rng.randi_range(80, 300):
					buf[at + j] += rng.randf_range(-1.0, 1.0) * 0.35 * (1.0 - j / 300.0)
		"engine": # a diesel below decks: a deep thrum pulsing with each firing
			var f0 := 30.0 + v * 3.0
			var fire := 15.0 + v * 2.0
			var rumble := _lp(rng, n, 120.0, rate)
			for i in n:
				var t := float(i) / rate
				var pulse := 0.45 + 0.55 * pow(maxf(sin(TAU * fire * t), 0.0), 3.0)
				var s := sin(TAU * f0 * t) + 0.5 * sin(TAU * f0 * 2.0 * t) + 0.3 * sin(TAU * f0 * 3.0 * t)
				buf[i] = (s * 0.22 + rumble[i] * 0.35) * pulse
		"fan": # air rushing through a fan, the blades chopping it
			var air := _bp(rng, n, 700.0 + v * 150.0, rate)
			for i in n:
				var t := float(i) / rate
				var chop := 0.75 + 0.25 * sin(TAU * (20.0 + v * 4.0) * t)
				buf[i] = air[i] * 0.3 * chop + sin(TAU * 60.0 * t) * 0.03
		"steam": # a steam leak: a bright hiss that flutters
			var lo := _lp(rng, n, 1500.0, rate)
			for i in n:
				var t := float(i) / rate
				var white := rng.randf_range(-1.0, 1.0)
				var flutter := 0.8 + 0.2 * sin(TAU * 7.0 * t + v) * sin(TAU * 1.3 * t)
				buf[i] = (white - lo[i]) * 0.3 * flutter
		"radio": # a radio left on: static, and a voice warbling somewhere in it
			var hiss := _bp(rng, n, 2200.0, rate)
			var phase := 0.0
			for i in n:
				var t := float(i) / rate
				var syl := maxf(sin(TAU * (3.0 + v) * t) * sin(TAU * 0.6 * t + v), 0.0)
				var f := 180.0 + 60.0 * sin(TAU * 2.3 * t + v) + 40.0 * sin(TAU * 5.1 * t)
				phase += TAU * f / rate
				var voice := (sin(phase) + 0.5 * sin(phase * 3.0) + 0.3 * sin(phase * 5.0)) * syl
				buf[i] = hiss[i] * 0.22 + voice * 0.07
			for k in int(LENGTH * 4.0): # pops of static
				var at := rng.randi_range(0, n - 200)
				for j in 120:
					buf[at + j] += rng.randf_range(-1.0, 1.0) * 0.3
	# Noise: cross-fade the tail into the head; the loop ends before the tail.
	var fade := int(FADE * rate)
	for i in fade:
		var k := float(i) / fade
		buf[i] = buf[i] * k + buf[n - fade + i] * (1.0 - k)
	return n - fade


static func _lp(rng: RandomNumberGenerator, n: int, cutoff: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var y := 0.0
	var g := clampf(sqrt(1.0 / maxf(a, 0.001)) * 0.6, 1.0, 12.0)
	for i in n:
		y += (rng.randf_range(-1.0, 1.0) - y) * a
		out[i] = y * g
	return out


static func _bp(rng: RandomNumberGenerator, n: int, center: float, rate: int) -> PackedFloat32Array:
	var hi := _lp(rng, n, center * 1.6, rate)
	var lo := _lp(rng, n, center * 0.6, rate)
	for i in n:
		hi[i] -= lo[i] * 0.8
	return hi
