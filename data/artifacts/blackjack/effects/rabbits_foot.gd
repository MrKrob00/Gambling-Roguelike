extends "res://data/artifact_effect.gd"
## Passive: wins in a streak of two or more pay a tenth of the bet more per streak step.

const PER_STEP := 0.1
const MAX_STEPS := 5

func modify_payout(table, payout: int, _outcome: int) -> int:
	if payout <= table.bet:
		return payout
	var steps := mini(table.run.win_streak, MAX_STEPS)
	if steps < 2:
		return payout
	notify()
	return payout + int(table.bet * PER_STEP * steps)
