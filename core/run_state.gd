extends RefCounted
## Everything that lives for one run: chips, payments, equipped artifacts. No nodes.

const Rules := preload("res://core/rules.gd")
const Stat := preload("res://core/stat.gd")

signal chips_changed(chips: int)
signal countdown_changed(hands_left: int, amount: int)
signal payment_made(amount: int, index: int)
signal payment_waived(index: int)
signal died(reason: StringName)
signal artifacts_changed
signal offer_changed

const DEATH_BROKE := &"broke"
const DEATH_DEBT := &"debt"

var game_id: StringName = &"blackjack"
var chips: int = 0
var hands_played: int = 0
var payments_paid: int = 0
var hands_to_payment: int = Rules.PAYMENT_EVERY
var win_streak: int = 0
var peak_chips: int = 0
var alive: bool = true
var artifacts: Array = []
var effects: Array = []

enum Offer { NONE, PROPOSED, CHOOSING }
## PROPOSED: the house offers a new choice for `offer_cost` chips. CHOOSING: `offer` holds the options.
var offer_stage: int = Offer.NONE
var offer_cost: int = 0
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
	effects.append(fx)

func min_bet() -> int:
	var m := Rules.MIN_BET
	for fx in effects:
		m = fx.modify_min_bet(m)
	return m

func next_payment() -> int:
	var amount := Rules.payment_for(payments_paid)
	for fx in effects:
		amount = fx.modify_payment(amount)
	return maxi(amount, 0)

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
	offer_cost = 0

## The paid offer after a payment. Nothing to sell when the pool is empty.
func propose_paid_offer() -> void:
	if offer_pool().is_empty() or not alive:
		return
	offer_stage = Offer.PROPOSED
	offer_cost = maxi(Rules.OFFER_MIN_COST, int(next_payment() * Rules.OFFER_COST_PERCENT))
	offer_changed.emit()

func can_buy_offer() -> bool:
	return offer_stage == Offer.PROPOSED and chips >= offer_cost

func buy_offer() -> void:
	if not can_buy_offer():
		return
	add_chips(-offer_cost)
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
	if chips >= amount:
		add_chips(-amount)
		payments_paid += 1
		hands_to_payment = Rules.PAYMENT_EVERY
		Events.stat_added.emit(Stat.PAYMENTS_PAID, 1)
		payment_made.emit(amount, payments_paid)
		if chips < min_bet():
			_try_die(DEATH_BROKE)
		elif alive:
			propose_paid_offer()
	else:
		if _survives():
			payments_paid += 1
			hands_to_payment = Rules.PAYMENT_EVERY
			payment_waived.emit(payments_paid)
			propose_paid_offer()
		else:
			_die(DEATH_DEBT)

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
