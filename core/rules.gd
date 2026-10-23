extends RefCounted
## Numbers that tune the whole game. One place, so balance is not hunted through scripts.

const START_CHIPS := 500
const MIN_BET := 10
const BET_STEPS: Array[int] = [10, 25, 100, 500]
const ARTIFACT_SLOTS := 3
## Artifacts come in offers: one free at the start, then one free for every loan paid off.
const OFFER_SIZE := 3

## The debt. Every PAYMENT_EVERY hands the collectors take INSTALLMENT_SHARE of what is owed, then
## charge interest on what is left; the sum is the new debt. The rate climbs with every payment.
## Paying the whole debt at once closes the loan: a free artifact offer, and a bigger loan.
const PAYMENT_EVERY := 5
const FIRST_LOAN := 500
const LOAN_GROWTH := 1.5
const INSTALLMENT_SHARE := 0.25
const INTEREST_BASE := 0.15
const INTEREST_STEP := 0.05
const INTEREST_MAX := 0.6
const MONEY_ROUND_TO := 5

const BLACKJACK_PAYOUT := 1.5
const DEALER_STANDS_ON := 17
const SHOE_DECKS := 6
const RESHUFFLE_BELOW := 0.25

static func loan_for(closed: int) -> int:
	return int(ceil(FIRST_LOAN * pow(LOAN_GROWTH, closed) / MONEY_ROUND_TO)) * MONEY_ROUND_TO

static func installment_for(debt: int) -> int:
	return mini(debt, int(ceil(debt * INSTALLMENT_SHARE / MONEY_ROUND_TO)) * MONEY_ROUND_TO)

static func interest_rate_for(payments_paid: int) -> float:
	return minf(INTEREST_BASE + INTEREST_STEP * payments_paid, INTEREST_MAX)
