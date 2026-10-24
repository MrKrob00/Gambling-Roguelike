extends "res://data/artifact_effect.gd"
## Passive: the dealer stands on 16 instead of 17.

func modify_dealer_stands_on(total: int) -> int:
	return total - 1
