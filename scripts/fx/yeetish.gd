class_name Yeetish
## Placeholder Yeet voices: gibberish "Yeetish" shouts, synthesized (Sfx makes them at
## startup, "voice_<kind>"; recordings in assets/sounds/ replace them, see docs/SOUNDS.md).
## A shout is a few syllables: a consonant onset (a breathy h, a y or w glide, a click, a
## hiss, a hum) into a vowel, sung with a pitch melody of its kind: falling for pain, high
## and wobbly for a scream, sing-song for a taunt, rising for a cheer. The vowels come from
## one-period wavetables shaped by their formants (cheap: a lookup per sample), so the voice
## is cartoonish: the formants move with the pitch, like a sped-up recording.

const KINDS := ["hurt", "die", "scream", "grabbed", "taunt", "cheer", "burn", "gasp", "yay", "effort", "yeet"]
## Buffer length per kind (seconds).
const LENGTH := {
	"hurt": 0.35, "die": 1.0, "scream": 1.0, "grabbed": 0.45, "taunt": 0.75, "cheer": 0.7,
	"burn": 0.6, "gasp": 0.6, "yay": 0.6, "effort": 0.6, "yeet": 0.5,
}
## Vowel formants (Hz) and their strengths.
const VOWELS := {
	"a": [[800.0, 1.0], [1250.0, 0.6], [2600.0, 0.25]],
	"e": [[480.0, 1.0], [1950.0, 0.55], [2650.0, 0.3]],
	"i": [[300.0, 1.0], [2350.0, 0.5], [3050.0, 0.3]],
	"o": [[520.0, 1.0], [880.0, 0.7], [2500.0, 0.15]],
	"u": [[330.0, 1.0], [780.0, 0.45], [2300.0, 0.1]],
}
const TABLE := 512
const REF_F0 := 280.0 # the pitch the tables are shaped for

static var _tables := {}


## Fills `buf` (at `rate` Hz) with variant `v` of a shout.
static func speak(buf: PackedFloat32Array, v: int, kind: String, rng: RandomNumberGenerator, rate: int) -> void:
	if _tables.is_empty():
		_make_tables(rate)
	var base := rng.randf_range(0.92, 1.1) # (each Yeet's own pitch comes on top, at playback)
	var syl: Array = [] # [start s, length s, onset, vowel from, vowel to, f0 from, f0 mid, f0 to, amp, vibrato]
	var pick := func(a: Array): return a[rng.randi() % a.size()]
	match kind:
		"hurt": # a short "oof", "ow", "agh"
			syl.append([0.0, rng.randf_range(0.17, 0.25), pick.call(["h", "", "w"]), pick.call(["o", "a", "u"]), pick.call(["o", "u", "a"]), 430.0, 360.0, 260.0, 1.0, 0.0])
		"die": # a falling wail: "wa-aaah"
			syl.append([0.0, 0.14, pick.call(["w", "", "n"]), "a", "a", 470.0, 450.0, 420.0, 0.9, 0.0])
			syl.append([0.16, rng.randf_range(0.6, 0.75), "", "a", "o", 440.0, 300.0, 160.0, 1.0, 0.05])
		"scream": # high and wobbly: "aaaah!", "wheee!"
			var high := rng.randf_range(620.0, 760.0)
			syl.append([0.0, rng.randf_range(0.65, 0.85), pick.call(["", "w", "h"]), pick.call(["a", "e", "i"]), pick.call(["a", "e"]), high * 0.85, high * 1.08, high * 0.8, 1.0, 0.06])
		"grabbed": # an indignant "hey?!"
			syl.append([0.0, rng.randf_range(0.28, 0.34), pick.call(["h", "w"]), "e", "i", 320.0, 420.0, 580.0, 1.0, 0.0])
		"taunt": # sing-song: "nya-nya-nyaa"
			var cons: String = pick.call(["n", "b", "d", "y"])
			var t := 0.0
			var count := 3 + rng.randi() % 2
			for k in count:
				var last := k == count - 1
				var hi := (k % 2) == 0
				var d := 0.22 if last else rng.randf_range(0.09, 0.12)
				var f := 470.0 if hi else 380.0
				syl.append([t, d, cons, pick.call(["e", "a"]), "a" if last else "e", f, f, (300.0 if last else f), 0.85, 0.02 if last else 0.0])
				t += d + 0.035
		"cheer": # "yee-YAAH!"
			syl.append([0.0, 0.15, "y", "i", "i", 400.0, 410.0, 420.0, 0.8, 0.0])
			syl.append([0.18, rng.randf_range(0.36, 0.45), pick.call(["y", "w"]), "a", "a", 430.0, 590.0, 470.0, 1.0, 0.03])
		"burn": # "ah! ah! ah!", hot hot hot
			var t := 0.0
			for k in 3:
				var f := 520.0 + k * 45.0
				syl.append([t, rng.randf_range(0.1, 0.12), pick.call(["", "h"]), pick.call(["a", "e"]), "a", f, f * 1.05, f * 0.9, 0.9, 0.0])
				t += 0.17
		"gasp": # a breath in, then "hah"
			syl.append([0.0, 0.26, "inhale", "a", "a", 0.0, 0.0, 0.0, 0.5, 0.0])
			syl.append([0.3, 0.17, "h", "a", "o", 400.0, 380.0, 300.0, 0.8, 0.0])
		"yay": # "ya-hoo!"
			syl.append([0.0, 0.13, "y", "a", "a", 400.0, 410.0, 420.0, 0.85, 0.0])
			syl.append([0.16, rng.randf_range(0.3, 0.38), "h", "u", "o", 520.0, 610.0, 500.0, 1.0, 0.03])
		"effort": # a strained "hnnngh!"
			syl.append([0.0, rng.randf_range(0.4, 0.5), "h", "u", "o", 190.0, 215.0, 240.0, 0.9, 0.0])
		"yeet": # "YEET!"
			syl.append([0.0, rng.randf_range(0.26, 0.3), "y", "i", "i", 470.0, 500.0, 430.0, 1.0, 0.0])
			syl.append([0.3, 0.0, "t_end", "i", "i", 0.0, 0.0, 0.0, 0.7, 0.0])
	for s in syl:
		_syllable(buf, s, base, kind == "effort", rng, rate)
	# Gentle level: peaks to about 0.8.
	var peak := 0.0
	for i in buf.size():
		peak = maxf(peak, absf(buf[i]))
	if peak > 0.0:
		var g := 0.8 / peak
		for i in buf.size():
			buf[i] *= g


static func _syllable(buf: PackedFloat32Array, s: Array, base: float, strain: bool, rng: RandomNumberGenerator, rate: int) -> void:
	var start := int(float(s[0]) * rate)
	var dur := float(s[1])
	var onset: String = s[2]
	var amp: float = s[8]
	var n := buf.size()
	# Onsets that are noise: a breath in, an h, a hiss, a click at the end ("yeet").
	if onset == "inhale":
		var y := 0.0
		for i in range(start, mini(n, start + int(dur * rate))):
			var t := float(i - start) / rate
			y += (rng.randf_range(-1.0, 1.0) - y) * 0.35
			buf[i] += y * sin(PI * t / dur) * amp * 0.5
		return
	if onset == "t_end":
		for i in range(start, mini(n, start + int(0.025 * rate))):
			buf[i] += rng.randf_range(-1.0, 1.0) * (1.0 - float(i - start) / (0.025 * rate)) * amp
		return
	var lead := 0.0
	if onset in ["h", "s"]:
		lead = 0.05 if onset == "h" else 0.07
		var prev := 0.0
		for i in range(start, mini(n, start + int(lead * rate))):
			var t := float(i - start) / rate
			var w := rng.randf_range(-1.0, 1.0)
			var hp := w - prev if onset == "s" else w * 0.5
			prev = w
			buf[i] += hp * amp * 0.25 * (t / lead)
	elif onset in ["k", "t", "p"]:
		lead = 0.03
		for i in range(start + int(0.015 * rate), mini(n, start + int(lead * rate))):
			buf[i] += rng.randf_range(-1.0, 1.0) * amp * 0.5
	# The vowel: a wavetable at the melody's pitch, gliding between two vowels.
	var from: PackedFloat32Array = _tables[s[3]]
	var to: PackedFloat32Array = _tables[s[4]]
	var glide_in := onset in ["y", "w", "n", "b", "d", "m"]
	var onset_v: PackedFloat32Array = _tables["i" if onset == "y" else "u"] if glide_in else from
	var phase := 0.0
	var v0 := start + int(lead * rate)
	var len_n := int(dur * rate)
	var r1 := rng.randf() * TAU
	for j in len_n:
		var i := v0 + j
		if i >= n:
			break
		var t := float(j) / rate
		var u := t / dur
		# Melody: from -> mid -> to (a smooth curve through the three).
		var f := lerpf(lerpf(float(s[5]), float(s[6]), u), lerpf(float(s[6]), float(s[7]), u), u) * base
		f *= 1.0 + float(s[9]) * sin(TAU * 5.6 * t + r1) # vibrato
		f *= 1.0 + 0.01 * sin(TAU * 13.0 * t + r1 * 2.0) # a little natural wobble
		if strain:
			f *= 1.0 + 0.04 * sin(TAU * 31.0 * t) # a rough, strained voice
		phase = fmod(phase + f / rate, 1.0)
		var x := phase * TABLE
		var k := int(x)
		var fr := x - k
		var k2 := (k + 1) % TABLE
		var a := lerpf(from[k], from[k2], fr)
		var b := lerpf(to[k], to[k2], fr)
		var smp := lerpf(a, b, smoothstep(0.2, 0.9, u))
		if glide_in and t < 0.06: # a y / w / hum gliding into the vowel
			var g := t / 0.06
			smp = lerpf(lerpf(onset_v[k], onset_v[k2], fr), smp, g) * lerpf(0.45, 1.0, g)
		var env := clampf(t / 0.012, 0.0, 1.0) * clampf((dur - t) / 0.05, 0.0, 1.0)
		buf[i] += (smp + rng.randf_range(-1.0, 1.0) * (0.12 if strain else 0.04)) * env * amp


## One period of each vowel: harmonics of REF_F0 weighted by the vowel's formant peaks.
static func _make_tables(rate: int) -> void:
	for vname in VOWELS:
		var t := PackedFloat32Array()
		t.resize(TABLE)
		var peak := 0.0
		var max_h := int(rate * 0.45 / (REF_F0 * 2.4)) # (no aliasing up to ~2.4x the pitch)
		for h in range(1, max_h + 1):
			var fh := REF_F0 * h
			var g := 0.0
			for fm in VOWELS[vname]:
				var bw := 90.0 + float(fm[0]) * 0.06
				g += float(fm[1]) / (1.0 + pow((fh - float(fm[0])) / bw, 2.0))
			g *= 1.0 / pow(h, 0.35)
			for i in TABLE:
				t[i] += sin(TAU * h * i / TABLE) * g
		for i in TABLE:
			peak = maxf(peak, absf(t[i]))
		for i in TABLE:
			t[i] /= peak
		_tables[vname] = t
