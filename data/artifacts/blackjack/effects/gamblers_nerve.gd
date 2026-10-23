extends "res://data/artifact_effect.gd"
## Passive: a won hand of four or more cards pays half a stake more (nerve to keep hitting).

const BONUS := 0.5
const MIN_CARDS := 4

func modify_payout(table, payout: int, _outcome: int) -> int:
	if table.player.cards.size() >= MIN_CARDS and payout > table.bet:
		notify()
		return payout + int(table.bet * BONUS)
	return payout
