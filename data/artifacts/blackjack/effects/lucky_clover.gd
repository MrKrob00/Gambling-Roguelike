extends "res://data/artifact_effect.gd"
## Consumable: undoes a bust by discarding the card that caused it.

func prevent_bust(table) -> bool:
	if charges_left <= 0:
		return false
	table.discard_last_player_card()
	spend()
	return true
