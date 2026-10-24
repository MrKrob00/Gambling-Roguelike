extends "res://data/artifact_effect.gd"
## Passive: a lost hand gives half the stake back, so a loss does not take everything. Wins pay as usual.
## It works once every few hands: the counter shows how many are left.

const REFUND := 0.5
const ROUND_TO := 5
const COOLDOWN := 5

func modify_payout(table, payout: int, outcome: int) -> int:
	if outcome != table.Outcome.LOSE and outcome != table.Outcome.BUST:
		return payout
	if cooldown_left > 0 or table.bet <= 0:
		return payout
	cooldown_left = table.run.cooldown_for(COOLDOWN)
	notify()
	return maxi(payout, int(table.bet * REFUND / ROUND_TO) * ROUND_TO)
