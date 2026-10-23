extends RefCounted
## A blackjack hand: the cards and what they are worth.

var cards: Array = []

func add(card) -> void:
	cards.append(card)

func clear() -> void:
	cards.clear()

func pop_last():
	return cards.pop_back()

func total() -> int:
	var sum := 0
	var aces := 0
	for c in cards:
		sum += c.hard_value()
		if c.is_ace():
			aces += 1
	if aces > 0 and sum + 10 <= 21:
		sum += 10
	return sum

func is_soft() -> bool:
	var hard := 0
	var aces := 0
	for c in cards:
		hard += c.hard_value()
		if c.is_ace():
			aces += 1
	return aces > 0 and hard + 10 <= 21

func is_blackjack() -> bool:
	return cards.size() == 2 and total() == 21

func is_bust() -> bool:
	return total() > 21
