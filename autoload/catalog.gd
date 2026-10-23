extends Node
## Read-only list of every artifact. Autoload `Catalog`.

const CATALOG_PATH := "res://data/catalog.tres"

var _all: Array = []
var _by_id: Dictionary = {}

func _ready() -> void:
	var cat: Resource = load(CATALOG_PATH)
	_all = cat.artifacts
	for a in _all:
		_by_id[a.id] = a

func all() -> Array:
	return _all

func for_game(game_id: StringName) -> Array:
	return _all.filter(func(a): return a.game_id == game_id)

func by_id(id: StringName):
	return _by_id.get(id)
