extends "res://data/artifact_effect.gd"
## Cursed: the pocket holds one artifact less, and a won hand pays half as much again.

const BONUS := 0.5

func modify_pocket_size(size: int) -> int:
	return size - 1

func modify_payout(table, payout: int, _outcome: int) -> int:
	if payout > table.bet:
		notify()
		return payout + int((payout - table.bet) * BONUS)
	return payout
