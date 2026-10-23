extends "res://data/artifact_effect.gd"
## Consumable, button: throws your hand away and deals two new cards.

func can_use(table) -> bool:
	return super.can_use(table) and not table.player.cards.is_empty()

func use(table) -> void:
	table.redeal_player_hand()
