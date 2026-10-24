extends "res://data/artifact_effect.gd"
## Cursed: two more hands before a debt falls due, but every new loan is a tenth smaller.

const EXTRA_HANDS := 2
const LOAN_SHARE := 0.9

func modify_deadline(hands: int) -> int:
	return hands + EXTRA_HANDS

func modify_new_loan(loan: int) -> int:
	return int(loan * LOAN_SHARE)

func affects_loan() -> bool:
	return true
