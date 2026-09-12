class_name SoundSynthesizer
extends RefCounted
## Generates 16-bit PCM AudioStreamWAV assets procedurally in memory at startup.
## Eliminates external audio file dependencies, ensures zero missing assets
## in exported builds, and provides crisp, responsive arcade/MOBA combat audio.

const MIX_RATE: int = 22050

## High-speed sci-fi projectile / laser chirp
static func create_laser_sfx() -> AudioStreamWAV:
	var duration: float = 0.22
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var freq: float = lerpf(980.0, 160.0, progress * progress)
		var env: float = (1.0 - progress) * (1.0 - progress)
		var wave: float = sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.0 * TAU)
		var val: int = clampi(int(wave * env * 0.7 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Melee weapon swing / whoosh
static func create_slash_sfx() -> AudioStreamWAV:
	var duration: float = 0.18
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = sin(progress * PI)
		var noise: float = randf_range(-1.0, 1.0)
		var tone: float = sin(t * (420.0 - progress * 240.0) * TAU)
		var wave: float = noise * 0.65 + tone * 0.35
		var val: int = clampi(int(wave * env * 0.75 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Punchy impact / crunch hit
static func create_hit_sfx() -> AudioStreamWAV:
	var duration: float = 0.20
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = exp(-progress * 14.0)
		var thud: float = sin(t * (120.0 - progress * 60.0) * TAU)
		var crunch: float = randf_range(-1.0, 1.0) * exp(-progress * 22.0)
		var wave: float = thud * 0.6 + crunch * 0.5
		var val: int = clampi(int(wave * env * 0.85 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Low rumbling explosion / blast
static func create_explosion_sfx() -> AudioStreamWAV:
	var duration: float = 0.45
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = exp(-progress * 7.0)
		var rumble: float = sin(t * 65.0 * TAU) + 0.5 * sin(t * 45.0 * TAU)
		var noise: float = randf_range(-1.0, 1.0)
		var wave: float = rumble * 0.45 + noise * 0.55
		var val: int = clampi(int(wave * env * 0.9 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Ethereal rising holy chime arpeggio (C-E-G-C)
static func create_heal_sfx() -> AudioStreamWAV:
	var duration: float = 0.40
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var wave: float = 0.0
		for note_idx in range(freqs.size()):
			var note_start: float = float(note_idx) * 0.07
			if t >= note_start:
				var note_t: float = t - note_start
				var note_env: float = exp(-note_t * 9.0)
				wave += sin(note_t * freqs[note_idx] * TAU) * note_env * 0.3
		var val: int = clampi(int(wave * 0.85 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Fast mobility dash / wind rush
static func create_dash_sfx() -> AudioStreamWAV:
	var duration: float = 0.24
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = sin(progress * PI)
		var noise: float = randf_range(-1.0, 1.0) * 0.6
		var pitch: float = 300.0 + sin(progress * PI) * 350.0
		var tone: float = sin(t * pitch * TAU) * 0.4
		var wave: float = noise + tone
		var val: int = clampi(int(wave * env * 0.7 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Spatial teleport / blink warp
static func create_blink_sfx() -> AudioStreamWAV:
	var duration: float = 0.28
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = exp(-progress * 6.0)
		var f: float = 350.0 + progress * progress * 1400.0
		var wave: float = sin(t * f * TAU) + 0.4 * sin(t * f * 2.5 * TAU)
		var val: int = clampi(int(wave * env * 0.75 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Bright dual-tone bell chime for gold earned
static func create_coin_sfx() -> AudioStreamWAV:
	var duration: float = 0.32
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = exp(-progress * 11.0)
		var bell1: float = sin(t * 1760.0 * TAU) * 0.5
		var bell2: float = sin(t * 2637.0 * TAU) * 0.5
		var wave: float = (bell1 + bell2) * env
		var val: int = clampi(int(wave * 0.8 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## UI button click
static func create_ui_click_sfx() -> AudioStreamWAV:
	var duration: float = 0.06
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = t / duration
		var env: float = 1.0 - progress
		var wave: float = sin(t * 1100.0 * TAU) * env
		var val: int = clampi(int(wave * 0.6 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Triumphant brass fanfare for victory
static func create_victory_sfx() -> AudioStreamWAV:
	var duration: float = 1.6
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	# C major fanfare notes: C4, E4, G4, C5
	var notes: Array[float] = [261.63, 329.63, 392.00, 523.25]
	var starts: Array[float] = [0.0, 0.22, 0.44, 0.72]
	var lens: Array[float] = [0.20, 0.20, 0.25, 0.85]
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var wave: float = 0.0
		for n in range(notes.size()):
			var st: float = starts[n]
			var ln: float = lens[n]
			if t >= st and t < st + ln:
				var nt: float = t - st
				var env: float = sin((nt / ln) * PI)
				wave += (sin(nt * notes[n] * TAU) + 0.4 * sin(nt * notes[n] * 2.0 * TAU)) * env * 0.4
		var val: int = clampi(int(wave * 0.85 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	return _make_stream(data)

## Looping atmospheric cyberpunk / MOBA battle music track (~8 seconds loop)
static func create_battle_music() -> AudioStreamWAV:
	var duration: float = 8.0 # 8 second loop (4 bars at 120 BPM)
	var samples: int = int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var beat_sec: float = 0.5 # 120 BPM
	# Bass root notes per bar: A (110Hz), F (87.3Hz), C (130.8Hz), G (98Hz)
	var bass_notes: Array[float] = [110.0, 87.31, 130.81, 98.00]
	for i in range(samples):
		var t: float = float(i) / float(MIX_RATE)
		var bar_idx: int = clampi(int(t / 2.0), 0, 3)
		var root_freq: float = bass_notes[bar_idx]

		# 1. Pulse kick on every beat
		var beat_t: float = fmod(t, beat_sec)
		var kick_env: float = exp(-beat_t * 18.0)
		var kick: float = sin(beat_t * (100.0 - beat_t * 160.0) * TAU) * kick_env * 0.45

		# 2. Driving bassline (8th notes)
		var eighth_t: float = fmod(t, beat_sec * 0.5)
		var bass_env: float = exp(-eighth_t * 8.0)
		var bass: float = sin(eighth_t * root_freq * TAU) * bass_env * 0.35

		# 3. Synth arpeggio (16th notes)
		var sixteenth_idx: int = int(t / (beat_sec * 0.25))
		var arp_offset: int = sixteenth_idx % 4
		var arp_mults: Array[float] = [1.0, 1.2, 1.5, 2.0]
		var arp_freq: float = root_freq * 4.0 * arp_mults[arp_offset]
		var arp_t: float = fmod(t, beat_sec * 0.25)
		var arp_env: float = exp(-arp_t * 12.0)
		var arp: float = sin(arp_t * arp_freq * TAU) * arp_env * 0.18

		# 4. Hi-hat rhythm
		var hat_t: float = fmod(t + beat_sec * 0.25, beat_sec * 0.5)
		var hat_env: float = exp(-hat_t * 35.0)
		var hat: float = randf_range(-1.0, 1.0) * hat_env * 0.12

		var total: float = kick + bass + arp + hat
		var val: int = clampi(int(total * 0.75 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)

	var stream := _make_stream(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream

static func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
