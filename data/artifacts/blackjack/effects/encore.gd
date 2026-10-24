extends "res://data/artifact_effect.gd"
## Passive: once per loan a trick that has just been used is given back at once, so it can be repeated.
## A loan is told by the debts paid and the fingers left: either changes when the house lends again.

var _used_for_loan := -1

func _loan_id(run) -> int:
	return run.payments_paid * 10 + run.lives

func encore(table, used) -> void:
	if used == self or not used.data.button or _used_for_loan == _loan_id(table.run):
		return
	_used_for_loan = _loan_id(table.run)
	if used.data.uses_per_hand > 0:
		used.uses_left += 1
	if used.data.charges > 0:
		used.charges_left += 1
	used.cooldown_left = 0
	notify()
