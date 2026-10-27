# Spariaps — Audio: suoni sintetizzati (come nella versione browser) e musica.
# I suoni vengono calcolati una volta sola in un thread all'avvio e poi riprodotti da un gruppo di lettori riutilizzati.
extends Node

const RATE := 22050
const VOLUME := 0.5
const CATS := { "weapons": "volWeapons", "enemies": "volEnemies", "fx": "volFx", "ui": "volUi", "music": "volMusic" }
const BUS := { "weapons": "Weapons", "enemies": "Enemies", "fx": "Fx", "ui": "Ui", "music": "Music" }

var cat := "fx"
var bank := {}           # baked sounds: key -> AudioStreamWAV (or Array of variants)
var tones := {}          # small tones baked on demand
var ready_bank := false
var players2d: Array = []
var players3d: Array = []
var _p2 := 0
var _p3 := 0
var last_groan := -99.0

var song: AudioStreamPlayer
var loop: AudioStreamPlayer
var song_key := ""
var loop_key := ""
var music_want := ""
var song_vol := 0.0
var loop_vol := 0.0
var duck := 1.0

# gunshot = supersonic crack + muzzle blast + low-end punch; distance makes it duller (and the bus adds the echo)
const SND := {
	"rifle": [0.9, 1.0, 1500, 0.22, 0.8], "pistol": [0.8, 0.75, 2000, 0.14, 0.45], "shotgun": [0.75, 1.35, 950, 0.4, 1.3],
	"sniper": [1.25, 1.2, 1200, 0.38, 1.1], "lmg": [0.9, 1.05, 1300, 0.24, 0.95], "smg": [0.7, 0.7, 2300, 0.11, 0.4],
	"bot": [0.8, 0.95, 1400, 0.22, 0.7], "uzi": [0.65, 0.65, 2500, 0.1, 0.35], "burst": [0.9, 0.95, 1600, 0.2, 0.75],
	"dmr": [1.1, 1.1, 1300, 0.3, 0.95], "minigun": [0.7, 0.9, 1400, 0.12, 0.7], "magnum": [1.15, 1.2, 1250, 0.32, 1.1],
}

func _ready() -> void:
	G.audio = self
	_buses()
	for i in 28:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players2d.append(p)
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.panning_strength = 0.8
		p.max_db = 6
		G.scene_root.add_child(p)
		players3d.append(p)
	song = AudioStreamPlayer.new(); song.bus = "Music"; add_child(song)
	loop = AudioStreamPlayer.new(); loop.bus = "Music"; add_child(loop)
	apply_volumes()
	WorkerThreadPool.add_task(_bake_all, false, "spariaps-sfx")

func _buses() -> void:
	for c in BUS.values():
		if AudioServer.get_bus_index(c) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, c)
		AudioServer.set_bus_send(i, "Master")
		if c in ["Weapons", "Enemies", "Fx"]:
			var rv := AudioEffectReverb.new()
			rv.room_size = 0.55
			rv.damping = 0.6
			rv.wet = 0.14
			rv.dry = 1.0
			rv.spread = 0.8
			AudioServer.add_bus_effect(i, rv)

func apply_volumes() -> void:
	var S: Dictionary = G.settings
	AudioServer.set_bus_volume_db(0, -80.0 if G.muted else linear_to_db(maxf(0.0001, S.volMaster)))
	for c in CATS:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS[c]), linear_to_db(maxf(0.0001, float(S[CATS[c]]))))

func set_muted(v: bool) -> void:
	G.muted = v
	G.sset("muted", v)
	apply_volumes()

func with_cat(c: String, fn: Callable) -> void:
	var prev := cat
	cat = c
	fn.call()
	cat = prev

# ============================================================ playback
func _play(stream: AudioStream, vol := 1.0, pos: Variant = null, pitch := 1.0, delay := 0.0, bus := "") -> void:
	if stream == null or vol <= 0.002:
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_play.bind(stream, vol, pos, pitch, 0.0, bus if bus != "" else BUS[cat]))
		return
	var b := bus if bus != "" else str(BUS[cat])
	if pos is Vector3 and G.camera:
		var p: AudioStreamPlayer3D = players3d[_p3]
		_p3 = (_p3 + 1) % players3d.size()
		p.global_position = pos
		p.stream = stream; p.volume_db = linear_to_db(vol); p.pitch_scale = pitch; p.bus = b
		p.play()
	else:
		var p2: AudioStreamPlayer = players2d[_p2]
		_p2 = (_p2 + 1) % players2d.size()
		p2.stream = stream; p2.volume_db = linear_to_db(vol); p2.pitch_scale = pitch; p2.bus = b
		p2.play()

func _pick(key: String) -> AudioStream:
	if not ready_bank or not bank.has(key):
		return null
	var v: Variant = bank[key]
	if v is Array:
		return v[randi() % v.size()]
	return v

# far: 0 near .. 1 distant (muffled variant)
func _far_key(base: String, far: float) -> String:
	return "%s@%d" % [base, clampi(roundi(far * 3.0), 0, 3)]

# ============================================================ synthesis
static func _osc(type: String, ph: float) -> float:
	match type:
		"square": return 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
		"sawtooth": return fposmod(ph, 1.0) * 2.0 - 1.0
		"triangle": return 1.0 - 4.0 * absf(fposmod(ph, 1.0) - 0.5)
	return sin(ph * TAU)

class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	func _init(type: String, f: float, q: float) -> void:
		var w := TAU * clampf(f, 20.0, 10500.0) / 22050.0
		var al := sin(w) / (2.0 * maxf(0.1, q))
		var c := cos(w)
		var a0 := 1.0 + al
		match type:
			"lowpass":
				b0 = (1.0 - c) / 2.0; b1 = 1.0 - c; b2 = (1.0 - c) / 2.0
			"highpass":
				b0 = (1.0 + c) / 2.0; b1 = -(1.0 + c); b2 = (1.0 + c) / 2.0
			_:
				b0 = al; b1 = 0.0; b2 = -al
		a1 = -2.0 * c; a2 = 1.0 - al
		b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		return y

static func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE) + 1)
	return b

# exponential envelope like Web Audio's exponentialRampToValueAtTime
static func _exp(v0: float, v1: float, t: float, dur: float) -> float:
	if t >= dur:
		return v1
	return v0 * pow(v1 / v0, t / dur)

static func tone_buf(freq: float, dur: float, vol: float, type := "square", end_freq := -1.0) -> PackedFloat32Array:
	if end_freq < 0:
		end_freq = freq
	var b := _buf(dur + 0.02)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := _exp(freq, end_freq, t, dur)
		ph += f / RATE
		b[i] = _osc(type, ph) * _exp(vol, 0.001, t, dur) * (1.0 if t <= dur else 0.0)
	return b

static func burst_buf(dur: float, ftype: String, freq: float, q: float, vol: float, attack := 0.0) -> PackedFloat32Array:
	var b := _buf(dur + 0.05)
	var f := Biquad.new(ftype, freq, q)
	for i in b.size():
		var t := float(i) / RATE
		var g: float
		if attack > 0.0 and t < attack:
			g = _exp(0.001, vol, t, attack)
		else:
			g = _exp(vol, 0.001, t - attack, dur - attack)
		b[i] = f.run(randf() * 2.0 - 1.0) * g
	return b

static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at := 0.0, k := 1.0) -> PackedFloat32Array:
	var o := int(at * RATE)
	if dst.size() < o + src.size():
		dst.resize(o + src.size())
	for i in src.size():
		dst[o + i] += src[i] * k
	return dst

static func lowpass(b: PackedFloat32Array, f: float) -> PackedFloat32Array:
	var lp := Biquad.new("lowpass", f, 0.7)
	for i in b.size():
		b[i] = lp.run(b[i])
	return b

static func to_wav(b: PackedFloat32Array, gain := VOLUME) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		var s := b[i] * gain
		s = s if absf(s) < 0.8 else signf(s) * (0.8 + (1.0 - 0.8) * tanh((absf(s) - 0.8) / 0.2))
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

static func shot_buf(s: Array, far: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b = mix_into(b, burst_buf(0.045, "highpass", 2500, 0.7, s[0] * (1.0 - far * 0.7)))
	b = mix_into(b, burst_buf(s[3], "lowpass", s[2], 0.5, s[1], 0.003))
	b = mix_into(b, burst_buf(0.17, "lowpass", 160, 1.2, s[4] * 2.2))
	return lowpass(b, lerpf(10000, 1000, far))

static func boom_buf(far: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b = mix_into(b, burst_buf(0.08, "highpass", 1800, 0.7, 1.1 * (1.0 - far * 0.7)))
	b = mix_into(b, burst_buf(1.3, "lowpass", 650, 0.8, 1.7))
	b = mix_into(b, tone_buf(115, 0.85, 1.5, "sine", 30))
	return lowpass(b, lerpf(8000, 900, far))

# zombie voice: raspy pitch-wobbling sawtooth, vocal-fry flutter, two throat formants, breath noise
static func groan_buf(kind: String) -> PackedFloat32Array:
	var dur := randf_range(0.35, 0.55) if kind == "attack" else (randf_range(0.8, 1.2) if kind == "death" else randf_range(0.9, 1.7))
	var base := randf_range(115, 160) if kind == "attack" else (randf_range(80, 110) if kind == "death" else randf_range(58, 92))
	var pc: Array = []
	for i in 9:
		pc.append(base * (1.0 + (randf() - 0.5) * 0.28) * ((1.0 - i / 9.0 * 0.5) if kind == "death" else 1.0))
	var fry := randf_range(20, 36)
	var f1 := Biquad.new("bandpass", randf_range(420, 680), 4.5)
	var f2 := Biquad.new("bandpass", randf_range(950, 1400), 6.0)
	var nf := Biquad.new("bandpass", randf_range(900, 1500), 0.9)
	var lp := Biquad.new("lowpass", 3200 if kind == "attack" else 2200, 0.7)
	var peak := 0.9 if kind == "attack" else 0.6
	var env := [0.0001, peak * 0.6, peak, peak * randf_range(0.45, 0.85), peak * randf_range(0.6, 1.0), peak * 0.35, 0.0001]
	var nenv := [0.0001, peak * 0.35, peak * 0.2, peak * 0.3, 0.0001]
	var b := _buf(dur)
	var ph := 0.0
	var fph := 0.0
	for i in b.size():
		var t := float(i) / RATE / dur
		var pi := minf(t * 8.0, 7.999)
		var f: float = lerpf(pc[int(pi)], pc[int(pi) + 1], pi - int(pi))
		ph += f / RATE
		fph += fry / RATE
		var am := 0.55 + 0.42 * (1.0 if fposmod(fph, 1.0) < 0.5 else -1.0)
		var src := _osc("sawtooth", ph) * am
		var ei := minf(t * 6.0, 5.999)
		var e: float = lerpf(env[int(ei)], env[int(ei) + 1], ei - int(ei))
		var ni := minf(t * 4.0, 3.999)
		var ne: float = lerpf(nenv[int(ni)], nenv[int(ni) + 1], ni - int(ni))
		var v := (f1.run(src) + f2.run(src) * 0.55) * e * 2.5 + nf.run(randf() * 2.0 - 1.0) * ne
		b[i] = lp.run(v)
	return b

static func _click(b: PackedFloat32Array, at: float, f: float, v: float, q := 6.0) -> PackedFloat32Array:
	return mix_into(b, burst_buf(0.035, "bandpass", f, q, v), at)

static func _ping(b: PackedFloat32Array, at: float, f: float, v: float) -> PackedFloat32Array:
	return mix_into(b, tone_buf(f, 0.06, v, "sine", f * 0.97), at)

static func _scrape(b: PackedFloat32Array, at: float, dur: float, f: float, v: float) -> PackedFloat32Array:
	return mix_into(b, burst_buf(dur, "bandpass", f, 1.6, v, 0.02), at)

static func mech_buf(kind: String) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	match kind:
		"release": b = _click(b, 0, 3200, 0.6); b = _ping(b, 0.004, 2400, 0.025)
		"out": b = _scrape(b, 0, 0.16, 1400, 0.28); b = _click(b, 0.15, 900, 0.4, 3)
		"in": b = _scrape(b, 0, 0.11, 1700, 0.25); b = mix_into(b, burst_buf(0.07, "lowpass", 450, 1, 0.9), 0.1); b = _click(b, 0.1, 2600, 0.55)
		"seat": b = _click(b, 0, 3600, 0.7, 8); b = _click(b, 0.03, 2000, 0.35)
		"rack": b = _scrape(b, 0, 0.09, 2200, 0.3); b = _click(b, 0.08, 3000, 0.75); b = _scrape(b, 0.14, 0.08, 1800, 0.28); b = _click(b, 0.22, 3400, 0.9); b = _ping(b, 0.225, 2900, 0.04)
		"slide": b = _click(b, 0, 2800, 0.55); b = _scrape(b, 0.02, 0.06, 1500, 0.3); b = _click(b, 0.08, 3600, 0.9); b = _ping(b, 0.085, 3100, 0.04)
		"bolt": b = _click(b, 0, 2600, 0.6); b = _scrape(b, 0.03, 0.12, 1300, 0.32); b = _click(b, 0.15, 2200, 0.65); b = _scrape(b, 0.19, 0.1, 1500, 0.3); b = _click(b, 0.29, 3200, 0.8)
		"shell": b = _scrape(b, 0, 0.06, 1900, 0.35); b = _click(b, 0.05, 1200, 0.55, 3)
		"pump": b = _scrape(b, 0, 0.09, 900, 0.55); b = _click(b, 0.08, 1500, 0.9, 3); b = _scrape(b, 0.14, 0.08, 1100, 0.5); b = _click(b, 0.21, 1800, 0.9, 3)
		"lid": b = _click(b, 0, 1700, 0.65, 4); b = mix_into(b, burst_buf(0.05, "lowpass", 700, 1, 0.45), 0.01)
		"zapOut": b = mix_into(b, tone_buf(900, 0.25, 0.07, "sawtooth", 200))
		"zapIn": b = mix_into(b, tone_buf(200, 0.3, 0.07, "sawtooth", 1400)); b = mix_into(b, tone_buf(1400, 0.1, 0.05, "sine", 1800), 0.3)
	return b

# everything heavy is computed here, off the main thread
func _bake_all() -> void:
	var out := {}
	for k in SND:
		for f in 4:
			var vars: Array = []
			for v in (3 if f == 0 else 2):
				vars.append(to_wav(shot_buf(SND[k], f / 3.0)))
			out["shot-%s@%d" % [k, f]] = vars
	for f in 4:
		out["boom@%d" % f] = to_wav(boom_buf(f / 3.0))
	for kind in ["idle", "attack", "death"]:
		var vars: Array = []
		for i in 5:
			vars.append(to_wav(groan_buf(kind)))
		out["groan-" + kind] = vars
	for kind in ["release", "out", "in", "seat", "rack", "slide", "bolt", "shell", "pump", "lid", "zapOut", "zapIn"]:
		out["mech-" + kind] = to_wav(mech_buf(kind))
	var sh: Array = []
	for i in 3:
		var b := PackedFloat32Array()
		for j in 2:
			var f := randf_range(3600, 5400)
			b = mix_into(b, tone_buf(f, 0.035, 0.02, "sine", randf_range(3000, 5000)), j * randf_range(0.06, 0.12))
		sh.append(to_wav(b))
	out["shell"] = sh
	var sw := PackedFloat32Array()
	var bp := Biquad.new("bandpass", 700, 2)
	sw.resize(int(0.2 * RATE))
	for i in sw.size():
		var t := float(i) / RATE
		if i % 64 == 0:
			bp = _retune(bp, _exp(700, 3500, t, 0.14))
		var g := _exp(0.001, 1.0, t, 0.06) if t < 0.06 else _exp(1.0, 0.001, t - 0.06, 0.12)
		sw[i] = bp.run(randf() * 2.0 - 1.0) * g
	out["swoosh"] = to_wav(sw)
	var bite := PackedFloat32Array()
	bite = mix_into(bite, burst_buf(0.14, "lowpass", 320, 1, 1.1)); bite = mix_into(bite, burst_buf(0.08, "bandpass", 2400, 1.5, 0.45), 0.02)
	out["bite"] = to_wav(bite)
	var stun := PackedFloat32Array()
	stun = mix_into(stun, burst_buf(0.3, "highpass", 1400, 0.6, 1.5)); stun = mix_into(stun, burst_buf(0.5, "lowpass", 1200, 0.7, 0.9))
	out["stun"] = to_wav(stun)
	out["ring"] = to_wav(tone_buf(3150, 2.5, 0.05, "sine", 3050))
	out["hiss"] = to_wav(burst_buf(2.4, "bandpass", 3200, 0.8, 0.35, 0.15))
	var ray := PackedFloat32Array()
	ray = mix_into(ray, tone_buf(1700, 0.17, 0.11, "sawtooth", 240)); ray = mix_into(ray, tone_buf(850, 0.24, 0.09, "square", 110), 0.01); ray = mix_into(ray, burst_buf(0.14, "lowpass", 1400, 0.8, 0.5))
	out["ray"] = to_wav(ray)
	var rk := PackedFloat32Array()
	rk = mix_into(rk, burst_buf(0.5, "lowpass", 900, 0.8, 1.1, 0.02)); rk = mix_into(rk, burst_buf(0.9, "bandpass", 2200, 0.6, 0.35, 0.05)); rk = mix_into(rk, tone_buf(160, 0.35, 0.2, "sine", 60))
	out["rocket"] = to_wav(rk)
	var horn := PackedFloat32Array()
	for fv in [[55.0, 0.5], [82.4, 0.35], [110.0, 0.2]]:
		var hb := _buf(2.9)
		var ph := 0.0
		var lp := Biquad.new("lowpass", 300, 0.7)
		for i in hb.size():
			var t := float(i) / RATE
			if i % 128 == 0:
				lp = _retune_lp(lp, 300.0 + 600.0 * minf(1.0, t / 1.2) - (650.0 * clampf((t - 1.2) / 1.4, 0, 1)))
			ph += lerpf(fv[0] * 0.94, fv[0], minf(1.0, t / 0.6)) / RATE
			var g = _exp(0.001, fv[1], t, 0.4) if t < 0.4 else (fv[1] if t < 1.8 else _exp(fv[1], 0.001, t - 1.8, 1.0))
			hb[i] = lp.run(_osc("sawtooth", ph)) * g
		horn = mix_into(horn, hb)
	horn = mix_into(horn, boom_buf(0.4), 0.0, 0.8)
	out["horn"] = to_wav(horn)
	var boing := PackedFloat32Array()
	boing = mix_into(boing, tone_buf(170, 0.35, 0.22, "sine", 720)); boing = mix_into(boing, tone_buf(340, 0.25, 0.08, "triangle", 1300), 0.02)
	out["boing"] = to_wav(boing)
	call_deferred("_bank_ready", out)

static func _retune(bq: Biquad, f: float) -> Biquad:
	var n := Biquad.new("bandpass", f, 2)
	n.x1 = bq.x1; n.x2 = bq.x2; n.y1 = bq.y1; n.y2 = bq.y2
	return n

static func _retune_lp(bq: Biquad, f: float) -> Biquad:
	var n := Biquad.new("lowpass", maxf(120.0, f), 0.7)
	n.x1 = bq.x1; n.x2 = bq.x2; n.y1 = bq.y1; n.y2 = bq.y2
	return n

func _bank_ready(out: Dictionary) -> void:
	bank = out
	ready_bank = true

# ============================================================ sound effects used by the game
func tone(freq: float, dur: float, vol: float, type := "square", end_freq := -1.0, delay := 0.0, pos: Variant = null) -> void:
	if end_freq < 0:
		end_freq = freq
	var key := "%d|%d|%d|%s|%d" % [roundi(freq / 10.0), roundi(dur * 100.0), roundi(end_freq / 10.0), type, roundi(vol * 50.0)]
	if not tones.has(key):
		if tones.size() > 400:
			tones.clear()
		tones[key] = to_wav(tone_buf(freq, dur, minf(vol * 2.0, 1.0), type, end_freq))
	_play(tones[key], 1.0, pos, 1.0, delay)

func shot(snd: String, vol := 1.0, pos: Variant = null, far := 0.0) -> void:
	_play(_pick("shot-%s@%d" % [snd, clampi(roundi(far * 3.0), 0, 3)]), vol, pos, randf_range(0.96, 1.04))

func shell(delay: float) -> void:
	_play(_pick("shell"), 1.0, null, 1.0, delay)

func swoosh(vol := 0.5) -> void:
	_play(_pick("swoosh"), vol * 1.4, null, randf_range(0.9, 1.1))

func groan(vol: float, pos: Variant, kind := "idle") -> void:
	if kind == "idle":
		if G.now - last_groan < 0.7:
			return
		last_groan = G.now
	_play(_pick("groan-" + kind), vol * 1.3, pos)

func bite(vol: float) -> void:
	_play(_pick("bite"), vol)

func boom(vol := 1.0, pos: Variant = null, far := 0.0) -> void:
	_play(_pick(_far_key("boom", far)), vol, pos, randf_range(0.92, 1.05))

func stun_bang(vol: float, pos: Variant, far: float, ring: float) -> void:
	_play(_pick("stun"), vol, pos)
	if ring > 0.05:
		_play(_pick("ring"), ring * 2.0, null, 1.0, 0.12)

func smoke_hiss(vol: float, pos: Variant) -> void:
	_play(_pick("hiss"), vol, pos)

func ray_sfx() -> void:
	_play(_pick("ray"), 1.0)

func rocket_launch(pos: Variant = null) -> void:
	_play(_pick("rocket"), 1.0, pos)

func mech(kind: String) -> void:
	_play(_pick("mech-" + kind), 1.0)

func boss_horn() -> void:
	_play(_pick("horn"), 1.0)

func boing() -> void:
	_play(_pick("boing"), 1.0)
	swoosh(0.4)

func bounce(vol: float, pos: Variant = null) -> void:
	tone(randf_range(900, 1300), 0.05, 0.07 * vol, "triangle", 650, 0.0, pos)

func powerup(type: String) -> void:
	var base: float = { "jump": 440, "haste": 520, "ammo": 392, "quad": 294, "god": 587 }.get(type, 440)
	var i := 0
	for m in [1.0, 1.26, 1.5, 2.0]:
		tone(base * m, 0.22, 0.13, "triangle" if i % 2 else "sawtooth", base * m * 1.01, i * 0.06)
		i += 1
	tone(base / 2, 0.5, 0.18, "sine", base / 4)

func power_spawn(vol: float) -> void:
	tone(330, 0.3, 0.1 * vol, "sine", 990)
	tone(660, 0.3, 0.06 * vol, "triangle", 1320, 0.08)

func pickup(high: bool) -> void:
	var b := 660.0 if high else 520.0
	tone(b, 0.09, 0.14, "triangle", b)
	tone(b * 1.25, 0.09, 0.14, "triangle", b * 1.25, 0.07)
	tone(b * 1.5, 0.16, 0.14, "triangle", b * 1.5, 0.14)

func box_open() -> void:
	var i := 0
	for f in [523, 659, 784, 1046, 1318]:
		tone(f, 0.3, 0.1, "triangle", f, i * 0.08)
		i += 1

func box_reveal(tier: String) -> void:
	var base: float = { "common": 392, "uncommon": 440, "rare": 523, "epic": 587, "legendary": 659 }.get(tier, 440)
	var i := 0
	for m in [1.0, 1.26, 1.5, 2.0, 2.52]:
		tone(base * m, 0.4, 0.09, "triangle" if i % 2 else "sine", base * m, i * 0.05)
		i += 1

func ui_hover() -> void:
	var p := cat
	cat = "ui"
	tone(2100, 0.035, 0.025, "sine", 2300)
	cat = p

func ui_click(strong: bool) -> void:
	var p := cat
	cat = "ui"
	if strong:
		tone(660, 0.09, 0.07, "triangle", 660); tone(990, 0.14, 0.07, "triangle", 990, 0.06)
	else:
		tone(1200, 0.05, 0.06, "triangle", 900)
	cat = p

# ============================================================ music: a song in the menus, a seamless loop during the match
const SONGS := { "classic": "res://assets/music/classica.ogg", "zombie": "res://assets/music/zombie.ogg" }
const LOOPS := { "classic": "res://assets/music/classica_loop.ogg", "zombie": "res://assets/music/zombie_loop.ogg" }

func _stream(path: String) -> AudioStream:
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s

# scene: 'menu' (song of the selected mode), 'game' (loop), 'pause' (loop, quieter)
func set_music(scene: String) -> void:
	music_want = scene
	if scene == "menu":
		if song_key != G.mode or not song.playing:
			song_key = G.mode
			song.stream = _stream(SONGS[G.mode])
			song_vol = 0.0
			song.play()
	elif scene == "game":
		duck = 1.0
		if loop_key != G.mode or not loop.playing:
			loop_key = G.mode
			loop.stream = _stream(LOOPS[G.mode])
			loop_vol = 0.0
			loop.play()
	elif scene == "pause":
		duck = 0.35

func _process(dt: float) -> void:
	var want_song := 1.0 if music_want == "menu" else 0.0
	song_vol = move_toward(song_vol, want_song, dt * (1.0 if want_song > song_vol else 1.2))
	song.volume_db = linear_to_db(maxf(0.0001, song_vol * 0.6))
	if song_vol <= 0.0 and song.playing and want_song == 0.0:
		song.stop()
	var want_loop := duck if music_want == "game" or music_want == "pause" else 0.0
	loop_vol = move_toward(loop_vol, want_loop, dt * 0.9)
	loop.volume_db = linear_to_db(maxf(0.0001, loop_vol * 0.6))
	if loop_vol <= 0.0 and loop.playing and want_loop == 0.0:
		loop.stop()
		loop_key = ""
