extends "res://data/artifact_effect.gd"
## Passive: every recharge is a hand shorter (never below one hand).

func modify_cooldown(hands: int) -> int:
	return maxi(hands - 1, 1)
