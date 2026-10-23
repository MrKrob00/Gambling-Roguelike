extends RefCounted
## Everything that lives for one run: chips, payments, equipped artifacts. No nodes.

const Rules := preload("res://core/rules.gd")
const Stat := preload("res://core/stat.gd")

signal chips_changed(chips: int)
signal countdown_changed(hands_left: int, amount: int)
signal payment_made(amount: int, index: int)
signal payment_waived(index: int)
## What the collectors do after a payment: `remainder` + `interest` (at `rate`) = `new_debt`.
signal interest_added(remainder: int, interest: int, rate: float, new_debt: int)
signal debt_changed(debt: int)
signal loan_closed(paid: int, new_loan: int)
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
var loans_closed: int = 0
## What is owed right now. The chips of every loan were handed over when it was taken.
var debt: int = Rules.FIRST_LOAN
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
	chips = Rules.START_CHIPS
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

func next_payment() -> int:
	var amount := Rules.installment_for(debt)
	for fx in effects:
		amount = fx.modify_payment(amount)
	return clampi(amount, 0, debt)

func interest_rate() -> float:
	return Rules.interest_rate_for(payments_paid)

func can_pay_off() -> bool:
	return alive and chips >= debt

## Pays everything owed at once: the only way to close a loan. The house lends a bigger one and
## opens a free artifact offer.
func pay_off() -> bool:
	if not can_pay_off():
		return false
	var paid := debt
	add_chips(-paid)
	loans_closed += 1
	debt = Rules.loan_for(loans_closed)
	add_chips(debt)
	hands_to_payment = Rules.PAYMENT_EVERY
	Events.stat_added.emit(Stat.LOANS_CLOSED, 1)
	loan_closed.emit(paid, debt)
	debt_changed.emit(debt)
	countdown_changed.emit(hands_to_payment, next_payment())
	start_free_offer()
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
	var amount := next_payment()
	var rate := interest_rate()
	if chips >= amount:
		for fx in effects:
			if fx.affects_payment():
				fx.notify()
		add_chips(-amount)
		debt -= amount
		payments_paid += 1
		hands_to_payment = Rules.PAYMENT_EVERY
		Events.stat_added.emit(Stat.PAYMENTS_PAID, 1)
		payment_made.emit(amount, payments_paid)
		_charge_interest(rate)
		if chips < min_bet():
			_try_die(DEATH_BROKE)
	elif _survives():
		payments_paid += 1
		hands_to_payment = Rules.PAYMENT_EVERY
		payment_waived.emit(payments_paid)
		_charge_interest(rate)
	else:
		_die(DEATH_DEBT)

## The unpaid rest grows: this is where the next debt comes from.
func _charge_interest(rate: float) -> void:
	var remainder := debt
	var interest := int(ceil(remainder * rate / Rules.MONEY_ROUND_TO)) * Rules.MONEY_ROUND_TO
	debt = remainder + interest
	interest_added.emit(remainder, interest, rate, debt)
	debt_changed.emit(debt)

func _try_die(reason: StringName) -> void:
	if not _survives():
		_die(reason)

func _survives() -> bool:
	for fx in effects:
		if fx.prevent_death(self):
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
