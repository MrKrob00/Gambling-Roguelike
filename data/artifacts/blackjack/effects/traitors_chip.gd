extends "res://data/artifact_effect.gd"
## Active, between hands: the next hand is a bet on the dealer. The player's win is a loss, a lost hand pays 1:1 and a
## bust pays 2:1.

func can_use(table) -> bool:
	if not data.button or table.phase != table.Phase.BETTING or table.bet_against:
		return false
	return cooldown_left <= 0

func use(table) -> void:
	table.bet_against = true
