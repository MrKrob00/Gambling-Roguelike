extends "res://data/artifact_effect.gd"
## Passive: a won hand of 15 or less pays a whole stake more.

const MAX_TOTAL := 15

func modify_payout(table, payout: int, _outcome: int) -> int:
	if payout > table.bet and table.player.total() <= MAX_TOTAL:
		notify()
		return payout + table.bet
	return payout
