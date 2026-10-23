extends "res://data/artifact_effect.gd"
## Consumable, button: cuts the debt by a quarter. Works between hands too.

const CUT := 0.25

func can_use(table) -> bool:
	if charges_left <= 0:
		return false
	return table.phase == table.Phase.BETTING or table.is_player_turn()

func use(table) -> void:
	table.run.reduce_debt(CUT)
