extends "res://data/artifact_effect.gd"
## Cursed: wins pay half a stake more, but a push counts as a loss.

const BONUS := 0.5

func modify_payout(table, payout: int, outcome: int) -> int:
	if outcome == table.Outcome.PUSH:
		notify()
		return 0
	if payout > table.bet:
		notify()
		return payout + int(table.bet * BONUS)
	return payout
