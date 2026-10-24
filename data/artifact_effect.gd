extends RefCounted
## Base class of every artifact behaviour. A table or run calls these hooks; an artifact overrides
## only the ones it cares about. Hooks are the single doors: never patch a rule from the outside.

const ArtifactData := preload("res://data/artifact_data.gd")

## Emitted whenever the artifact actually does something, so the screen can show it.
signal triggered

var data: Resource
var uses_left: int = 0
var charges_left: int = 0
var cooldown_left: int = 0

func bind(artifact: Resource) -> void:
	data = artifact
	charges_left = artifact.charges

func hand_started(_table) -> void:
	uses_left = data.uses_per_hand
	cooldown_left = maxi(cooldown_left - 1, 0)

## Called once the opening cards are on the table (the hole card exists).
func hand_dealt(_table) -> void:
	pass

## Buttons only. Default: needs a charge or a use, and the player's turn.
func can_use(table) -> bool:
	if not data.button or not table.is_player_turn():
		return false
	if data.uses_per_hand > 0 and uses_left <= 0:
		return false
	if data.charges > 0 and charges_left <= 0:
		return false
	return cooldown_left <= 0

func use(_table) -> void:
	pass

func spend() -> void:
	if data.uses_per_hand > 0:
		uses_left -= 1
	if data.charges > 0:
		charges_left -= 1
	cooldown_left = data.cooldown_hands

## Consumables vanish once every charge is spent.
func is_spent() -> bool:
	return data.kind == ArtifactData.Kind.CONSUMABLE and data.charges > 0 and charges_left <= 0

## The player just went over 21. Return true after fixing the hand yourself.
func prevent_bust(_table) -> bool:
	return false

## `payout` is the chips returned for the bet (0 on a loss, may go negative for a curse).
func modify_payout(_table, payout: int, _outcome: int) -> int:
	return payout

func modify_payment(amount: int) -> int:
	return amount

## True for artifacts that change payments: they announce themselves when a payment is really taken
## (modify_payment is also asked just to display the amount, so it must not notify).
func affects_payment() -> bool:
	return false

func modify_min_bet(min_bet: int) -> int:
	return min_bet

## How much of the purse goes on the table (the stake is the whole purse unless an artifact says otherwise).
func modify_stake(purse: int) -> int:
	return purse

## Hands until a debt falls due.
func modify_deadline(hands: int) -> int:
	return hands

## The loan and the debt the house writes when one is closed (or lent again after losing a finger).
func modify_new_loan(loan: int) -> int:
	return loan

func modify_new_debt(debt: int) -> int:
	return debt

## True for artifacts that change the new loan or debt: they announce themselves when one is really written.
func affects_loan() -> bool:
	return false

## A hand has just been settled (after the payout), with its outcome. For things that carry over to the next hand.
func hand_ended(_table, _outcome: int) -> void:
	pass

## A hand is about to end in a push: return true after changing the dealer's hand so that it is played out again.
func rematch(_table) -> bool:
	return false

## True lets the player double down on credit when the purse is empty: the borrowed chips are added to the debt.
func allows_credit_double(_table) -> bool:
	return false

## How many artifacts a free offer shows.
func modify_offer_size(size: int) -> int:
	return size

## Another artifact's button has just been used (its use is already spent): give the use back to repeat the trick.
func encore(_table, _used) -> void:
	pass

## True if the artifact still changes the pocket's size while it lies in the pocket (a bag does, a curse does not).
func works_in_pocket() -> bool:
	return false

## How many artifacts the pocket holds (the size is passed through every artifact in hand).
func modify_pocket_size(size: int) -> int:
	return size

## How many hands an artifact needs to recharge (every artifact's own wait goes through here).
func modify_cooldown(hands: int) -> int:
	return hands

## The total the dealer stands on (17 in the rules).
func modify_dealer_stands_on(total: int) -> int:
	return total

## A payment could not be paid (or the player is broke). Return true to survive.
func prevent_death(_run) -> bool:
	return false

func notify() -> void:
	triggered.emit()

func charges_text() -> String:
	if cooldown_left > 0:
		return "(%d)" % cooldown_left
	return "%d" % charges_left if data.charges > 0 else ""
