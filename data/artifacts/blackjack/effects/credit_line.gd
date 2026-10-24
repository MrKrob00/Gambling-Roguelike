extends "res://data/artifact_effect.gd"
## Passive: a double down is allowed with an empty purse. The chips borrowed for it are added to the debt.

func allows_credit_double(_table) -> bool:
	return true
