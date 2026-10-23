extends RefCounted
## Everything that lives for one run: chips, payments, equipped artifacts. No nodes.

const Rules := preload("res://core/rules.gd")
const Stat := preload("res://core/stat.gd")

signal chips_changed(chips: int)
signal countdown_changed(hands_left: int, amount: int)
signal payment_made(amount: int, index: int)
signal payment_waived(index: int)
signal debt_changed(debt: int)
## A debt was paid (on the deadline or early): the house lends `new_loan` chips and writes `new_debt`.
signal loan_closed(paid: int, new_loan: int, new_debt: int)
signal died(reason: StringName)
signal artifacts_changed
signal artifact_triggered(effect)
signal offer_changed

const DEATH_BROKE := &"broke"
const DEATH_DEBT := &"debt"

var game_id: StringName = &"blackjack"
var chips: int = 0
var hands_played: int = 0
var payments_paid: int = 0
## What is owed right now (`payments_paid` counts the debts already paid).
var debt: int = Rules.debt_for(0)
var hands_to_payment: int = Rules.PAYMENT_EVERY
var win_streak: int = 0
var peak_chips: int = 0
var alive: bool = true
var artifacts: Array = []
var effects: Array = []

enum Offer { NONE, CHOOSING }
## CHOOSING: `offer` holds the options. Offers are free and come only with a closed loan.
var offer_stage: int = Offer.NONE
var offer: Array = []
var rng := RandomNumberGenerator.new()

func _init(game: StringName, loadout: Array) -> void:
	game_id = game
	artifacts = loadout
	for a in loadout:
		_equip(a)
	chips = Rules.loan_for(0)
	peak_chips = chips
	rng.randomize()

func _equip(data) -> void:
	var fx = data.effect_script.new()
	fx.bind(data)
	fx.triggered.connect(artifact_triggered.emit.bind(fx))
	effects.append(fx)

func min_bet() -> int:
	var m := Rules.MIN_BET
	for fx in effects:
		m = fx.modify_min_bet(m)
	return m

## What the collectors take at the deadline.
func next_payment() -> int:
	var amount := debt
	for fx in effects:
		amount = fx.modify_payment(amount)
	return maxi(amount, 0)

func can_pay_off() -> bool:
	return alive and chips >= next_payment()

## Pays the debt now instead of waiting for the deadline.
func pay_off() -> bool:
	if not can_pay_off():
		return false
	_pay()
	return true

func add_chips(delta: int) -> void:
	chips = maxi(chips + delta, 0)
	if chips > peak_chips:
		peak_chips = chips
		Events.stat_peaked.emit(Stat.CHIPS_PEAK, peak_chips)
	chips_changed.emit(chips)

# ---------------------------------------------------------------- artifact offers

## Unlocked artifacts of this game that the player does not hold yet.
func offer_pool() -> Array:
	var held := effects.map(func(fx): return fx.data.id)
	return Profile.unlocked_for(game_id).filter(func(a): return not (a.id in held))

func slots_full() -> bool:
	return effects.size() >= Rules.ARTIFACT_SLOTS

## The free offer at the start of a run: straight to choosing.
func start_free_offer() -> void:
	_roll()

func skip_offer() -> void:
	offer_stage = Offer.NONE
	offer.clear()
	offer_changed.emit()

func _roll() -> void:
	var pool := offer_pool()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	offer = pool.slice(0, Rules.OFFER_SIZE)
	offer_stage = Offer.CHOOSING if not offer.is_empty() else Offer.NONE
	offer_changed.emit()

## Takes an offered artifact. With full slots `replace` must be one of the held effects.
func choose_offer(data, replace = null) -> bool:
	if offer_stage != Offer.CHOOSING or not (data in offer):
		return false
	if slots_full():
		if replace == null or not (replace in effects):
			return false
		effects.erase(replace)
	_equip(data)
	offer_stage = Offer.NONE
	offer.clear()
	artifacts_changed.emit()
	offer_changed.emit()
	return true

## Takes every spent consumable out of the slots. Called after anything that can spend a charge.
func retire_spent() -> void:
	var gone := effects.filter(func(fx): return fx.is_spent())
	if gone.is_empty():
		return
	for fx in gone:
		effects.erase(fx)
	artifacts_changed.emit()

func discard(effect) -> void:
	if effect in effects:
		effects.erase(effect)
		artifacts_changed.emit()

func announce() -> void:
	chips_changed.emit(chips)
	debt_changed.emit(debt)
	countdown_changed.emit(hands_to_payment, next_payment())

## Called by a table once a hand is fully settled. Handles the payment clock and death.
func hand_finished(bet_on_table: int) -> void:
	hands_played += 1
	hands_to_payment -= 1
	if hands_to_payment <= 0:
		_collect_payment()
	elif chips < min_bet() and bet_on_table == 0:
		_try_die(DEATH_BROKE)
	if alive:
		countdown_changed.emit(hands_to_payment, next_payment())

func _collect_payment() -> void:
	if chips >= next_payment():
		payment_made.emit(next_payment(), payments_paid + 1)
		_pay()
	elif _survives():
		hands_to_payment = Rules.PAYMENT_EVERY
		payment_waived.emit(payments_paid)
	else:
		_die(DEATH_DEBT)

## Takes the debt out of the purse, then the house lends a bigger loan and writes a bigger debt.
func _pay() -> void:
	var amount := next_payment()
	for fx in effects:
		if fx.affects_payment():
			fx.notify()
	add_chips(-amount)
	payments_paid += 1
	Events.stat_added.emit(Stat.PAYMENTS_PAID, 1)
	var loan := Rules.loan_for(payments_paid)
	debt = Rules.debt_for(payments_paid)
	add_chips(loan)
	hands_to_payment = Rules.PAYMENT_EVERY
	loan_closed.emit(amount, loan, debt)
	debt_changed.emit(debt)
	countdown_changed.emit(hands_to_payment, next_payment())
	start_free_offer()

func _try_die(reason: StringName) -> void:
	if not _survives():
		_die(reason)

func _survives() -> bool:
	for fx in effects:
		if fx.prevent_death(self):
			retire_spent()
			return true
	return false

func _die(reason: StringName) -> void:
	if not alive:
		return
	alive = false
	Events.stat_added.emit(Stat.DEATHS, 1)
	if reason == DEATH_DEBT:
		Events.stat_added.emit(Stat.DEBT_DEATHS, 1)
	Events.stat_peaked.emit(Stat.BEST_PAYMENTS, payments_paid)
	died.emit(reason)
	Events.run_ended.emit(self, reason)
