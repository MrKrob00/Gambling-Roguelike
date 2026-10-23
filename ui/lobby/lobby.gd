extends Control
## Pick up to three unlocked artifacts, then borrow chips and sit down.

const Rules := preload("res://core/rules.gd")
const ArtifactData := preload("res://data/artifact_data.gd")
const ArtifactTile := preload("res://ui/common/artifact_tile.gd")

const KIND_KEYS: Array[String] = ["KIND_ACTIVE", "KIND_PASSIVE", "KIND_CONSUMABLE", "KIND_CURSED"]
const GAME_ID := &"blackjack"

@onready var grid: GridContainer = %Grid
@onready var name_label: Label = %NameLabel
@onready var kind_label: Label = %KindLabel
@onready var desc_label: Label = %DescLabel
@onready var hint_label: Label = %HintLabel
@onready var slots_label: Label = %SlotsLabel
@onready var open_label: Label = %OpenLabel
@onready var borrow_button: Button = %BorrowButton
@onready var back_button: Button = %BackButton

var _tiles: Array = []
var _picked: Array = []

func _ready() -> void:
	var all := Catalog.for_game(GAME_ID)
	var open := 0
	for a in all:
		var tile := ArtifactTile.new()
		var is_locked: bool = not Profile.is_unlocked(a)
		open += 0 if is_locked else 1
		grid.add_child(tile)
		tile.bind(a, is_locked)
		tile.pressed.connect(_on_tile_pressed.bind(tile))
		tile.inspected.connect(_inspect)
		_tiles.append(tile)
	open_label.text = tr("LOBBY_OPEN") % [open, all.size()]
	borrow_button.pressed.connect(_on_borrow)
	back_button.pressed.connect(func() -> void: Game.goto(Game.SCENE_MENU))
	Events.language_changed.connect(func(_c: String) -> void: _refresh())
	_refresh()

func _on_tile_pressed(tile) -> void:
	Audio.sfx(&"ui/ui_click")
	if tile.locked:
		tile.button_pressed = false
	elif tile.button_pressed:
		if _picked.size() >= Rules.ARTIFACT_SLOTS:
			tile.button_pressed = false
		else:
			_picked.append(tile.data)
	else:
		_picked.erase(tile.data)
	_inspect(tile)
	_refresh()

func _inspect(tile) -> void:
	var a = tile.data
	if tile.locked:
		name_label.text = "???"
		kind_label.text = tr(KIND_KEYS[a.kind])
		desc_label.text = ""
		hint_label.text = tr("HINT_UNLOCK") % a.unlock_hint()
		return
	name_label.text = a.title()
	var kind := tr(KIND_KEYS[a.kind])
	if a.charges > 0:
		kind += "  " + tr("CHARGES") % a.charges
	kind_label.text = kind
	desc_label.text = a.description()
	hint_label.text = ""

func _refresh() -> void:
	slots_label.text = tr("LOBBY_SLOTS") % [_picked.size(), Rules.ARTIFACT_SLOTS]
	borrow_button.text = tr("LOBBY_BORROW") % Rules.START_CHIPS
	for t in _tiles:
		if not t.locked and not t.button_pressed:
			t.modulate = Color.WHITE if _picked.size() < Rules.ARTIFACT_SLOTS else Color(1, 1, 1, 0.55)

func _on_borrow() -> void:
	Audio.sfx(&"ui/ui_confirm")
	Game.start_run(GAME_ID, _picked.duplicate())
