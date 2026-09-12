extends Node
## Autoload singleton: bus-based audio playback + simple music crossfade.
## Fed by the MCP asset pipeline (docs/ARCHITECTURE.md Section 1: Stable
## Audio 3 / ACE-Step via the "comfyui" MCP tool for generated music/SFX,
## plus the "freesound" MCP tool for real recorded SFX).

const SFX_POOL_SIZE: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_sfx_index: int = 0

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func play_music(stream: AudioStream, fade_sec: float = 1.0) -> void:
	if stream == null:
		return
	if _music_player.playing and fade_sec > 0.0:
		var tween: Tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_sec)
		tween.tween_callback(func() -> void:
			_music_player.stream = stream
			_music_player.volume_db = 0.0
			_music_player.play()
		)
	else:
		_music_player.stream = stream
		_music_player.play()

func stop_music(fade_sec: float = 1.0) -> void:
	if fade_sec <= 0.0:
		_music_player.stop()
		return
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_sec)
	tween.tween_callback(_music_player.stop)
