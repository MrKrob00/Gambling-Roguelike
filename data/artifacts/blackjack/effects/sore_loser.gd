extends "res://data/artifact_effect.gd"
## Passive: after a lost hand the next one starts with a ten (a ten is slipped on top of the shoe before the deal).

const Card := preload("res://core/card.gd")

var _armed := false

func hand_ended(table, outcome: int) -> void:
	if outcome == table.Outcome.LOSE or outcome == table.Outcome.BUST:
		_armed = true

func hand_started(table) -> void:
	super.hand_started(table)
	if _armed:
		_armed = false
		table.shoe.cards.append(Card.new(10, 0))
		notify()
