extends "res://data/artifact_effect.gd"
## Active: the next three cards of the shoe are laid out face up; the player takes one, the rest go to the bottom.

func can_use(table) -> bool:
	return super.can_use(table) and table.draft.is_empty() and table.shoe.cards.size() >= 3

func use(table) -> void:
	table.begin_draft()
