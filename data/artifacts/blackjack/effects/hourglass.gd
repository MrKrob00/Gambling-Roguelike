extends "res://data/artifact_effect.gd"
## Consumable, button: two more hands before the debt falls due. Works between hands too.

const EXTRA_HANDS := 2

func can_use(table) -> bool:
	if charges_left <= 0 or cooldown_left > 0:
		return false
	return table.phase == table.Phase.BETTING or table.is_player_turn()

func use(table) -> void:
	table.run.extend_deadline(EXTRA_HANDS)
