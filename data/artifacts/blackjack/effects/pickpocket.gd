extends "res://data/artifact_effect.gd"
## Active: takes the dealer's open card into the player's hand; the dealer gets a fresh one in its place.

func use(table) -> void:
	table.steal_dealer_card()
