extends "res://data/artifact_effect.gd"
## Consumable: undoes a bust by discarding the card that caused it.

func prevent_bust(table) -> bool:
	if charges_left <= 0:
		return false
	table.discard_last_player_card()
	# The undone card now lies on top of the shoe: lay it face up beside the deck, as the Cracked Mirror does.
	table.peek_next_card()
	spend()
	notify()
	return true
