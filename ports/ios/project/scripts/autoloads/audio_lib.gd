extends Node

const SFX_RATE := 22050
const MUSIC_RATE := 16000
const MUSIC_BAR := 1.0
const MUSIC_BARS := 4

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _current_music := 0
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _music_tween: Tween
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 31337
	_setup_buses()
	print("AudioLib: generuje SFX...")
	_build_sfx()
	print("AudioLib: generuje warstwy muzyczne...")
	for lvl in 4:
		_music[lvl] = _wav(_synth_layer(lvl), MUSIC_RATE, true)
	_make_pool(12)
	_active_player = AudioStreamPlayer.new()
	_inactive_player = AudioStreamPlayer.new()
	_active_player.bus = "Music"
	_inactive_player.bus = "Music"
	add_child(_active_player)
	add_child(_inactive_player)
	_active_player.volume_db = -6.0
	_inactive_player.volume_db = -60.0
	_active_player.stream = _music[0]
	_active_player.play()
	print("AudioLib ready.")

static func _saw(f: float, t: float) -> float:
	return sin(TAU * f * t) * 0.65 + sin(TAU * 2.0 * f * t) * 0.3 + sin(TAU * 3.0 * f * t) * 0.15

static func _sq(f: float, t: float) -> float:
	return sin(TAU * f * t) * 0.7 + sin(TAU * 3.0 * f * t) * 0.25 + sin(TAU * 5.0 * f * t) * 0.12

func _wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

func _norm(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var mx := 0.0001
	for s in samples:
		mx = maxf(mx, absf(s))
	var k := peak / mx
	for i in samples.size():
		samples[i] *= k
	return samples

func _build_sfx() -> void:
	_sfx["shot"] = _wav(_norm(_synth_shot(), 0.95), SFX_RATE)
	_sfx["hit"] = _wav(_norm(_synth_hit(), 0.8), SFX_RATE)
	_sfx["enemy_die"] = _wav(_norm(_synth_die(), 0.95), SFX_RATE)
	_sfx["player_damage"] = _wav(_norm(_synth_damage(), 0.9), SFX_RATE)
	_sfx["pickup_heal"] = _wav(_norm(_synth_heal(), 0.75), SFX_RATE)
	_sfx["pickup_overdrive"] = _wav(_norm(_synth_overdrive_on(), 0.85), SFX_RATE)
	_sfx["overdrive_off"] = _wav(_norm(_synth_overdrive_off(), 0.7), SFX_RATE)
	_sfx["wave_start"] = _wav(_norm(_synth_wave_start(), 0.95), SFX_RATE)
	_sfx["wave_clear"] = _wav(_norm(_synth_wave_clear(), 0.75), SFX_RATE)
	_sfx["game_over"] = _wav(_norm(_synth_game_over(), 0.9), SFX_RATE)

func _synth_shot() -> PackedFloat32Array:
	var n := int(0.09 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var noise := _rng.randf() * 2.0 - 1.0
		out[i] = noise * exp(-55.0 * t) * 0.6 \
			+ sin(TAU * (200.0 - 1100.0 * t) * t) * exp(-30.0 * t) * 0.8
	return out

func _synth_hit() -> PackedFloat32Array:
	var n := int(0.05 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		out[i] = (_rng.randf() * 2.0 - 1.0) * exp(-70.0 * t) * 0.55 \
			+ sin(TAU * (900.0 + 900.0 * t) * t) * exp(-60.0 * t) * 0.45
	return out

func _synth_die() -> PackedFloat32Array:
	var n := int(0.4 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		out[i] = _saw(300.0 - 620.0 * t, t) * exp(-8.0 * t) * 0.45 \
			+ (_rng.randf() * 2.0 - 1.0) * exp(-12.0 * t) * 0.6 \
			+ sin(TAU * 70.0 * t) * exp(-20.0 * t) * 0.7
	return out

func _synth_damage() -> PackedFloat32Array:
	var n := int(0.3 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		out[i] = _sq(90.0, t) * exp(-10.0 * t) * 0.45 \
			+ (_rng.randf() * 2.0 - 1.0) * exp(-18.0 * t) * 0.55
	return out

func _synth_heal() -> PackedFloat32Array:
	var n := int(0.3 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var f := 330.0 + 1100.0 * t
		out[i] = sin(TAU * f * t) * exp(-5.0 * t) * 0.5 \
			+ sin(TAU * f * 2.0 * t) * exp(-5.0 * t) * 0.25
	return out

func _synth_overdrive_on() -> PackedFloat32Array:
	var n := int(0.5 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var f := 140.0 + 2500.0 * t
		out[i] = _saw(f, t) * exp(-3.0 * t) * 0.5 \
			+ (_rng.randf() * 2.0 - 1.0) * exp(-7.0 * t) * 0.3
	return out

func _synth_overdrive_off() -> PackedFloat32Array:
	var n := int(0.4 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var f := 1400.0 - 2800.0 * t
		out[i] = _saw(maxf(f, 60.0), t) * exp(-3.0 * t) * 0.5
	return out

func _synth_wave_start() -> PackedFloat32Array:
	var n := int(1.0 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var alarm_f := 440.0 if int(t / 0.18) % 2 == 0 else 554.0
		out[i] = sin(TAU * 60.0 * t) * exp(-6.0 * t) * 0.8 \
			+ sin(TAU * alarm_f * t) * (0.5 + 0.5 * sin(TAU * 2.7 * t)) * 0.22 * exp(-t)
	return out

func _synth_wave_clear() -> PackedFloat32Array:
	var n := int(0.6 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var s := 0.0
		for nt in 3:
			var nf: float = [440.0, 659.25, 880.0][nt]
			var nt0 := nt * 0.2
			if t >= nt0:
				s += sin(TAU * nf * t) * exp(-9.0 * (t - nt0)) * 0.3
		out[i] = s
	return out

func _synth_game_over() -> PackedFloat32Array:
	var n := int(1.6 * SFX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SFX_RATE
		var s := 0.0
		var seq := [[0.0, 220.0], [0.25, 196.0], [0.5, 164.81], [0.75, 130.81]]
		for nt in seq:
			if t >= nt[0]:
				s += _saw(nt[1], t) * exp(-3.5 * (t - nt[0])) * 0.32
		s += sin(TAU * 55.0 * t) * exp(-2.2 * t) * 0.5
		out[i] = s
	return out

func _synth_layer(lvl: int) -> PackedFloat32Array:
	var total := MUSIC_BAR * MUSIC_BARS
	var n := int(total * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [
		[55.0, 110.0, 130.81, 164.81],
		[43.65, 87.31, 110.0, 130.81],
		[65.41, 130.81, 164.81, 196.0],
		[49.0, 98.0, 123.47, 146.83],
	]
	var scale1 := [220.0, 261.63, 293.66, 329.63, 392.0, 440.0]
	var scale2 := [440.0, 523.25, 587.33, 659.25, 783.99]
	for i in n:
		var t := float(i) / MUSIC_RATE
		var bar := int(t / MUSIC_BAR) % MUSIC_BARS
		var bt := t - float(bar) * MUSIC_BAR
		var c: Array = chords[bar]
		var env := sin(PI * minf(bt, 1.0))
		env *= env
		var s := 0.0
		if lvl >= 0:
			for k in 3:
				s += _saw(c[1 + k], t) * 0.16 * env
		if lvl >= 1:
			var idx := int(bt / 0.25)
			var st := float(idx) * 0.25
			if bt >= st and bt - st < 0.16:
				s += _saw(c[0], t) * 0.22 * exp(-38.0 * (bt - st))
		if lvl >= 2:
			var stp := 0.0625
			var hidx := int(bt / stp)
			var hst := float(hidx) * stp
			if bt >= hst and bt - hst < 0.05:
				s += (_rng.randf() * 2.0 - 1.0) * 0.05 * exp(-160.0 * (bt - hst))
			var aidx := int(bt / 0.125) % scale1.size()
			var ast := float(int(bt / 0.125)) * 0.125
			if bt >= ast and bt - ast < 0.09:
				s += _sq(scale1[aidx], t) * 0.11 * exp(-70.0 * (bt - ast))
		if lvl >= 3:
			var kidx := int(bt / 0.25)
			var kst := float(kidx) * 0.25
			if bt >= kst and bt - kst < 0.16:
				s += sin(TAU * (85.0 - 130.0 * (bt - kst)) * t) * 0.34 * exp(-26.0 * (bt - kst))
			var bidx := int(bt / 0.0625) % scale2.size()
			var bst := float(int(bt / 0.0625)) * 0.0625
			if bt >= bst and bt - bst < 0.05:
				s += _sq(scale2[bidx] * 0.5, t) * 0.10 * exp(-90.0 * (bt - bst))
			if bt < 0.25:
				s += (_rng.randf() * 2.0 - 1.0) * 0.06 * exp(-22.0 * bt)
		out[i] = s
	return out

func play_sfx(key: String, pitch := 1.0, db := 0.0) -> void:
	if not _sfx.has(key):
		return
	var p: AudioStreamPlayer = null
	for candidate in _pool:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _pool[_pool_idx]
		_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = _sfx[key]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()

func set_music_intensity(lvl: int) -> void:
	lvl = clampi(lvl, 0, 3)
	if _active_player.playing and _current_music == lvl:
		return
	if _music_tween:
		_music_tween.kill()
	_current_music = lvl
	var old := _active_player
	var new := _inactive_player
	new.stream = _music[lvl]
	new.volume_db = -40.0
	var playback_position := fmod(old.get_playback_position(), MUSIC_BAR * MUSIC_BARS) if old.playing else 0.0
	new.play(playback_position)
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(new, "volume_db", -6.0, 0.4)
	_music_tween.tween_property(old, "volume_db", -40.0, 0.4)
	_music_tween.chain().tween_callback(func():
		if old != _active_player and old.playing:
			old.stop())
	_active_player = new
	_inactive_player = old

func rumble(weak := 0.0, strong := 0.0, dur := 0.1) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	Input.start_joy_vibration(pads[0], weak, strong, dur)

func duck_music(on: bool) -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, -7.0 if on else 0.0)

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)

func _make_pool(count: int) -> void:
	for i in count:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
