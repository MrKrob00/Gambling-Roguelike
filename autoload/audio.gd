extends Node
## One door for sound. `Audio.sfx(&"ui/ui_click")` plays assets/audio/sfx/ui/ui_click.ogg. Autoload `Audio`.
## Every sound is loaded at startup: loading on the first press made the first click lag behind the tap.

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 10

var sfx_volume_db: float = 0.0
var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)
	_preload_dir("")

func sfx(sfx_name: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _stream(sfx_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = sfx_volume_db + volume_db
			p.play()
			return

func music(path: String) -> void:
	var stream: AudioStream = load(path)
	if stream == null or _music.stream == stream:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_music.stop()
	_music.stream = null

## Walks the sfx folders; an exported build lists `x.ogg.import` or `x.ogg.remap`, so the suffix is cut.
func _preload_dir(sub: String) -> void:
	var dir := DirAccess.open(SFX_DIR + sub)
	if dir == null:
		return
	for d in dir.get_directories():
		_preload_dir(sub + d + "/")
	for f in dir.get_files():
		var base := f.trim_suffix(".import").trim_suffix(".remap")
		if base.ends_with(".ogg"):
			var key := StringName(sub + base.trim_suffix(".ogg"))
			if not _cache.has(key):
				_cache[key] = load(SFX_DIR + sub + base)

func _stream(sfx_name: StringName) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var path := "%s%s.ogg" % [SFX_DIR, sfx_name]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Audio: missing sfx %s" % path)
	_cache[sfx_name] = stream
	return stream
