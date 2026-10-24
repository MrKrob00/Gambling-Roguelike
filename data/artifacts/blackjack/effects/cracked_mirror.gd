extends "res://data/artifact_effect.gd"
## Active: shows the next card of the shoe. Using it is what opens the Marked Deck.

const Stat := preload("res://core/stat.gd")

func use(table) -> void:
	table.peek_next_card()
	Events.stat_added.emit(Stat.MIRROR_USES, 1)
