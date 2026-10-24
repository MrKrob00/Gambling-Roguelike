extends "res://data/artifact_effect.gd"
## Consumable, between hands: the hand gives up a finger and the collectors let the whole debt go. The purse is topped up
## to the payment and the debt is paid now. It cannot take the last finger.

func can_use(table) -> bool:
	var run = table.run
	return charges_left > 0 and table.phase == table.Phase.BETTING and run.alive and run.lives > 1 and run.offer_stage != run.Offer.CHOOSING

func use(table) -> void:
	table.run.pawn_finger()
