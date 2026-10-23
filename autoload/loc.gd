extends Node
## Builds the translations at startup from `i18n/strings.json` ({KEY: {en: ..., ru: ...}}), so a new
## language or line needs no import step. Autoload `Loc`.

const STRINGS_PATH := "res://i18n/strings.json"
const LANGUAGES: Array[String] = ["en", "ru"]

func _enter_tree() -> void:
	var table = JSON.parse_string(FileAccess.get_file_as_string(STRINGS_PATH))
	if typeof(table) != TYPE_DICTIONARY:
		push_error("Loc: %s is not a JSON object" % STRINGS_PATH)
		return
	for code in LANGUAGES:
		var t := Translation.new()
		t.locale = code
		for key in table:
			var entry: Dictionary = table[key]
			if entry.has(code):
				t.add_message(key, entry[code])
		TranslationServer.add_translation(t)
