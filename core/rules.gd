extends RefCounted
## Numbers that tune the whole game. One place, so balance is not hunted through scripts.

const START_CHIPS := 500
const MIN_BET := 10
const BET_STEPS: Array[int] = [10, 25, 100, 500]
const ARTIFACT_SLOTS := 3
## Artifacts come in offers: one free at the start, then one for sale after every payment.
const OFFER_SIZE := 3
const OFFER_COST_PERCENT := 0.3
const OFFER_MIN_COST := 20

## A payment is taken after every PAYMENT_EVERY resolved hands.
const PAYMENT_EVERY := 5
const FIRST_PAYMENT := 100
const PAYMENT_GROWTH := 1.5
const PAYMENT_ROUND_TO := 5

const BLACKJACK_PAYOUT := 1.5
const DEALER_STANDS_ON := 17
const SHOE_DECKS := 6
const RESHUFFLE_BELOW := 0.25

static func payment_for(index: int) -> int:
	var raw := FIRST_PAYMENT * pow(PAYMENT_GROWTH, index)
	return int(ceil(raw / PAYMENT_ROUND_TO)) * PAYMENT_ROUND_TO
