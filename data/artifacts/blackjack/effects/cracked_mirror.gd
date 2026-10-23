extends "res://data/artifact_effect.gd"
## Active: shows the next card of the shoe.

func use(table) -> void:
	table.peek_next_card()
