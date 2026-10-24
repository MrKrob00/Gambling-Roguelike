extends "res://data/artifact_effect.gd"
## Active: buries the next card at the bottom of the shoe and shows the one beneath. Using it opens the Glass Eye.

const Stat := preload("res://core/stat.gd")

func use(table) -> void:
	table.bury_next_card()
	Events.stat_added.emit(Stat.STACKED_USES, 1)
