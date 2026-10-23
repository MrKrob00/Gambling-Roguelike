extends "res://data/artifact_effect.gd"
## Cursed: payments are 30% smaller, but the table asks for a higher minimum bet.

const DISCOUNT := 0.7
const FORCED_MIN_BET := 25

func modify_payment(amount: int) -> int:
	return int(ceil(amount * DISCOUNT))

func affects_payment() -> bool:
	return true

func modify_min_bet(min_bet: int) -> int:
	return maxi(min_bet, FORCED_MIN_BET)
