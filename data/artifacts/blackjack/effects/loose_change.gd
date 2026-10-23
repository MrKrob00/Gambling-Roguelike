extends "res://data/artifact_effect.gd"
## Passive: a quarter of the purse stays in the pocket, out of the stake, so a loss does not take everything.

const KEEP := 0.25
const ROUND_TO := 5

func modify_stake(purse: int) -> int:
	return purse - int(purse * KEEP / ROUND_TO) * ROUND_TO

func hand_dealt(table) -> void:
	if table.run.chips > 0:
		notify()
