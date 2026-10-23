extends "res://data/artifact_effect.gd"
## Consumable, button: the dealer stands on whatever he has this hand.

func can_use(table) -> bool:
	return super.can_use(table) and not table.dealer_frozen

func use(table) -> void:
	table.freeze_dealer()
