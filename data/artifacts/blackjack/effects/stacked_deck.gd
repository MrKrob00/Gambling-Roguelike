extends "res://data/artifact_effect.gd"
## Active: buries the next card at the bottom of the shoe and shows the one beneath.

func use(table) -> void:
	table.bury_next_card()
