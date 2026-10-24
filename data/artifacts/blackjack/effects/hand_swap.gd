extends "res://data/artifact_effect.gd"
## Active: the player's hand and the dealer's change places, the hidden card turns face up for its new owner.

func use(table) -> void:
	table.swap_hands()
