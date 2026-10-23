extends "res://data/artifact_effect.gd"
## Cursed: wins on 19 or more pay double, wins on 17 or less only return the stake.

const HIGH := 19
const LOW := 17

func modify_payout(table, payout: int, outcome: int) -> int:
	if outcome != table.Outcome.WIN and outcome != table.Outcome.BLACKJACK:
		return payout
	var total: int = table.player.total()
	if total >= HIGH:
		notify()
		return payout + table.bet
	if total <= LOW:
		notify()
		return table.bet
	return payout
