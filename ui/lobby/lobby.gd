extends Control
## The collection: every artifact of the game, tinted by kind. A locked one shows how to open it.
## Picking artifacts happens at the table now, in offers.

const ArtifactTile := preload("res://ui/common/artifact_tile.gd")
const InfoPanel := preload("res://ui/common/artifact_info_panel.gd")

const GAME_ID := &"blackjack"

@onready var grid: GridContainer = %Grid
@onready var info_host: Control = %InfoHost
@onready var open_label: Label = %OpenLabel
@onready var back_button: Button = %BackButton

var _info

func _ready() -> void:
	_info = InfoPanel.new()
	info_host.add_child(_info)
	_info.custom_minimum_size = Vector2(230, 0)
	var all := Catalog.for_game(GAME_ID)
	var open := 0
	for a in all:
		var tile := ArtifactTile.new()
		var is_locked: bool = not Profile.is_unlocked(a)
		open += 0 if is_locked else 1
		grid.add_child(tile)
		tile.bind(a, is_locked)
		tile.pressed.connect(_inspect.bind(tile))
		tile.inspected.connect(_inspect)
	open_label.text = tr("LOBBY_OPEN") % [open, all.size()]
	back_button.pressed.connect(func() -> void: Game.goto(Game.SCENE_MENU))
	Events.language_changed.connect(func(_c: String) -> void: _ready_refresh(all))
	if grid.get_child_count() > 0:
		_inspect(grid.get_child(0))

func _ready_refresh(all: Array) -> void:
	var open := all.filter(func(a): return Profile.is_unlocked(a)).size()
	open_label.text = tr("LOBBY_OPEN") % [open, all.size()]

func _inspect(tile) -> void:
	Audio.sfx(&"ui/ui_hover", 1.0, -6.0)
	if tile.locked:
		_info.show_locked(tile.data)
	else:
		_info.show_artifact(tile.data)
