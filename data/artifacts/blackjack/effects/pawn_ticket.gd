extends "res://data/artifact_effect.gd"
## Passive: new debts are written a tenth smaller.

const DISCOUNT := 0.9
const ROUND_TO := 5

func modify_new_debt(debt: int) -> int:
	return int(round(debt * DISCOUNT / ROUND_TO)) * ROUND_TO

func affects_loan() -> bool:
	return true
