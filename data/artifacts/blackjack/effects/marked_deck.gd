extends "res://data/artifact_effect.gd"
## Passive: every hand starts with the dealer's face-down card shown to you. The artifact announces itself first,
## then the card turns over (the view plays the steps in the order they are raised).

func hand_dealt(table) -> void:
	notify()
	table.peek_hole()
