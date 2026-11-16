extends Node
## Sound effects and music (autoload "AudioManager").
##
## HOW TO ADD YOUR OWN AUDIO
## 1. Copy your "audio" folder into the project root (res://audio/).
## 2. Easiest: do nothing. Each sound is found automatically by KEYWORDS in the
##    file name (see SOUND_KEYWORDS / MUSIC_KEYWORDS below), e.g. "laser_shot.wav"
##    is used for the player laser because it contains "laser".
## 3. Exact control: type the file name next to the sound in SOUND_FILES or
##    MUSIC_FILES, e.g. "player_laser": "sfx/zap01.ogg" (path is relative to res://audio/).
## Sounds that cannot be found are skipped (SFX use a built-in beep instead).
## See SETUP_GUIDE.md for details.

const AUDIO_DIR := "res://audio/"

## Kenney UI sounds that came with your UI pack (always available).
const UI_SOUNDS := {
	"ui_click": "res://assets/ui/kenney_ui_audio/click1.ogg",
	"ui_hover": "res://assets/ui/kenney_ui_audio/rollover1.ogg",
	"ui_switch": "res://assets/ui/kenney_ui_audio/switch2.ogg",
}

const AUDIO_EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]

## Exact file names (relative to res://audio/). Leave "" to use keyword search.
const SOUND_FILES := {
	"player_laser": "",
	"enemy_laser": "",
	"explosion": "",
	"hit": "",
	"boost": "",
	"warning": "",
	"victory": "",
	"game_over": "",
}

## Words searched for in file names when no exact file name is given.
const SOUND_KEYWORDS := {
	"player_laser": ["player_laser", "laser", "shoot", "blaster", "pew", "fire"],
	"enemy_laser": ["enemy_laser", "enemy_shoot", "laser2", "laser", "shoot", "blaster"],
	"explosion": ["explosion", "explode", "boom", "blast", "destroy", "crash"],
	"hit": ["hit", "impact", "damage", "hurt", "bump"],
	"boost": ["boost", "afterburner", "thruster", "whoosh", "engine"],
	"warning": ["warning", "alarm", "alert", "siren"],
	"victory": ["victory", "win", "complete", "success", "fanfare", "level_up"],
	"game_over": ["game_over", "gameover", "lose", "defeat", "fail", "death"],
}

## Exact music file names (relative to res://audio/). Leave "" to use keyword search.
const MUSIC_FILES := {
	"menu": "",
	"space": "",
	"planet": "",
}

const MUSIC_KEYWORDS := {
	"menu": ["menu", "title", "intro", "theme", "music", "loop"],
	"space": ["space", "level1", "level_1", "battle", "combat", "action", "music", "loop"],
	"planet": ["planet", "level2", "level_2", "surface", "canyon", "combat", "music", "loop"],
}

const SFX_POOL_SIZE := 10
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var music_volume_db: float = -8.0
var sfx_volume_db: float = 0.0

var _audio_files: Array[String] = []
var _stream_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _music_player: AudioStreamPlayer
var _current_music_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()
	_scan_audio_folder(AUDIO_DIR)
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = music_volume_db
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)


## Plays a sound effect by key (see SOUND_FILES / UI_SOUNDS).
func play_sfx(key: String, volume_offset_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _get_sfx_stream(key)
	if stream == null:
		return
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.pitch_scale = pitch
	player.play()


## Plays looping background music by key ("menu", "space", "planet").
func play_music(key: String) -> void:
	if key == _current_music_key and _music_player.playing:
		return
	_current_music_key = key
	var stream := _get_music_stream(key)
	if stream == null:
		_music_player.stop()
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_current_music_key = ""
	_music_player.stop()


func _on_music_finished() -> void:
	# Loops every track, whatever its file format.
	if _current_music_key != "":
		_music_player.play()


func _get_sfx_stream(key: String) -> AudioStream:
	if _stream_cache.has(key):
		return _stream_cache[key]
	var stream: AudioStream = null
	if UI_SOUNDS.has(key):
		stream = load(UI_SOUNDS[key]) as AudioStream
	else:
		stream = _find_stream(key, SOUND_FILES, SOUND_KEYWORDS)
		if stream == null:
			stream = _make_fallback_sound(key)
	_stream_cache[key] = stream
	return stream


func _get_music_stream(key: String) -> AudioStream:
	var cache_key := "music_" + key
	if _stream_cache.has(cache_key):
		return _stream_cache[cache_key]
	var stream := _find_stream(key, MUSIC_FILES, MUSIC_KEYWORDS)
	_stream_cache[cache_key] = stream
	return stream


func _find_stream(key: String, exact_files: Dictionary, keywords: Dictionary) -> AudioStream:
	var exact_name: String = exact_files.get(key, "")
	if exact_name != "":
		var exact_path := AUDIO_DIR + exact_name
		if ResourceLoader.exists(exact_path):
			return load(exact_path) as AudioStream
		push_warning("AudioManager: '%s' not found for sound '%s'" % [exact_path, key])
	var word_list: Array = keywords.get(key, [])
	for word in word_list:
		for path in _audio_files:
			if path.get_file().to_lower().contains(String(word)):
				return load(path) as AudioStream
	return null


func _scan_audio_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		# Exported games list resources with an extra ".import" or ".remap" suffix.
		var clean_name := file_name.trim_suffix(".import").trim_suffix(".remap")
		if AUDIO_EXTENSIONS.has(clean_name.get_extension().to_lower()):
			var full_path := path.path_join(clean_name)
			if not _audio_files.has(full_path):
				_audio_files.append(full_path)
	for sub_dir in dir.get_directories():
		_scan_audio_folder(path.path_join(sub_dir))
	_audio_files.sort()


func _create_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


# --- Built-in fallback sounds (used only when no audio file is found) ---------

func _make_fallback_sound(key: String) -> AudioStream:
	match key:
		"player_laser":
			return _synth_sweep(1500.0, 350.0, 0.16, 0.35)
		"enemy_laser":
			return _synth_sweep(700.0, 220.0, 0.2, 0.3)
		"explosion":
			return _synth_noise(0.7, 0.6, 6.0)
		"hit":
			return _synth_noise(0.12, 0.5, 20.0)
		"boost":
			return _synth_noise(0.5, 0.25, 3.0)
		"warning":
			return _synth_sweep(900.0, 900.0, 0.25, 0.25)
		"victory":
			return _synth_sweep(500.0, 1100.0, 0.6, 0.3)
		"game_over":
			return _synth_sweep(500.0, 120.0, 0.9, 0.3)
	return null


func _synth_sweep(start_hz: float, end_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		var frequency := lerpf(start_hz, end_hz, t)
		phase += TAU * frequency / float(sample_rate)
		var envelope := (1.0 - t) * minf(1.0, t * 40.0)
		var sample := signf(sin(phase)) * 0.5 + sin(phase) * 0.5
		data.encode_s16(i * 2, int(sample * envelope * volume * 32767.0))
	return _make_wav(data, sample_rate)


func _synth_noise(duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var smoothed := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.35)
		var envelope := exp(-decay * t)
		data.encode_s16(i * 2, int(smoothed * envelope * volume * 32767.0))
	return _make_wav(data, sample_rate)


func _make_wav(data: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
