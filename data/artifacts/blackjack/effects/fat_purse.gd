extends "res://data/artifact_effect.gd"
## Cursed: new loans are half again as big, and the debts written with them are half again as big.

const LOAN_BONUS := 1.5
const DEBT_BONUS := 1.5
const ROUND_TO := 5

func modify_new_loan(loan: int) -> int:
	return int(round(loan * LOAN_BONUS / ROUND_TO)) * ROUND_TO

func modify_new_debt(debt: int) -> int:
	return int(round(debt * DEBT_BONUS / ROUND_TO)) * ROUND_TO

func affects_loan() -> bool:
	return true
