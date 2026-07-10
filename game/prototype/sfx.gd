# PROTOTYPE HARNESS — procedural SFX factory. AudioStreamWAV samples are
# synthesized ONCE (44100 Hz, 16-bit mono) into a static cache — same budget
# discipline as sprites.gd. The shipping audio path is authored assets through
# the content pipeline (docs/design/17); this exists so the slice sounds alive.
class_name ProtoSfx

const RATE := 44100

static var _cache: Dictionary = {}

const NAMES := ["swing", "hit", "player_hurt", "pickup", "capture", "snare_fail",
		"bolt", "boss_screech", "victory"]

static func warm() -> void:
	for n in NAMES:
		stream(n)

static func stream(sfx_name: String) -> AudioStreamWAV:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var samples: PackedFloat32Array
	match sfx_name:
		"swing":
			samples = _swing()
		"hit":
			samples = _hit()
		"player_hurt":
			samples = _player_hurt()
		"pickup":
			samples = _notes([[880.0, 0.06], [1318.5, 0.06]], 1.0, 0.0, 0.22)
		"capture":
			samples = _notes([[523.25, 0.11], [659.25, 0.11], [783.99, 0.18]], 0.35, 0.6, 0.3)
		"snare_fail":
			samples = _snare_fail()
		"bolt":
			samples = _bolt()
		"boss_screech":
			samples = _boss_screech()
		_:
			samples = _notes([[523.25, 0.14], [659.25, 0.14], [783.99, 0.14], [1046.5, 0.36]],
					0.3, 0.65, 0.32)   # victory fanfare
	var wav := _wav(samples)
	_cache[sfx_name] = wav
	return wav

# ---- synthesis kit -------------------------------------------------------------

static func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

static func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

static func _square(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

static func _saw(phase: float) -> float:
	return 2.0 * fmod(phase, 1.0) - 1.0

# ---- recipes ---------------------------------------------------------------------

# short filtered noise whoosh, 0.08 s
static func _swing() -> PackedFloat32Array:
	var b := _buf(0.08)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var lp := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var cutoff := 0.10 + 0.28 * t          # opening filter = rising whoosh
		lp += cutoff * (rng.randf_range(-1.0, 1.0) - lp)
		b[i] = lp * sin(PI * t) * 0.9
	return b

# sine thud 90 -> 45 Hz, 0.1 s
static func _hit() -> PackedFloat32Array:
	var b := _buf(0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += lerpf(90.0, 45.0, t) / RATE
		var s := sin(phase * TAU) * 0.95
		if t < 0.12:                            # tiny impact crackle at the front
			s += rng.randf_range(-0.3, 0.3) * (1.0 - t / 0.12)
		b[i] = s * pow(1.0 - t, 1.6)
	return b

# harsh saw burst, 0.12 s
static func _player_hurt() -> PackedFloat32Array:
	var b := _buf(0.12)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += lerpf(230.0, 95.0, t) / RATE
		var s: float = clampf(_saw(phase) * 1.9, -1.0, 1.0)   # clipped = harsh
		b[i] = s * pow(1.0 - t, 1.3) * 0.7
	return b

# quick zap: square sweep 1200 -> 300 Hz, 0.07 s
static func _bolt() -> PackedFloat32Array:
	var b := _buf(0.07)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += lerpf(1200.0, 300.0, t) / RATE
		b[i] = _square(phase) * pow(1.0 - t, 0.6) * 0.3
	return b

# descending buzz (failed snare)
static func _snare_fail() -> PackedFloat32Array:
	var b := _buf(0.3)
	var phase := 0.0
	var mod_phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += lerpf(380.0, 110.0, t) / RATE
		mod_phase += 28.0 / RATE
		var buzz := 0.6 + 0.4 * _square(mod_phase)    # 28 Hz chop = buzz
		b[i] = _square(phase) * buzz * (1.0 - t) * 0.32
	return b

# noisy descending screech, 0.4 s (enrage / boss aggro)
static func _boss_screech() -> PackedFloat32Array:
	var b := _buf(0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var p0 := 0.0
	var p1 := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var f := lerpf(1500.0, 340.0, pow(t, 0.7))
		p0 += f / RATE
		p1 += (f * 1.02 + 7.0) / RATE            # detuned second saw = nasty beat
		var s := (_saw(p0) + _saw(p1)) * 0.5 + rng.randf_range(-0.45, 0.45)
		var env := minf(t / 0.04, 1.0) * pow(1.0 - t, 1.1)
		b[i] = clampf(s * 1.3, -1.0, 1.0) * env * 0.65
	return b

# note sequence: [[freq, dur], ...] mixed square+sine (chimes/arpeggios/fanfare)
static func _notes(seq: Array, square_mix: float, sine_mix: float,
		amp: float) -> PackedFloat32Array:
	var total := 0.0
	for n in seq:
		total += float(n[1])
	var b := _buf(total)
	var idx := 0
	for n in seq:
		var freq := float(n[0])
		var count := int(float(n[1]) * RATE)
		var phase := 0.0
		for i in count:
			if idx >= b.size():
				break
			var t := float(i) / count
			phase += freq / RATE
			var s := _square(phase) * square_mix + sin(phase * TAU) * sine_mix
			var env := minf(t / 0.03, 1.0) * pow(1.0 - t, 0.9)
			b[idx] = s * env * amp
			idx += 1
	return b
