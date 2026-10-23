extends RefCounted
## Numbers that tune the whole game. One place, so balance is not hunted through scripts.

const MIN_BET := 10
## Each death costs a finger of the right hand; the run ends with the fifth.
const LIVES := 5
const ARTIFACT_SLOTS := 3
## Artifacts come in offers: one free at the start, then one free for every debt paid.
const OFFER_SIZE := 3

## The debt. The house lends `loan_for(n)` chips and the debt is written at once as DEBT_MULTIPLIER times
## that. Every stake is the whole purse (all in), so the loan is both the bankroll and the risk. The debt
## falls due after PAYMENT_EVERY hands; paying it early is allowed. Each next loan is LOAN_GROWTH times bigger.
const PAYMENT_EVERY := 5
const LOAN_FIRST := 100
const LOAN_GROWTH := 2.0
const DEBT_MULTIPLIER := 5
const MONEY_ROUND_TO := 5

const BLACKJACK_PAYOUT := 1.5
const DEALER_STANDS_ON := 17
const SHOE_DECKS := 6
const RESHUFFLE_BELOW := 0.25

static func loan_for(index: int) -> int:
	return int(round(LOAN_FIRST * pow(LOAN_GROWTH, index) / MONEY_ROUND_TO)) * MONEY_ROUND_TO

static func debt_for(index: int) -> int:
	return loan_for(index) * DEBT_MULTIPLIER
