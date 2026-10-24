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
signal next_card_peeked(card)
## Three cards of the shoe are laid out to pick from; `draft_closed` when one is taken.
signal draft_offered(cards: Array)
signal draft_closed
## The player's and the dealer's hands changed places.
signal hands_swapped
signal count_changed(value: int)

var run
var shoe
var player := Hand.new()
var dealer := Hand.new()
var phase: int = Phase.BETTING
var bet: int = 0
var doubled: bool = false
var hole_known: bool = false
var hole_shown: bool = false
## Set by an artifact: the dealer stands on whatever he has this hand.
var dealer_frozen: bool = false
## Set by an artifact before the deal: this hand the player bets on the dealer.
var bet_against: bool = false
## The three cards on offer while the player is choosing; empty otherwise.
var draft: Array = []
## The Hi-Lo running count of the cards seen since the shoe was shuffled.
var count: int = 0
var _hole_counted: bool = false

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
	return is_player_turn() and player.cards.size() == 2 and not doubled and (run.chips >= bet or _credit_double())

## The stake is always the whole purse: there is no choosing a bet. The view deals through this door.
func can_deal_all_in() -> bool:
	return phase == Phase.BETTING and run.stake_for(run.chips + bet) >= min_bet()

func deal_all_in() -> void:
	if can_deal_all_in():
		add_bet(run.stake_for(run.chips + bet) - bet)
		deal()

func can_pay_off() -> bool:
	return phase == Phase.BETTING and run.can_pay_off()

## Early repayment of the whole debt. Only between hands, so the clock and the offer cannot clash with a hand.
func pay_off() -> void:
	if can_pay_off():
		run.pay_off()

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
		count = 0
		count_changed.emit(count)
		Events.stat_added.emit(Stat.SHUFFLES, 1)
		shoe_shuffled.emit()
	player.clear()
	dealer.clear()
	doubled = false
	hole_known = false
	hole_shown = false
	dealer_frozen = false
	_hole_counted = false
	draft.clear()
	for fx in run.effects:
		fx.hand_started(self)
	_draw(false, true)
	_draw(true, true)
	_draw(false, true)
	_draw(true, false)
	_set_phase(Phase.PLAYER_TURN)
	if player.cards[0].rank == 7 and player.cards[1].rank == 7:
		Events.stat_added.emit(Stat.LUCKY_SEVENS, 1)
	for fx in run.effects:
		fx.hand_dealt(self)
	if player.is_blackjack() or dealer.is_blackjack():
		_reveal_hole()
		_settle()

func hit() -> void:
	if not is_player_turn() or not draft.is_empty():
		return
	_player_draw()

func stand() -> void:
	if not is_player_turn() or not draft.is_empty():
		return
	_set_phase(Phase.DEALER_TURN)
	_reveal_hole()
	while not dealer_frozen and dealer.total() < _dealer_stands_on():
		_draw(true, true)
	_settle()

## The effect that lets the player double on credit, or null.
func _credit_double():
	for fx in run.effects:
		if fx.allows_credit_double(self):
			return fx
	return null

func _dealer_stands_on() -> int:
	var total := Rules.DEALER_STANDS_ON
	for fx in run.effects:
		total = fx.modify_dealer_stands_on(total)
	return total

func double_down() -> void:
	if not can_double() or not draft.is_empty():
		return
	if run.chips < bet:
		var credit = _credit_double()
		credit.notify()
		run.borrow(bet - run.chips)
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
	if not draft.is_empty() or not fx.can_use(self):
		return
	fx.notify()  # the artifact announces itself first, then its effect plays
	fx.use(self)
	fx.spend()
	fx.cooldown_left = run.cooldown_for(fx.data.cooldown_hands) if fx.data.cooldown_hands > 0 else 0
	run.retire_spent()
	Events.stat_added.emit(Stat.TRICKS_USED, 1)
	trick_used.emit(fx)

## Shows the next card of the shoe without drawing it.
func peek_next_card() -> void:
	if not shoe.cards.is_empty():
		next_card_peeked.emit(shoe.cards.back())

## Buries the next card at the bottom of the shoe and shows the one under it.
func bury_next_card() -> void:
	if shoe.cards.size() < 2:
		return
	shoe.cards.insert(0, shoe.cards.pop_back())
	next_card_peeked.emit(shoe.cards.back())

func freeze_dealer() -> void:
	dealer_frozen = true

## Throws the whole hand to the bottom of the shoe and deals two new cards.
func redeal_player_hand() -> void:
	while not player.cards.is_empty():
		discard_last_player_card(false)
	_draw(false, true)
	_draw(false, true)
	_after_player_card()

func peek_hole() -> void:
	if dealer.cards.size() < 2 or hole_known:
		return
	hole_known = true
	_see_hole()
	hole_peeked.emit(dealer.cards[1])

## The card goes back into the shoe: on top (an undone draw, the next draw is the same card) or at the bottom.
func discard_last_player_card(back_on_top: bool = true) -> void:
	var card = player.pop_last()
	if back_on_top:
		shoe.cards.append(card)
	else:
		shoe.cards.insert(0, card)
	card_removed.emit(false, card)

## Swaps the last card for a fresh one. Settles the hand if that makes 21 or a bust.
func replace_last_player_card() -> void:
	discard_last_player_card(false)
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
	if run.chips >= amount:
		run.add_chips(-amount)
		return true
	if bet > amount:
		bet -= amount
		bet_changed.emit(bet)
		return true
	return false

## Changes the dealer's last card for a fresh one and lets him play on. The Rematch does it when a hand would be a push.
func replace_dealer_last_card() -> void:
	var old = dealer.pop_last()
	shoe.cards.insert(0, old)
	card_removed.emit(true, old)
	_draw(true, true)
	while not dealer_frozen and dealer.total() < _dealer_stands_on():
		_draw(true, true)

## Lays the next three cards of the shoe out to choose from (`pick_draft`).
func begin_draft() -> void:
	if shoe.cards.size() < 3 or not draft.is_empty():
		return
	draft = [shoe.cards[-1], shoe.cards[-2], shoe.cards[-3]]
	draft_offered.emit(draft)

## Takes card `index` of the draft into the player's hand; the other two go to the bottom of the shoe.
func pick_draft(index: int) -> void:
	if draft.is_empty() or index < 0 or index >= draft.size():
		return
	var chosen = draft[index]
	for i in 3:
		shoe.cards.pop_back()
	for card in draft:
		if card != chosen:
			shoe.cards.insert(0, card)
	draft.clear()
	player.add(chosen)
	_see(chosen)
	draft_closed.emit()
	card_dealt.emit(false, chosen, true)
	_after_player_card()

## The dealer's open card goes into the player's hand and the dealer gets a fresh one in its place.
func steal_dealer_card() -> void:
	if dealer.cards.is_empty():
		return
	var stolen = dealer.cards.pop_front()
	card_removed.emit(true, stolen)
	player.add(stolen)
	card_dealt.emit(false, stolen, true)
	var fresh = shoe.draw()
	dealer.cards.insert(0, fresh)
	_see(fresh)
	card_dealt.emit(true, fresh, true)
	_after_player_card()

## The two hands change places, the dealer's hidden card turns face up for its new owner.
func swap_hands() -> void:
	var mine := player.cards
	player.cards = dealer.cards
	dealer.cards = mine
	hole_known = true
	hole_shown = true
	_hole_counted = true
	hands_swapped.emit()
	_after_player_card()

## Hi-Lo: low cards count +1, tens and aces -1.
func _see(card) -> void:
	if card.rank >= 2 and card.rank <= 6:
		count += 1
	elif card.rank == 1 or card.rank >= 10:
		count -= 1
	count_changed.emit(count)

func _see_hole() -> void:
	if not _hole_counted:
		_hole_counted = true
		_see(dealer.cards[1])

# ---------------------------------------------------------------- internals

func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)

func _draw(to_dealer: bool, face_up: bool) -> void:
	var card = shoe.draw()
	(dealer if to_dealer else player).add(card)
	if face_up:
		_see(card)
	card_dealt.emit(to_dealer, card, face_up)

func _reveal_hole() -> void:
	if hole_shown:
		return
	hole_shown = true
	_see_hole()
	hole_revealed.emit(dealer.cards[1])

## Draws for the player. Returns true if the hand is still alive.
func _player_draw() -> bool:
	_draw(false, true)
	return _after_player_card()

func _after_player_card() -> bool:
	if player.is_bust():
		for fx in run.effects:
			if fx.prevent_bust(self):
				run.retire_spent()
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
	if outcome == Outcome.PUSH:
		for fx in run.effects:
			if fx.rematch(self):
				outcome = _outcome()
				break
	var real := outcome
	if bet_against:
		outcome = _against(real)
	_record(outcome)
	var payout := 0
	if bet_against:
		match real:
			Outcome.LOSE: payout = bet * 2
			Outcome.BUST: payout = bet * 3
			Outcome.PUSH: payout = bet
	else:
		match outcome:
			Outcome.BLACKJACK:
				payout = bet + int(bet * Rules.BLACKJACK_PAYOUT)
			Outcome.WIN:
				payout = bet * 2
			Outcome.PUSH:
				payout = bet
	for fx in run.effects:
		payout = fx.modify_payout(self, payout, outcome)
	bet_against = false
	run.add_chips(payout)
	var settled_bet := bet
	bet = 0
	_set_phase(Phase.RESOLVED)
	hand_resolved.emit(outcome, settled_bet, payout)
	for fx in run.effects:
		fx.hand_ended(self, outcome)
	run.hand_finished(bet, outcome == Outcome.LOSE or outcome == Outcome.BUST)

## What a bet on the dealer makes of the real result: the player's win is its loss and the other way round.
func _against(real: int) -> int:
	match real:
		Outcome.WIN, Outcome.BLACKJACK:
			return Outcome.LOSE
		Outcome.LOSE, Outcome.BUST:
			return Outcome.WIN
	return real

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
	if outcome == Outcome.PUSH:
		Events.stat_added.emit(Stat.PUSHES, 1)
		if player.total() == 21 and dealer.total() == 21 and not player.is_blackjack():
			Events.stat_added.emit(Stat.TWENTY_ONE_PUSHES, 1)
	if outcome == Outcome.WIN:
		# Only a dealer's bust lets a small hand win.
		if player.total() <= Rules.LOW_WIN_TOTAL:
			Events.stat_added.emit(Stat.LOW_WINS, 1)
	if won and dealer.total() > 21:
		Events.stat_added.emit(Stat.DEALER_BUSTS, 1)
	if outcome == Outcome.BLACKJACK:
		Events.stat_added.emit(Stat.BLACKJACKS, 1)
	if dealer.is_blackjack():
		Events.stat_added.emit(Stat.DEALER_BLACKJACKS, 1)
	if outcome == Outcome.BUST:
		Events.stat_added.emit(Stat.BUSTS, 1)

func dealer_event_for(outcome: int) -> StringName:
	match outcome:
		Outcome.BLACKJACK: return &"blackjack"
		Outcome.WIN: return &"player_wins"
		Outcome.PUSH: return &"push"
		Outcome.BUST: return &"player_bust"
	return &"player_loses"
