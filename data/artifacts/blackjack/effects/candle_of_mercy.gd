extends "res://data/artifact_effect.gd"
## Consumable: one failed payment is forgiven and the player keeps a few chips.

const MERCY_CHIPS := 50

func prevent_death(run) -> bool:
	if charges_left <= 0:
		return false
	spend()
	notify()
	if run.chips < MERCY_CHIPS:
		run.add_chips(MERCY_CHIPS - run.chips)
	return true
