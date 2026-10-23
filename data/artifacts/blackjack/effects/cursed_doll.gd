extends "res://data/artifact_effect.gd"
## Cursed: wins pay a quarter more, losses cost a quarter more.

const SWING := 0.25

func modify_payout(table, payout: int, outcome: int) -> int:
	var extra := int(table.bet * SWING)
	if payout > table.bet:
		return payout + extra
	if payout < table.bet:
		return payout - extra
	return payout
