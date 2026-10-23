extends Control

const Stat := preload("res://core/stat.gd")
const AMBIENCE := "res://assets/audio/ambience/dark_cavern_ambient_001.ogg"

@onready var play_button: Button = %PlayButton
@onready var collection_button: Button = %CollectionButton
@onready var language_button: Button = %LanguageButton
@onready var quit_button: Button = %QuitButton
@onready var record_label: Label = %RecordLabel

func _ready() -> void:
	play_button.pressed.connect(_on_play)
	collection_button.pressed.connect(_on_collection)
	language_button.pressed.connect(_on_language)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	Events.language_changed.connect(_on_language_changed)
	Audio.music(AMBIENCE)
	_refresh()

func _refresh() -> void:
	language_button.text = Profile.locale.to_upper()
	var best := Profile.stat(Stat.BEST_PAYMENTS)
	record_label.text = tr("MENU_RECORD") % best if best > 0 else ""

func _on_play() -> void:
	Audio.sfx(&"ui/ui_confirm")
	Game.start_run(&"blackjack")

func _on_collection() -> void:
	Audio.sfx(&"ui/ui_click")
	Game.goto(Game.SCENE_LOBBY)

func _on_language() -> void:
	Audio.sfx(&"ui/ui_click")
	var i := Loc.LANGUAGES.find(Profile.locale)
	Profile.set_locale_code(Loc.LANGUAGES[(i + 1) % Loc.LANGUAGES.size()])

func _on_language_changed(_code: String) -> void:
	_refresh()
