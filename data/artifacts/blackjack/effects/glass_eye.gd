extends "res://data/artifact_effect.gd"
## Passive: the next card of the shoe is laid face up beside it at the start of every hand.

func hand_dealt(table) -> void:
	notify()
	table.peek_next_card()
