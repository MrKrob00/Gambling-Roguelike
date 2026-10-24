extends "res://data/artifact_effect.gd"
## Passive: a won double down pays half a stake more.

const BONUS := 0.5

func modify_payout(table, payout: int, _outcome: int) -> int:
	if table.doubled and payout > table.bet:
		notify()
		return payout + int(table.bet * BONUS)
	return payout
