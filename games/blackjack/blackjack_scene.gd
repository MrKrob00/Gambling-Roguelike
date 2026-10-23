extends Control
## The blackjack screen. The table (pure logic) decides everything and emits signals; this script turns
## each signal into a queued animation step, so what the player sees always lags the rules by a beat
## and nothing is spoiled early (a payout does not show before the dealer's last card lands).

const Rules := preload("res://core/rules.gd")
const Dealer := preload("res://core/dealer.gd")
const RunState := preload("res://core/run_state.gd")
const Table := preload("res://games/blackjack/blackjack_table.gd")
const Hand := preload("res://games/blackjack/blackjack_hand.gd")
const ArtifactSlot := preload("res://ui/common/artifact_slot.gd")

const CHIP_ICONS := {
	10: preload("res://assets/art/casino/chip_icons/chip_10.png"),
	25: preload("res://assets/art/casino/chip_icons/chip_25.png"),
	100: preload("res://assets/art/casino/chip_icons/chip_100.png"),
	500: preload("res://assets/art/casino/chip_icons/chip_500.png"),
}
const STEP_PAUSE := 0.25
const AMBIENCE := "res://assets/audio/ambience/dark_cavern_ambient_001.ogg"

@onready var chips_label: Label = %ChipsLabel
@onready var payment_label: Label = %PaymentLabel
@onready var streak_label: Label = %StreakLabel
@onready var speech_label: Label = %SpeechLabel
@onready var dealer_hand: Control = %DealerHand
@onready var player_hand: Control = %PlayerHand
@onready var dealer_total: Label = %DealerTotal
@onready var player_total: Label = %PlayerTotal
@onready var message_label: Label = %MessageLabel
@onready var info_label: Label = %InfoLabel
@onready var bet_label: Label = %BetLabel
@onready var slots_box: VBoxContainer = %Slots
@onready var bet_row: Control = %BetRow
@onready var chip_buttons: HBoxContainer = %ChipButtons
@onready var clear_button: Button = %ClearButton
@onready var all_in_button: Button = %AllInButton
@onready var deal_button: Button = %DealButton
@onready var action_row: Control = %ActionRow
@onready var hit_button: Button = %HitButton
@onready var stand_button: Button = %StandButton
@onready var double_button: Button = %DoubleButton
@onready var next_button: Button = %NextButton

var run
var table
var _queue: Array[Callable] = []
var _pumping: bool = false
var _slots: Array = []
var _dealer_shown: Hand = Hand.new()
var _player_shown: Hand = Hand.new()
var _hole_view

func _ready() -> void:
	run = Game.run
	if run == null:
		run = RunState.new(&"blackjack", Profile.unlocked_for(&"blackjack").slice(0, Rules.ARTIFACT_SLOTS))
		Game.run = run
	table = Table.new(run)
	_connect_table()
	_connect_run()
	_build_chip_buttons()
	_build_slots()
	clear_button.pressed.connect(_on_clear)
	all_in_button.pressed.connect(_on_all_in)
	deal_button.pressed.connect(_on_deal)
	hit_button.pressed.connect(_on_hit)
	stand_button.pressed.connect(_on_stand)
	double_button.pressed.connect(_on_double)
	next_button.pressed.connect(_on_next)
	Audio.music(AMBIENCE)
	run.announce()
	_do_bet(0)
	_say(&"welcome")
	_update_totals()
	_refresh()

# ---------------------------------------------------------------- wiring

func _connect_table() -> void:
	table.bet_changed.connect(func(b: int) -> void: _enqueue(_do_bet.bind(b)))
	table.hand_cleared.connect(func() -> void: _enqueue(_do_clear))
	table.card_dealt.connect(func(d: bool, c, up: bool) -> void: _enqueue(_do_card.bind(d, c, up)))
	table.card_removed.connect(func(d: bool, c) -> void: _enqueue(_do_remove.bind(d, c)))
	table.hole_revealed.connect(func(c) -> void: _enqueue(_do_reveal.bind(c)))
	table.hole_peeked.connect(func(c) -> void: _enqueue(_do_peek.bind(c)))
	table.shoe_shuffled.connect(func() -> void: _enqueue(_do_shuffled))
	table.hand_resolved.connect(func(o: int, b: int, p: int) -> void: _enqueue(_do_resolved.bind(o, b, p)))
	table.trick_used.connect(func(fx) -> void: _enqueue(_do_trick.bind(fx)))

func _connect_run() -> void:
	run.chips_changed.connect(func(c: int) -> void: _enqueue(_do_chips.bind(c)))
	run.countdown_changed.connect(func(h: int, a: int) -> void: _enqueue(_do_countdown.bind(h, a)))
	run.payment_made.connect(func(a: int, i: int) -> void: _enqueue(_do_payment.bind(a, i)))
	run.payment_waived.connect(func(i: int) -> void: _enqueue(_do_waived.bind(i)))
	run.died.connect(func(r: StringName) -> void: _enqueue(_do_death.bind(r)))

func _build_chip_buttons() -> void:
	for amount in Rules.BET_STEPS:
		var b := TextureButton.new()
		b.texture_normal = CHIP_ICONS[amount]
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(32, 32)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		b.tooltip_text = str(amount)
		b.pressed.connect(_on_chip.bind(amount))
		chip_buttons.add_child(b)

func _build_slots() -> void:
	for fx in run.effects:
		var s := ArtifactSlot.new()
		slots_box.add_child(s)
		s.bind(fx)
		s.triggered.connect(_on_slot_triggered)
		s.inspected.connect(_on_slot_inspected)
		_slots.append(s)

# ---------------------------------------------------------------- queue

func _enqueue(step: Callable) -> void:
	_queue.append(step)
	if not _pumping:
		_pump()

func _pump() -> void:
	_pumping = true
	_lock(true)
	while not _queue.is_empty():
		var step: Callable = _queue.pop_front()
		await step.call()
	_pumping = false
	_refresh()

func _pause(seconds: float = STEP_PAUSE) -> void:
	await get_tree().create_timer(seconds).timeout

# ---------------------------------------------------------------- animation steps

func _do_bet(bet: int) -> void:
	bet_label.text = "%s %d" % [tr("TABLE_BET"), bet]
	if bet > 0:
		Audio.sfx(&"chips/Casino_chip_Put_down_%d" % randi_range(1, 8))

func _do_clear() -> void:
	dealer_hand.clear()
	player_hand.clear()
	_dealer_shown.clear()
	_player_shown.clear()
	_hole_view = null
	message_label.text = ""
	_update_totals()

func _do_card(to_dealer: bool, card, face_up: bool) -> void:
	var hand_view: Control = dealer_hand if to_dealer else player_hand
	var v = hand_view.add_card(card, face_up)
	Audio.sfx(&"trick/card_flick", randf_range(0.95, 1.1))
	if to_dealer:
		if face_up:
			_dealer_shown.add(card)
		else:
			_hole_view = v
	else:
		_player_shown.add(card)
	_update_totals()
	await _pause(hand_view.settle_time() + 0.1)

func _do_remove(to_dealer: bool, card) -> void:
	var hand: Hand = _dealer_shown if to_dealer else _player_shown
	hand.cards.erase(card)
	(dealer_hand if to_dealer else player_hand).remove_card(card)
	_update_totals()
	Audio.sfx(&"trick/whoosh")
	await _pause()

func _do_reveal(card) -> void:
	if _hole_view != null:
		_hole_view.set_peeked(false)
		Audio.sfx(&"game/card_reveal")
		if not _hole_view.face_up:
			_hole_view.card = card
			await _hole_view.flip_to(true)
		_hole_view = null
	_dealer_shown.add(card)
	_update_totals()
	await _pause()

func _do_peek(card) -> void:
	if _hole_view != null:
		_hole_view.setup(card, true)
		_hole_view.set_peeked(true)
	Audio.sfx(&"trick/sparkle")
	_say(&"peek")
	await _pause(0.4)

func _do_shuffled() -> void:
	Audio.sfx(&"tabletop/deck_shuffle_1")
	message_label.text = tr("TABLE_SHUFFLE")
	await _pause(0.5)

func _do_resolved(outcome: int, bet: int, payout: int) -> void:
	var net := payout - bet
	var total := _player_shown.total()
	match outcome:
		Table.Outcome.BLACKJACK:
			message_label.text = tr("OUTCOME_BLACKJACK") % net
			Audio.sfx(&"game/win_jackpot")
		Table.Outcome.WIN:
			message_label.text = tr("OUTCOME_WIN") % net
			Audio.sfx(&"game/win_small")
		Table.Outcome.PUSH:
			message_label.text = tr("OUTCOME_PUSH")
			Audio.sfx(&"ui/ui_cancel")
		Table.Outcome.BUST:
			message_label.text = tr("OUTCOME_BUST") % absi(net)
			Audio.sfx(&"trick/glass_shatter")
		_:
			message_label.text = tr("OUTCOME_LOSE") % absi(net)
			Audio.sfx(&"game/curse_hit")
	_say(table.dealer_event_for(outcome))
	streak_label.text = tr("TABLE_STREAK") % run.win_streak if run.win_streak >= 2 else ""
	await _pause(0.5)

func _do_trick(fx) -> void:
	if fx.data.id != &"marked_deck":
		Audio.sfx(&"trick/poof")
		_say(&"trick")
	info_label.text = fx.data.title()
	await _pause(0.3)

func _do_chips(chips: int) -> void:
	chips_label.text = "%s %d" % [tr("TABLE_CHIPS"), chips]

func _do_countdown(hands_left: int, amount: int) -> void:
	if hands_left <= 1:
		payment_label.text = tr("TABLE_PAYMENT_NOW") % amount
	else:
		payment_label.text = tr("TABLE_PAYMENT") % [amount, hands_left]

func _do_payment(amount: int, _index: int) -> void:
	message_label.text = tr("PAYMENT_PAID") % amount
	Audio.sfx(&"game/coin_ding")
	_say(&"payment")
	await _pause(0.9)

func _do_waived(_index: int) -> void:
	message_label.text = tr("PAYMENT_WAIVED")
	Audio.sfx(&"trick/sparkle")
	await _pause(1.2)

func _do_death(reason: StringName) -> void:
	_say(&"death_broke" if reason == run.DEATH_BROKE else &"death_debt")
	Audio.sfx(&"game/lose_sting")
	await _pause(2.0)
	Game.finish_run(reason)

# ---------------------------------------------------------------- input

func _on_chip(amount: int) -> void:
	if _pumping:
		return
	Audio.sfx(&"ui/ui_click")
	table.add_bet(amount)
	_refresh()

func _on_clear() -> void:
	if not _pumping:
		table.clear_bet()
		_refresh()

func _on_all_in() -> void:
	if not _pumping:
		table.all_in()
		_refresh()

func _on_deal() -> void:
	if _pumping or not table.can_deal():
		return
	Audio.sfx(&"tabletop/deck_deal_1")
	_say(&"deal")
	message_label.text = ""
	table.deal()

func _on_hit() -> void:
	if not _pumping:
		table.hit()

func _on_stand() -> void:
	if not _pumping:
		table.stand()

func _on_double() -> void:
	if not _pumping:
		table.double_down()

func _on_next() -> void:
	if not _pumping:
		table.next_hand()

func _on_slot_triggered(fx) -> void:
	if not _pumping:
		table.use_artifact(fx)
		_refresh()

func _on_slot_inspected(fx) -> void:
	info_label.text = "%s: %s" % [fx.data.title(), fx.data.description()]

# ---------------------------------------------------------------- view state

func _say(event: StringName) -> void:
	speech_label.text = Dealer.line(event)

func _update_totals() -> void:
	dealer_total.text = str(_dealer_shown.total()) if not _dealer_shown.cards.is_empty() else ""
	var p := _player_shown.total()
	player_total.text = "" if _player_shown.cards.is_empty() else (("%d" % p) + (" *" if _player_shown.is_soft() else ""))

func _lock(locked: bool) -> void:
	for b in [clear_button, all_in_button, deal_button, hit_button, stand_button, double_button, next_button]:
		b.disabled = locked
	for b in chip_buttons.get_children():
		b.disabled = locked
	for s in _slots:
		s.disabled = locked and s.fx.data.button

func _refresh() -> void:
	_lock(false)
	var phase: int = table.phase
	bet_row.visible = phase == Table.Phase.BETTING and run.alive
	action_row.visible = phase == Table.Phase.PLAYER_TURN
	next_button.visible = phase == Table.Phase.RESOLVED and run.alive
	deal_button.disabled = not table.can_deal()
	clear_button.disabled = table.bet == 0
	double_button.disabled = not table.can_double()
	for b in chip_buttons.get_children():
		b.disabled = not table.can_add_bet(int(b.tooltip_text))
	all_in_button.disabled = run.chips <= 0
	if phase == Table.Phase.BETTING:
		message_label.text = tr("TABLE_MIN_BET") % table.min_bet() if table.bet == 0 and _player_shown.cards.is_empty() else message_label.text
	for s in _slots:
		s.refresh(table)
