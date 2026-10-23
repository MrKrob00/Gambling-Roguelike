extends "res://data/artifact_effect.gd"
## Consumable: one failed payment is forgiven and the house hands over the last loan once more.

const Rules := preload("res://core/rules.gd")

func prevent_death(run) -> bool:
	if charges_left <= 0:
		return false
	spend()
	notify()
	run.add_chips(Rules.loan_for(run.payments_paid))
	return true
