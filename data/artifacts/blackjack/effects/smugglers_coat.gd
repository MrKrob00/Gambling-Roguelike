extends "res://data/artifact_effect.gd"
## Passive: the pocket holds two more artifacts while the backpack is on or in the pocket. Every hand in it opens the Clenched Fist.

const Stat := preload("res://core/stat.gd")

func works_in_pocket() -> bool:
	return true

func modify_pocket_size(size: int) -> int:
	return size + 2

func hand_ended(_table, _outcome: int) -> void:
	Events.stat_added.emit(Stat.CHEST_HANDS, 1)
