extends Node
## Meta progress that survives deaths: counters, unlocked artifacts, settings. Autoload `Profile`.
## Counters arrive through `Events`; an unlock fires the moment its rule is met.

## Overridable so tests never touch the real save.
var save_path: String = "user://profile.json"
var stats: Dictionary = {}
var unlocked: Array = []
var locale: String = ""
## Unlocks earned since the player last looked, shown on the result screen.
var fresh_unlocks: Array = []

func _ready() -> void:
	_load()
	Events.stat_added.connect(_on_stat_added)
	Events.stat_peaked.connect(_on_stat_peaked)
	if locale.is_empty():
		locale = "ru" if OS.get_locale_language() == "ru" else "en"
	TranslationServer.set_locale(locale)

func stat(stat_name: StringName) -> int:
	return int(stats.get(String(stat_name), 0))

func is_unlocked(artifact) -> bool:
	return artifact.is_open_from_start() or String(artifact.id) in unlocked

func unlocked_for(game_id: StringName) -> Array:
	return Catalog.for_game(game_id).filter(func(a): return is_unlocked(a))

func set_locale_code(code: String) -> void:
	locale = code
	TranslationServer.set_locale(code)
	save()
	Events.language_changed.emit(code)

func take_fresh_unlocks() -> Array:
	var out := fresh_unlocks.duplicate()
	fresh_unlocks.clear()
	return out

func _on_stat_added(stat_name: StringName, amount: int) -> void:
	stats[String(stat_name)] = stat(stat_name) + amount
	_after_change()

func _on_stat_peaked(stat_name: StringName, value: int) -> void:
	if value > stat(stat_name):
		stats[String(stat_name)] = value
		_after_change()

func _after_change() -> void:
	for a in Catalog.all():
		if is_unlocked(a):
			continue
		if stat(a.unlock_stat) >= a.unlock_value:
			unlocked.append(String(a.id))
			fresh_unlocks.append(a)
			Events.artifact_unlocked.emit(a)
	save()

func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"stats": stats, "unlocked": unlocked, "locale": locale}))

func _load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	stats = data.get("stats", {})
	unlocked = data.get("unlocked", [])
	locale = data.get("locale", "")

## Wipes meta progress. Used by the options screen and by tests.
func reset() -> void:
	stats.clear()
	unlocked.clear()
	fresh_unlocks.clear()
	save()
