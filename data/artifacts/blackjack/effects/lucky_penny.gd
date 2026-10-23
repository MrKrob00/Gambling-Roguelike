extends "res://data/artifact_effect.gd"
## Passive: a push pays half a stake more.

const BONUS := 0.5

func modify_payout(table, payout: int, outcome: int) -> int:
	if outcome == table.Outcome.PUSH:
		notify()
		return payout + int(table.bet * BONUS)
	return payout
