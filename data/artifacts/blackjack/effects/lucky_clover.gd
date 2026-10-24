extends "res://data/artifact_effect.gd"
## Consumable: undoes a bust. The card is dealt first, so its harm is seen; then the artifact acts, and only then does the
## card go back on top of the shoe (the steps play in the order they are raised).

func prevent_bust(table) -> bool:
	if charges_left <= 0:
		return false
	notify()
	spend()
	table.discard_last_player_card()
	# The undone card now lies on top of the shoe: lay it face up beside the deck, as the Cracked Mirror does.
	table.peek_next_card()
	return true
