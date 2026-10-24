extends "res://data/artifact_effect.gd"
## Passive: a free offer shows one artifact more.

const EXTRA := 1

func modify_offer_size(size: int) -> int:
	return size + EXTRA
