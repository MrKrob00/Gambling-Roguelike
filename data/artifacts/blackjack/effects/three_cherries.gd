extends "res://data/artifact_effect.gd"
## Passive: a won hand of three or more cards that makes exactly 21 pays a whole stake more.

const MIN_CARDS := 3

func modify_payout(table, payout: int, _outcome: int) -> int:
	if payout > table.bet and table.player.cards.size() >= MIN_CARDS and table.player.total() == 21:
		notify()
		return payout + table.bet
	return payout
