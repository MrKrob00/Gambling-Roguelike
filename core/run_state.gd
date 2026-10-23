extends RefCounted
## Everything that lives for one run: chips, payments, equipped artifacts. No nodes.

const Rules := preload("res://core/rules.gd")
const Stat := preload("res://core/stat.gd")

signal chips_changed(chips: int)
signal countdown_changed(hands_left: int, amount: int)
signal payment_made(amount: int, index: int)
signal payment_waived(index: int)
signal died(reason: StringName)

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

func _init(game: StringName, loadout: Array) -> void:
	game_id = game
	artifacts = loadout
	for a in loadout:
		var fx = a.effect_script.new()
		fx.bind(a)
		effects.append(fx)
	chips = Rules.START_CHIPS
	peak_chips = chips

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
	else:
		if _survives():
			payments_paid += 1
			hands_to_payment = Rules.PAYMENT_EVERY
			payment_waived.emit(payments_paid)
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
