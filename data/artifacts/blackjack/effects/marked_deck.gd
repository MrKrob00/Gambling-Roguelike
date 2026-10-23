extends "res://data/artifact_effect.gd"
## Active: shows the dealer's face-down card, once per hand.

func can_use(table) -> bool:
	return super.can_use(table) and not table.hole_known

func use(table) -> void:
	table.peek_hole()
