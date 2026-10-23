extends "res://data/artifact_effect.gd"
## Active: swaps the last card for a fresh one. Cheating costs hush money, taken out of the stake.

const HUSH_FRACTION := 0.2
const HUSH_MIN := 5

func hush_cost(table) -> int:
	return maxi(HUSH_MIN, int(table.bet * HUSH_FRACTION))

func can_use(table) -> bool:
	return super.can_use(table) and (table.run.chips >= hush_cost(table) or table.bet > hush_cost(table))

func use(table) -> void:
	table.hush_money(hush_cost(table))
	table.replace_last_player_card()
