extends "res://data/artifact_effect.gd"
## Passive: payments are a tenth smaller.

const DISCOUNT := 0.9

func modify_payment(amount: int) -> int:
	return int(ceil(amount * DISCOUNT))

func affects_payment() -> bool:
	return true
