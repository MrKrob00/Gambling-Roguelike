extends "res://data/artifact_effect.gd"
## Cursed: the debt due is 15% smaller, but the deadline comes a hand sooner.

const DISCOUNT := 0.85

func modify_payment(amount: int) -> int:
	return int(ceil(amount * DISCOUNT))

func affects_payment() -> bool:
	return true

func modify_deadline(hands: int) -> int:
	return hands - 1
