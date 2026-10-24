extends "res://data/artifact_effect.gd"
## Consumable, between hands: the pocket holds one more artifact for the rest of the run.

const Stat := preload("res://core/stat.gd")

func can_use(table) -> bool:
	return charges_left > 0 and table.phase == table.Phase.BETTING and table.run.alive and table.run.offer_stage != table.run.Offer.CHOOSING and table.run.pocket_capacity() < 6

func use(table) -> void:
	table.run.pocket_bonus += 1
	Events.stat_added.emit(Stat.POCKET_STITCHES, 1)
