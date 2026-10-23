extends RefCounted
## Rules and state of one blackjack table. No nodes: the view listens to the signals below, and every
## rule decision is made here so artifacts, tests and the screen all see the same game.
## Chips of the bet leave the run's purse when placed; `payout` is what comes back at the end.

const Rules := preload("res://core/rules.gd")
const Stat := preload("res://core/stat.gd")
const Card := preload("res://core/card.gd")
const Shoe := preload("res://core/shoe.gd")
const Hand := preload("res://games/blackjack/blackjack_hand.gd")

enum Phase { BETTING, PLAYER_TURN, DEALER_TURN, RESOLVED }
enum Outcome { BLACKJACK, WIN, PUSH, LOSE, BUST }

signal phase_changed(phase: int)
signal bet_changed(bet: int)
signal card_dealt(to_dealer: bool, card, face_up: bool)
signal card_removed(to_dealer: bool, card)
signal hole_revealed(card)
signal hole_peeked(card)
signal shoe_shuffled
signal hand_cleared
signal hand_resolved(outcome: int, bet: int, payout: int)
signal trick_used(effect)

var run
var shoe
var player := Hand.new()
var dealer := Hand.new()
var phase: int = Phase.BETTING
var bet: int = 0
var doubled: bool = false
var hole_known: bool = false
var hole_shown: bool = false

func _init(run_state, seed_value: int = -1) -> void:
	run = run_state
	shoe = Shoe.new(Rules.SHOE_DECKS, seed_value)

# ---------------------------------------------------------------- queries

func is_player_turn() -> bool:
	return phase == Phase.PLAYER_TURN

func min_bet() -> int:
	return run.min_bet()

func can_add_bet(amount: int) -> bool:
	return phase == Phase.BETTING and amount <= run.chips

func can_deal() -> bool:
	return phase == Phase.BETTING and bet >= min_bet()

func can_double() -> bool:
	return is_player_turn() and player.cards.size() == 2 and not doubled and run.chips >= bet

# ---------------------------------------------------------------- betting

func add_bet(amount: int) -> void:
	if not can_add_bet(amount):
		return
	run.add_chips(-amount)
	bet += amount
	bet_changed.emit(bet)

func all_in() -> void:
	add_bet(run.chips)

func clear_bet() -> void:
	if phase != Phase.BETTING or bet == 0:
		return
	run.add_chips(bet)
	bet = 0
	bet_changed.emit(bet)

# ---------------------------------------------------------------- the hand

func deal() -> void:
	if not can_deal():
		return
	if shoe.remaining_fraction() < Rules.RESHUFFLE_BELOW:
		shoe.shuffle()
		shoe_shuffled.emit()
	player.clear()
	dealer.clear()
	doubled = false
	hole_known = false
	hole_shown = false
	for fx in run.effects:
		fx.hand_started(self)
	_draw(false, true)
	_draw(true, true)
	_draw(false, true)
	_draw(true, false)
	_set_phase(Phase.PLAYER_TURN)
	if player.is_blackjack() or dealer.is_blackjack():
		_reveal_hole()
		_settle()

func hit() -> void:
	if not is_player_turn():
		return
	_player_draw()

func stand() -> void:
	if not is_player_turn():
		return
	_set_phase(Phase.DEALER_TURN)
	_reveal_hole()
	while dealer.total() < Rules.DEALER_STANDS_ON:
		_draw(true, true)
	_settle()

func double_down() -> void:
	if not can_double():
		return
	run.add_chips(-bet)
	bet *= 2
	doubled = true
	bet_changed.emit(bet)
	if _player_draw() and is_player_turn():
		stand()

func next_hand() -> void:
	if phase != Phase.RESOLVED or not run.alive:
		return
	bet = 0
	player.clear()
	dealer.clear()
	hand_cleared.emit()
	bet_changed.emit(bet)
	_set_phase(Phase.BETTING)

# ---------------------------------------------------------------- artifact doors

func use_artifact(fx) -> void:
	if not fx.can_use(self):
		return
	fx.use(self)
	fx.spend()
	Events.stat_added.emit(Stat.TRICKS_USED, 1)
	trick_used.emit(fx)

func peek_hole() -> void:
	if dealer.cards.size() < 2 or hole_known:
		return
	hole_known = true
	hole_peeked.emit(dealer.cards[1])

func discard_last_player_card() -> void:
	var card = player.pop_last()
	card_removed.emit(false, card)

## Swaps the last card for a fresh one. Settles the hand if that makes 21 or a bust.
func replace_last_player_card() -> void:
	discard_last_player_card()
	_draw(false, true)
	_after_player_card()

func last_player_card_becomes_ace() -> void:
	var old = player.pop_last()
	card_removed.emit(false, old)
	var ace := Card.new(1, old.suit)
	player.add(ace)
	card_dealt.emit(false, ace, true)
	_after_player_card()

## Pays a price for a trick. Returns false if the player cannot afford it.
func hush_money(amount: int) -> bool:
	if run.chips < amount:
		return false
	run.add_chips(-amount)
	return true

# ---------------------------------------------------------------- internals

func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)

func _draw(to_dealer: bool, face_up: bool) -> void:
	var card = shoe.draw()
	(dealer if to_dealer else player).add(card)
	card_dealt.emit(to_dealer, card, face_up)

func _reveal_hole() -> void:
	if hole_shown:
		return
	hole_shown = true
	hole_revealed.emit(dealer.cards[1])

## Draws for the player. Returns true if the hand is still alive.
func _player_draw() -> bool:
	_draw(false, true)
	return _after_player_card()

func _after_player_card() -> bool:
	if player.is_bust():
		for fx in run.effects:
			if fx.prevent_bust(self):
				return true
		_settle()
		return false
	if player.total() == 21 and not doubled:
		stand()
		return false
	return true

func _outcome() -> int:
	if player.is_bust():
		return Outcome.BUST
	var p_bj := player.is_blackjack()
	var d_bj := dealer.is_blackjack()
	if p_bj and d_bj:
		return Outcome.PUSH
	if p_bj:
		return Outcome.BLACKJACK
	if d_bj:
		return Outcome.LOSE
	if dealer.is_bust() or player.total() > dealer.total():
		return Outcome.WIN
	if player.total() == dealer.total():
		return Outcome.PUSH
	return Outcome.LOSE

func _settle() -> void:
	_reveal_hole()
	var outcome := _outcome()
	_record(outcome)
	var payout := 0
	match outcome:
		Outcome.BLACKJACK:
			payout = bet + int(bet * Rules.BLACKJACK_PAYOUT)
		Outcome.WIN:
			payout = bet * 2
		Outcome.PUSH:
			payout = bet
	for fx in run.effects:
		payout = fx.modify_payout(self, payout, outcome)
	run.add_chips(payout)
	var settled_bet := bet
	bet = 0
	_set_phase(Phase.RESOLVED)
	hand_resolved.emit(outcome, settled_bet, payout)
	run.hand_finished(bet)

func _record(outcome: int) -> void:
	var won := outcome == Outcome.WIN or outcome == Outcome.BLACKJACK
	Events.stat_added.emit(Stat.HANDS_PLAYED, 1)
	if won:
		Events.stat_added.emit(Stat.HANDS_WON, 1)
		run.win_streak += 1
		Events.stat_peaked.emit(Stat.WIN_STREAK, run.win_streak)
		if doubled:
			Events.stat_added.emit(Stat.DOUBLES_WON, 1)
	elif outcome != Outcome.PUSH:
		run.win_streak = 0
	if outcome == Outcome.BLACKJACK:
		Events.stat_added.emit(Stat.BLACKJACKS, 1)
	if outcome == Outcome.BUST:
		Events.stat_added.emit(Stat.BUSTS, 1)

func dealer_event_for(outcome: int) -> StringName:
	match outcome:
		Outcome.BLACKJACK: return &"blackjack"
		Outcome.WIN: return &"player_wins"
		Outcome.PUSH: return &"push"
		Outcome.BUST: return &"player_bust"
	return &"player_loses"
