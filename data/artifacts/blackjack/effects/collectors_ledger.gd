extends "res://data/artifact_effect.gd"
## Cursed: the debt due is 30% smaller, but the deadline comes a hand sooner.

const DISCOUNT := 0.7

func modify_payment(amount: int) -> int:
	return int(ceil(amount * DISCOUNT))

func affects_payment() -> bool:
	return true

func modify_deadline(hands: int) -> int:
	return hands - 1
