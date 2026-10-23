extends "res://data/artifact_effect.gd"
## Passive: every hand starts with the dealer's face-down card shown to you.

func hand_dealt(table) -> void:
	table.peek_hole()
	notify()
