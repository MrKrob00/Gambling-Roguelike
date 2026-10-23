extends RefCounted
## Several decks shuffled together. The rng is injectable so tests can replay a shoe.

const Card := preload("res://core/card.gd")

var rng := RandomNumberGenerator.new()
var decks: int = 6
var cards: Array = []
var total: int = 0

func _init(deck_count: int = 6, seed_value: int = -1) -> void:
	decks = deck_count
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	shuffle()

func shuffle() -> void:
	cards.clear()
	for d in decks:
		for suit in 4:
			for rank in range(1, 14):
				cards.append(Card.new(rank, suit))
	total = cards.size()
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func draw():
	if cards.is_empty():
		shuffle()
	return cards.pop_back()

func remaining_fraction() -> float:
	return float(cards.size()) / float(total)
