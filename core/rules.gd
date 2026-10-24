extends RefCounted
## Numbers that tune the whole game. One place, so balance is not hunted through scripts.

const MIN_BET := 10
## Each death costs a finger of the right hand; the run ends with the fifth.
const LIVES := 5
const ARTIFACT_SLOTS := 3
## Artifacts come in offers: one free at the start, then one free for every debt paid.
const OFFER_SIZE := 3

## The debt. The house lends `loan_for(n)` chips and writes a much bigger debt down at once. Every stake is the whole
## purse (all in), so a win doubles it and a loss is a death. Debt over loan is 1.7, 2.1, 2.6, 3.3, 4.1, 5.1...: the
## number of wins in a row a debt takes (1, 2, 2, 2, 3, 3...) climbs slowly while both amounts grow exponentially. The debt falls
## due after PAYMENT_EVERY hands; paying it early is allowed. Tuned with tools/balance.gd.
const PAYMENT_EVERY := 4
const LOAN_FIRST := 150
const LOAN_GROWTH := 2.0
const DEBT_FIRST := 250
const DEBT_GROWTH := 2.5
const MONEY_ROUND_TO := 5

const BLACKJACK_PAYOUT := 1.5
const DEALER_STANDS_ON := 17
const SHOE_DECKS := 6
const RESHUFFLE_BELOW := 0.25

static func loan_for(index: int) -> int:
	return _rounded(LOAN_FIRST * pow(LOAN_GROWTH, index))

static func debt_for(index: int) -> int:
	return _rounded(DEBT_FIRST * pow(DEBT_GROWTH, index))

static func _rounded(amount: float) -> int:
	return int(round(amount / MONEY_ROUND_TO)) * MONEY_ROUND_TO

## A hand that wins with this total or less (the dealer busted) opens the Pauper's Crown.
const LOW_WIN_TOTAL := 10

## Closing a debt and being left with fewer chips than this opens the Traitor's Chip.
const NARROW_PAYOFF_CHIPS := 10
