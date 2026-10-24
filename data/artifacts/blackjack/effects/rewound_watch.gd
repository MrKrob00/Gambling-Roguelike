extends "res://data/artifact_effect.gd"
## Consumable: every artifact is ready again at once, also between hands.

func can_use(table) -> bool:
	if charges_left <= 0:
		return false
	return table.run.effects.any(func(fx) -> bool: return fx != self and fx.cooldown_left > 0)

func use(table) -> void:
	for fx in table.run.effects:
		fx.cooldown_left = 0
