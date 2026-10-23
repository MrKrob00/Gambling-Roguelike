extends "res://data/artifact_effect.gd"
## Passive: a natural blackjack pays 2:1 instead of 3:2.

func modify_payout(table, payout: int, outcome: int) -> int:
	if outcome == table.Outcome.BLACKJACK:
		notify()
		return table.bet * 3
	return payout
