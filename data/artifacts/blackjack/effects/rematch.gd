extends "res://data/artifact_effect.gd"
## Passive: when a hand would end in a push, the dealer's last card is changed for a fresh one and he plays on.
## It needs a few hands to recharge.

const COOLDOWN := 3

func rematch(table) -> bool:
	if cooldown_left > 0:
		return false
	cooldown_left = COOLDOWN
	notify()
	table.replace_dealer_last_card()
	return true
