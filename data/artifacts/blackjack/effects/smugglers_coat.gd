extends "res://data/artifact_effect.gd"
## Passive: the pocket holds two more artifacts while the coat is on. Every hand in it opens the Clenched Fist.

const Stat := preload("res://core/stat.gd")

func modify_pocket_size(size: int) -> int:
	return size + 2

func hand_ended(_table, _outcome: int) -> void:
	Events.stat_added.emit(Stat.CHEST_HANDS, 1)
