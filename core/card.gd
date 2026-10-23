extends RefCounted
## One playing card. Blackjack scoring lives in the hand, not here.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const RANK_LABELS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_ICONS := {
	Suit.CLUBS: "res://assets/art/icons/game_icons/cards_dice/clubs.svg",
	Suit.DIAMONDS: "res://assets/art/icons/game_icons/cards_dice/diamonds.svg",
	Suit.HEARTS: "res://assets/art/icons/game_icons/cards_dice/hearts.svg",
	Suit.SPADES: "res://assets/art/icons/game_icons/cards_dice/spades.svg",
}

var rank: int = 1
var suit: int = Suit.SPADES

func _init(r: int = 1, s: int = Suit.SPADES) -> void:
	rank = r
	suit = s

func label() -> String:
	return RANK_LABELS[rank]

func is_ace() -> bool:
	return rank == 1

func is_red() -> bool:
	return suit == Suit.DIAMONDS or suit == Suit.HEARTS

## Hard value: ace counts 1, faces 10. The hand decides whether an ace is worth 11.
func hard_value() -> int:
	return mini(rank, 10)

func icon_path() -> String:
	return SUIT_ICONS[suit]
