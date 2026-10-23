extends "res://data/artifact_effect.gd"
## Consumable, button: the last card turns into an Ace.

func use(table) -> void:
	table.last_player_card_becomes_ace()
