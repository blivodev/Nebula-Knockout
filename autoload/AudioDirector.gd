extends Node
## Autoload singleton: bus-based audio playback + procedural sound synthesis.
## Generates crisp retro/arcade MOBA SFX and looping music in memory at startup.

const SoundSynthesizer = preload("res://core/audio/SoundSynthesizer.gd")

const SFX_POOL_SIZE: int = 12

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_sfx_index: int = 0

# Cached procedural sound streams
var sfx_laser: AudioStreamWAV
var sfx_slash: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_explosion: AudioStreamWAV
var sfx_heal: AudioStreamWAV
var sfx_dash: AudioStreamWAV
var sfx_blink: AudioStreamWAV
var sfx_coin: AudioStreamWAV
var sfx_ui: AudioStreamWAV
var sfx_victory: AudioStreamWAV
var music_battle: AudioStreamWAV

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_synthesize_audio()

func _synthesize_audio() -> void:
	sfx_laser = SoundSynthesizer.create_laser_sfx()
	sfx_slash = SoundSynthesizer.create_slash_sfx()
	sfx_hit = SoundSynthesizer.create_hit_sfx()
	sfx_explosion = SoundSynthesizer.create_explosion_sfx()
	sfx_heal = SoundSynthesizer.create_heal_sfx()
	sfx_dash = SoundSynthesizer.create_dash_sfx()
	sfx_blink = SoundSynthesizer.create_blink_sfx()
	sfx_coin = SoundSynthesizer.create_coin_sfx()
	sfx_ui = SoundSynthesizer.create_ui_click_sfx()
	sfx_victory = SoundSynthesizer.create_victory_sfx()
	music_battle = SoundSynthesizer.create_battle_music()

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func play_laser() -> void:
	play_sfx(sfx_laser, -2.0)

func play_slash() -> void:
	play_sfx(sfx_slash, -1.0)

func play_hit() -> void:
	play_sfx(sfx_hit, 0.0)

func play_explosion() -> void:
	play_sfx(sfx_explosion, 1.0)

func play_heal() -> void:
	play_sfx(sfx_heal, -1.0)

func play_dash() -> void:
	play_sfx(sfx_dash, -2.0)

func play_blink() -> void:
	play_sfx(sfx_blink, -1.0)

func play_coin() -> void:
	play_sfx(sfx_coin, 0.0)

func play_ui() -> void:
	play_sfx(sfx_ui, -3.0)

func play_victory() -> void:
	play_sfx(sfx_victory, 2.0)

func start_battle_music() -> void:
	if music_battle != null:
		play_music(music_battle, 0.5)

func play_music(stream: AudioStream, fade_sec: float = 1.0) -> void:
	if stream == null:
		return
	if _music_player.playing and fade_sec > 0.0:
		var tween: Tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_sec)
		tween.tween_callback(func() -> void:
			_music_player.stream = stream
			_music_player.volume_db = -6.0
			_music_player.play()
		)
	else:
		_music_player.stream = stream
		_music_player.volume_db = -6.0
		_music_player.play()

func stop_music(fade_sec: float = 1.0) -> void:
	if fade_sec <= 0.0:
		_music_player.stop()
		return
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_sec)
	tween.tween_callback(_music_player.stop)
