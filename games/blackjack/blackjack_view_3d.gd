extends Node3D
## The blackjack table in 3D, seen from the player's seat. The table (pure logic) decides everything and
## emits signals; each signal becomes a queued step here, so the screen lags the rules by a beat and
## nothing is spoiled early. Every control is an object on the table (chip piles, plaques, tokens),
## picked by a ray from the pointer or a tap.

const Rules := preload("res://core/rules.gd")
const DealerText := preload("res://core/dealer.gd")
const RunState := preload("res://core/run_state.gd")
const StepQueue := preload("res://core/step_queue.gd")
const Table := preload("res://games/blackjack/blackjack_table.gd")
const Hand := preload("res://games/blackjack/blackjack_hand.gd")
const Dealer3D := preload("res://games/blackjack/dealer_3d.gd")
const CardActor := preload("res://world/card_actor.gd")
const CardFaces := preload("res://world/card_faces.gd")
const CameraRig := preload("res://world/camera_rig.gd")
const ChipStack := preload("res://world/chip_stack_3d.gd")
const ChipRack := preload("res://world/chip_rack_3d.gd")
const Plaque := preload("res://world/plaque_3d.gd")
const Token := preload("res://world/artifact_token_3d.gd")
const OfferCard := preload("res://world/offer_card_3d.gd")
const Candles := preload("res://world/deadline_candles_3d.gd")
const PlayerHand := preload("res://world/player_hand_3d.gd")
const ArtifactHand := preload("res://world/artifact_hand_3d.gd")
const Enforcers := preload("res://world/enforcers_3d.gd")
const WarningHand := preload("res://world/warning_hand_3d.gd")
const InfoPanel := preload("res://ui/common/artifact_info_panel.gd")
const KindStyle := preload("res://core/kind_style.gd")
const ArtifactFlash := preload("res://ui/common/artifact_flash.gd")
const UnlockToast := preload("res://ui/common/unlock_toast.gd")
const FloatingText := preload("res://world/floating_text.gd")
const Vignette := preload("res://ui/common/vignette.gd")
const ROOM: PackedScene = preload("res://world/casino_room.tscn")
const BODY_FONT: Font = preload("res://ui/fonts/body_font.tres")

## Everything below is in metres, table-centred; the felt is at TOP.
const TOP := 1.03
const CARD_SPACING := 0.33
const SHOE := Vector3(1.55, TOP + 0.12, -1.05)
const DEALER_ROW := Vector3(0.0, TOP + 0.004, -0.84)
const PLAYER_ROW := Vector3(0.0, TOP + 0.004, -0.18)
const BET_SPOT := Vector3(0.0, TOP, 0.42)
const DEALER_SPOT := Vector3(0.0, 0.0, -2.4)
## Three zones: artifacts on a tray at the left, the chip piles on a plate at the right, and the action
## buttons in a row at the near edge, in the middle: the least distorted, thumb-friendly spot. The tray and
## the chip plate each stand on their own plate so they never blend into the felt.
## The chips stand on the padded rail along the near edge (built by tools/build_room.gd: 0.07 high, centred on z 1.27).
const RAIL_Z := 1.27
const RAIL_TOP := TOP + 0.04
const ACTION_Z := 0.96
## Early repayment sits at the right end of the action row, away from the deal button.
const ENFORCERS_POS := Vector3(0.0, 0.0, 0.3)
const HAND_POS := Vector3(0.0, TOP + 0.02, 0.62)
const PAY_OFF_X := 1.5
const ACTION_X: Array[float] = [-0.8, 0.0, 0.8]
const DISCARD_X := 1.5
const OFFER_Z := 0.2
const OFFER_SPACING := 0.9
## The deadline candles stand on the far rail, in front of the dealer.
const CANDLES_POS := Vector3(0.0, TOP + 0.045, -1.27)
const AMBIENCE := "res://assets/audio/ambience/dark_cavern_ambient_001.ogg"
const GOLD := Color(0.96, 0.63, 0.23)
const RED := Color(0.95, 0.3, 0.25)
const PALE := Color(0.85, 0.85, 0.95)

var run
var table
var _queue := StepQueue.new()
var _rig
var _dealer
var _faces
var _lamp: SpotLight3D
var _lamp_energy: float = 4.2
var _vignette
var _subtitle: Label
var _bet_stack
var _hud: Label
var _dealer_total: Label3D
var _player_total: Label3D
var _rack
var _tokens: Array = []
var _plaques: Dictionary = {}
var _dealer_cards: Array = []
var _player_cards: Array = []
var _dealer_shown: Hand = Hand.new()
var _player_shown: Hand = Hand.new()
var _hole_actor
var _hovered
var _pinned
var _candles
var _enforcers
var _hand_rig
var _player_hand
var _reaching: bool = false
var _held
var _warning_hand
var _debt_text: int = 0
var _rim: OmniLight3D
var _info
var _flash
var _toast
var _offer_cards: Array = []
var _pending_pick
var _discarding: bool = false
var _ui_state: String = ""
var _chips_text: int = 0
var _countdown: Array = [Rules.PAYMENT_EVERY, 0]

func _ready() -> void:
	run = Game.run
	if run == null:
		run = RunState.new(&"blackjack", Profile.unlocked_for(&"blackjack").slice(0, Rules.ARTIFACT_SLOTS))
		Game.run = run
	table = Table.new(run)
	_build_world()
	_build_controls()
	_build_overlay()
	_connect_table()
	_connect_run()
	_queue.drained.connect(_refresh)
	Events.artifact_unlocked.connect(func(a) -> void: _enqueue(_do_unlocked.bind(a)))
	Audio.music(AMBIENCE)
	run.announce()
	_say(&"welcome")
	_refresh()

# ---------------------------------------------------------------- building

func _build_world() -> void:
	var room := ROOM.instantiate()
	add_child(room)
	_lamp = room.get_node_or_null("TableLamp")
	if _lamp != null:
		_lamp_energy = _lamp.light_energy
	_rim = room.get_node_or_null("DealerRim")
	_candles = Candles.new()
	_candles.position = CANDLES_POS
	add_child(_candles)
	_enforcers = Enforcers.new()
	_enforcers.position = ENFORCERS_POS
	add_child(_enforcers)
	_warning_hand = WarningHand.new()
	_warning_hand.position = HAND_POS
	add_child(_warning_hand)
	_dealer = Dealer3D.new()
	_dealer.position = DEALER_SPOT
	add_child(_dealer)
	_rig = CameraRig.new()
	add_child(_rig)
	_hand_rig = ArtifactHand.new()
	_rig.camera.add_child(_hand_rig)
	_player_hand = PlayerHand.new()
	_rig.camera.add_child(_player_hand)
	_player_hand.set_lives.call_deferred(run.lives)
	_faces = CardFaces.new()
	add_child(_faces)
	_bet_stack = ChipStack.new()
	_bet_stack.position = BET_SPOT
	add_child(_bet_stack)
	_add_bet_ring()
	_add_shoe()
	_dealer_total = _make_label(DEALER_ROW + Vector3(-1.05, 0.2, 0.0), 64, 0.0036, PALE, true)
	_player_total = _make_label(PLAYER_ROW + Vector3(-1.05, 0.2, 0.0), 64, 0.0036, PALE, true)

func _make_label(pos: Vector3, size: int, pixel: float, color: Color, billboard: bool) -> Label3D:
	var l := Label3D.new()
	l.font = BODY_FONT
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 10
	l.modulate = color
	l.position = pos
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
	add_child(l)
	return l

func _add_bet_ring() -> void:
	var fill := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.27
	disc.bottom_radius = 0.27
	disc.height = 0.004
	disc.radial_segments = 24
	disc.rings = 1
	fill.mesh = disc
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.02, 0.05, 0.04)
	fill_mat.roughness = 1.0
	fill.material_override = fill_mat
	fill.position = BET_SPOT + Vector3(0.0, 0.002, 0.0)
	add_child(fill)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.265
	torus.outer_radius = 0.285
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.42, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.5, 0.15)
	mat.emission_energy_multiplier = 0.6
	ring.material_override = mat
	ring.scale = Vector3(1.0, 0.12, 1.0)
	ring.position = BET_SPOT + Vector3(0.0, 0.003, 0.0)
	add_child(ring)
	var caption := Label3D.new()
	caption.text = "TABLE_BET"
	caption.font = BODY_FONT
	caption.font_size = 40
	caption.pixel_size = 0.0028
	caption.outline_size = 6
	caption.modulate = Color(0.7, 0.5, 0.2)
	caption.rotation_degrees.x = -90.0
	caption.position = BET_SPOT + Vector3(-0.55, 0.006, 0.0)
	caption.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(caption)

func _add_shoe() -> void:
	var shoe := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.18, 0.36)
	shoe.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.06, 0.08)
	mat.roughness = 0.6
	shoe.material_override = mat
	shoe.position = Vector3(SHOE.x, TOP + 0.09, SHOE.z)
	add_child(shoe)

func _build_controls() -> void:
	_rack = ChipRack.new()
	_rack.position = Vector3(0.0, RAIL_TOP, RAIL_Z)
	_rack.scale = Vector3.ONE * 0.75
	add_child(_rack)
	_rack.show_amount(run.chips)
	## Slot 0 is left, 1 centre, 2 right. The phases share slots.
	var defs := {
		&"deal": ["TABLE_DEAL", 1],
		&"hit": ["TABLE_HIT", 0], &"stand": ["TABLE_STAND", 1], &"double": ["TABLE_DOUBLE", 2],
		&"next": ["TABLE_NEXT", 1],
		&"skip": ["OFFER_SKIP", 2], &"cancel": ["OFFER_CANCEL", 1],
		&"discard": ["DISCARD", -1], &"pay_off": ["TABLE_PAY_OFF", -2],
	}
	for id in defs:
		var plaque := Plaque.new()
		add_child(plaque)
		plaque.setup(defs[id][0])
		var slot: int = defs[id][1]
		plaque.position = Vector3(_slot_x(slot), TOP + 0.02, ACTION_Z - (0.45 if slot == -1 else 0.0))
		plaque.activated.connect(_on_plaque.bind(id))
		plaque.show_plaque(false)
		plaque.scale = Vector3.ONE * 0.001
		_plaques[id] = plaque
	_rebuild_tokens()

## One token per held artifact, rebuilt whenever the set changes.
func _rebuild_tokens() -> void:
	for t in _tokens:
		if is_instance_valid(t):
			t.queue_free()
	_tokens.clear()
	_pinned = null
	_hand_rig.clear()
	for i in run.effects.size():
		var token := Token.new()
		token.bind(run.effects[i])
		_hand_rig.add_token(token, i, run.effects.size())
		token.activated.connect(_on_token.bind(token))
		_tokens.append(token)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_vignette = Vignette.new()
	layer.add_child(_vignette)
	_subtitle = Label.new()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_subtitle.offset_top = 8.0
	_subtitle.offset_left = -200.0
	_subtitle.offset_right = 200.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", GOLD)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.05))
	_subtitle.add_theme_constant_override("outline_size", 4)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_subtitle)
	_hud = Label.new()
	_hud.position = Vector2(8.0, 6.0)
	_hud.add_theme_color_override("font_color", PALE)
	_hud.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.05))
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_toast = UnlockToast.new()
	layer.add_child(_toast)
	_flash = ArtifactFlash.new()
	layer.add_child(_flash)
	_info = InfoPanel.new()
	layer.add_child(_info)
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_info.offset_left = -190.0
	_info.offset_top = 34.0
	_info.offset_right = -8.0

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
	run.debt_changed.connect(func(d: int) -> void: _enqueue(_do_debt.bind(d)))
	run.loan_closed.connect(func(p: int, n: int, d: int) -> void: _enqueue(_do_loan_closed.bind(p, n, d)))
	run.life_lost.connect(func(n: int, r: StringName) -> void: _enqueue(_do_life_lost.bind(n, r)))
	run.died.connect(func(r: StringName) -> void: _enqueue(_do_death.bind(r)))
	run.artifacts_changed.connect(func() -> void: _enqueue(_do_artifacts))
	run.artifact_triggered.connect(func(fx) -> void: _enqueue(_do_triggered.bind(fx)))

func _enqueue(step: Callable) -> void:
	_set_interactive(false)
	_queue.push(step)

# ---------------------------------------------------------------- steps

func _do_bet(bet: int) -> void:
	_bet_stack.set_amount(bet)
	if bet > 0:
		Audio.sfx(&"chips/Casino_chip_Put_down_%d" % randi_range(1, 8))

func _do_clear() -> void:
	for actor in _dealer_cards + _player_cards:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(actor, "position", SHOE, 0.35).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(actor, "scale", Vector3.ONE * 0.6, 0.35)
		tween.chain().tween_callback(actor.queue_free)
	_dealer_cards.clear()
	_player_cards.clear()
	_dealer_shown.clear()
	_player_shown.clear()
	_hole_actor = null
	_update_totals()
	Audio.sfx(&"tabletop/paper_flip_1")
	await _pause(0.3)

func _do_card(to_dealer: bool, card, face_up: bool) -> void:
	var actor := CardActor.new()
	add_child(actor)
	actor.setup(card, _faces.texture_for(card), false)
	actor.position = SHOE
	actor.rotation.y = randf_range(-0.12, 0.12)
	var list: Array = _dealer_cards if to_dealer else _player_cards
	var row: Vector3 = DEALER_ROW if to_dealer else PLAYER_ROW
	list.append(actor)
	_relayout(list, row, actor)
	var target := _row_target(row, list.size() - 1, list.size())
	if to_dealer and list.size() == 1:
		_dealer.react(&"deal")
	Audio.sfx(&"trick/card_flick", randf_range(0.95, 1.12))
	if face_up:
		actor.flip_to(true, false)
	else:
		_hole_actor = actor
	await actor.fly_to(target)
	if to_dealer:
		if face_up:
			_dealer_shown.add(card)
		else:
			_hole_actor = actor
	else:
		_player_shown.add(card)
	_update_totals()
	await _pause(0.08)

func _do_remove(to_dealer: bool, card) -> void:
	var list: Array = _dealer_cards if to_dealer else _player_cards
	var hand: Hand = _dealer_shown if to_dealer else _player_shown
	hand.cards.erase(card)
	for actor in list:
		if actor.card == card:
			list.erase(actor)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(actor, "position:y", actor.position.y + 0.5, 0.35)
			tween.tween_property(actor, "scale", Vector3.ONE * 0.01, 0.35)
			tween.chain().tween_callback(actor.queue_free)
			break
	_relayout(list, DEALER_ROW if to_dealer else PLAYER_ROW)
	_update_totals()
	Audio.sfx(&"trick/whoosh")
	await _pause(0.35)

func _do_reveal(card) -> void:
	if _hole_actor != null:
		Audio.sfx(&"game/card_reveal")
		await _hole_actor.flip_to(true)
		_hole_actor = null
	_dealer_shown.add(card)
	_update_totals()
	await _pause(0.25)

## The hidden card on the table turns into the real one: it is shown face up, the total still waits for the reveal.
func _do_peek(_card) -> void:
	Audio.sfx(&"trick/sparkle")
	_dealer.react(&"peek")
	_say(&"peek")
	if _hole_actor != null:
		await _hole_actor.flip_to(true)
	await _pause(0.3)

func _do_shuffled() -> void:
	Audio.sfx(&"tabletop/deck_shuffle_1")
	_subtitle.text = tr("TABLE_SHUFFLE")
	await _pause(0.6)

func _do_resolved(outcome: int, bet: int, payout: int) -> void:
	var net := payout - bet
	var spot := BET_SPOT + Vector3(0.0, 0.35, 0.0)
	var slide_to := BET_SPOT
	match outcome:
		Table.Outcome.BLACKJACK, Table.Outcome.WIN:
			_bet_stack.set_amount(maxi(payout, 0))
			_add_text_node(spot, "+%d" % net, GOLD)
			Audio.sfx(&"game/win_jackpot" if outcome == Table.Outcome.BLACKJACK else &"game/win_small")
			_vignette.flash_color(GOLD, 0.7, 0.6)
			_rig.punch_fov(-5.0 if outcome == Table.Outcome.BLACKJACK else -2.5)
			_pulse_lamp(1.5, 0.6)
			slide_to = BET_SPOT + Vector3(0.0, 0.0, 1.0)
			_dealer.react(&"blackjack" if outcome == Table.Outcome.BLACKJACK else &"player_wins")
		Table.Outcome.PUSH:
			_add_text_node(spot, tr("OUTCOME_PUSH"), PALE)
			Audio.sfx(&"ui/ui_cancel")
			slide_to = BET_SPOT + Vector3(0.0, 0.0, 1.0)
		_:
			_add_text_node(spot, "-%d" % absi(net), RED)
			Audio.sfx(&"trick/glass_shatter" if outcome == Table.Outcome.BUST else &"game/curse_hit")
			_vignette.flash_color(RED, 1.0, 0.8)
			_rig.shake(0.07, 0.45)
			_pulse_lamp(0.55, 0.7)
			slide_to = Vector3(BET_SPOT.x, TOP, -1.4)
			_dealer.react(&"player_bust" if outcome == Table.Outcome.BUST else &"player_loses")
	_say(table.dealer_event_for(outcome))
	await _pause(0.7)
	var tween := create_tween()
	tween.tween_property(_bet_stack, "position", slide_to, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	_bet_stack.set_amount(0, false)
	_bet_stack.position = BET_SPOT

func _do_artifacts() -> void:
	_rebuild_tokens()
	_info.clear()
	await _pause(0.3)

## A new artifact opened: the pop-up slides in at the corner while play carries on.
func _do_unlocked(data) -> void:
	_toast.show_unlock(data)
	await _pause(0.15)

## The artifact did something: its icon pops into the middle of the screen, shaking, and leaves.
func _do_triggered(fx) -> void:
	Audio.sfx(&"game/item_use")
	_rig.shake(0.03, 0.25)
	await _flash.play(fx.data)

func _do_trick(fx) -> void:
	if fx.data.id != &"marked_deck":
		Audio.sfx(&"trick/poof")
		_say(&"trick")
		_dealer.react(&"trick")
	await _pause(0.1)

func _do_chips(chips: int) -> void:
	_chips_text = chips
	_rack.show_amount(chips)
	_update_ledger()

func _do_countdown(hands_left: int, amount: int) -> void:
	_countdown = [hands_left, amount]
	if hands_left > _candles.lit:
		_candles.relight(hands_left)
		_candles.set_remaining(hands_left, amount, false)
	else:
		_candles.set_remaining(hands_left, amount)
	_apply_urgency(_candles.urgency)
	_enforcers.set_urgency(_candles.urgency)
	if hands_left == 1:
		Audio.sfx(&"game/heartbeat")
		_say(&"deadline")
		_subtitle.text = tr("DEBT_WARNING") % amount
		await _warning_hand.knock(3, _on_finger_tap)
	_update_ledger()

func _on_finger_tap(index: int) -> void:
	Audio.sfx(&"game/knock", 1.0 + index * 0.06, -6.0)
	_rig.shake(0.02, 0.2)

func _do_debt(debt: int) -> void:
	_debt_text = debt
	_update_ledger()

## Spells out where the new debt comes from: the house lends a bigger loan and writes it down at once.
func _do_loan_closed(paid: int, new_loan: int, new_debt: int) -> void:
	_subtitle.text = tr("DEBT_CLOSED") % [paid, new_loan, new_debt]
	_add_text_node(BET_SPOT + Vector3(0.0, 0.5, 0.0), "+%d" % new_loan, GOLD)
	Audio.sfx(&"trick/sparkle")
	_vignette.flash_color(Color(0.9, 0.8, 0.4), 0.5, 0.8)
	await _pause(2.0)

## The closer the deadline, the redder the dealer's rim light and the darker the screen edges.
func _apply_urgency(urgency: float) -> void:
	if _rim != null:
		_rim.light_color = Color(1.0, 0.08, 0.14).lerp(Color(1.0, 0.0, 0.03), urgency)
		var tween := create_tween()
		tween.tween_property(_rim, "light_energy", 2.4 + 3.2 * urgency, 0.5)
	_vignette.set_darkness(0.55 + 0.25 * urgency)

func _do_payment(amount: int, _index: int) -> void:
	Audio.sfx(&"game/knock")
	_say(&"knock")
	_dealer.react(&"payment")
	_pulse_lamp(0.1, 0.9)
	_vignette.flash_color(RED, 0.8, 0.9)
	_rig.shake(0.05, 0.5)
	await _pause(1.1)
	_add_text_node(BET_SPOT + Vector3(0.0, 0.35, 0.0), "-%d" % amount, RED)
	_subtitle.text = tr("PAYMENT_PAID") % amount
	Audio.sfx(&"game/coin_ding")
	await _pause(0.9)

func _do_waived(_index: int) -> void:
	_subtitle.text = tr("PAYMENT_WAIVED")
	Audio.sfx(&"trick/sparkle")
	await _pause(1.3)

## A death costs a finger of the right hand; the house lends the loan again and the run goes on.
func _do_life_lost(left: int, reason: StringName) -> void:
	_say(&"death_broke" if reason == run.DEATH_BROKE else &"death_debt")
	_dealer.react(&"death")
	Audio.sfx(&"game/lose_sting")
	_vignette.flash_color(RED, 1.0, 1.6)
	_rig.shake(0.08, 0.6)
	_subtitle.text = tr("LIFE_LOST") % left
	await _player_hand.present_cut(left)
	Audio.sfx(&"game/knock")
	await _pause(0.4)

func _do_death(reason: StringName) -> void:
	await _player_hand.present_cut(0)
	_say(&"death_broke" if reason == run.DEATH_BROKE else &"death_debt")
	_dealer.react(&"death")
	Audio.sfx(&"game/lose_sting")
	_vignette.flash_color(RED, 1.0, 1.8)
	_rig.shake(0.1, 0.8)
	_pulse_lamp(0.15, 2.0)
	await _pause(2.4)
	Game.finish_run(reason)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if _reaching:
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_pointer_down(event)
		else:
			_on_pointer_up(event)

## A press only shows that the object is held. It acts on release, and only if the pointer is still on it: slide
## the finger off and let go to cancel.
func _on_pointer_down(event: InputEventMouseButton) -> void:
	var hit = _pick(event.position)
	_set_hover(hit)
	if is_instance_valid(_held):
		_held.set_held(false)
	_held = hit
	if hit == null:
		_pinned = null
		_info.clear()
		_sync_focus()
		return
	hit.set_held(true)

func _on_pointer_up(event: InputEventMouseButton) -> void:
	var target = _held
	_held = null
	if not is_instance_valid(target):
		return
	target.set_held(false)
	if _pick(event.position) != target:
		return
	## A touch screen has no hover, so the first tap on an artifact only shows what it is; the second tap
	## acts. With a mouse the hover already showed it, so one click acts.
	var from_touch: bool = event.device == InputEvent.DEVICE_ID_EMULATION
	if from_touch and _is_artifact(target) and _pinned != target:
		_pinned = target
		_show_info(target)
		Audio.sfx(&"ui/ui_hover")
		_sync_focus()
		return
	_pinned = null
	_sync_focus()
	_act_on(target)

## The right hand does every press: it reaches the object and taps it. A pickable that cannot act right now
## answers with a shake, so a tap is never silent.
func _act_on(target) -> void:
	_reaching = true
	await _player_hand.reach(_rig.camera, target.global_position, _activate_if_alive.bind(target))
	_reaching = false

func _activate_if_alive(target) -> void:
	if is_instance_valid(target):
		target.activate()

func _is_artifact(obj) -> bool:
	return obj.get("fx") != null or obj.get("data") != null

func _show_info(obj) -> void:
	if obj.get("fx") != null:
		_info.show_artifact(obj.fx.data, obj.fx)
	elif obj.get("data") != null:
		_info.show_artifact(obj.data, null, tr("INFO_TAKE") if obj in _offer_cards else "")

func _pick(screen_pos: Vector2):
	var camera: Camera3D = _rig.camera
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 30.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") if not hit.is_empty() else null

func _set_hover(target) -> void:
	if target == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.set_hovered(false)
	_hovered = target
	if is_instance_valid(_hovered):
		_hovered.set_hovered(true)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		if _is_artifact(_hovered):
			_show_info(_hovered)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _pinned == null and not _is_artifact_valid(_hovered):
		_info.clear()
	_sync_focus()

func _sync_focus() -> void:
	var target = _pinned if is_instance_valid(_pinned) else _hovered
	_hand_rig.focus(target if is_instance_valid(target) and target in _tokens else null)

func _is_artifact_valid(obj) -> bool:
	return is_instance_valid(obj) and _is_artifact(obj)

func _on_token(token) -> void:
	if _discarding:
		_subtitle.text = tr("DISCARDED") % token.fx.data.title()
		_discarding = false
		run.discard(token.fx)
	elif _pending_pick != null:
		run.choose_offer(_pending_pick, token.fx)
		_pending_pick = null
	elif token.fx.data.button:
		table.use_artifact(token.fx)
	_refresh()

func _on_offer_card(card) -> void:
	if run.slots_full():
		_pending_pick = card.data
	else:
		run.choose_offer(card.data)
	_refresh()

func _slot_x(slot: int) -> float:
	if slot >= 0:
		return ACTION_X[slot]
	return DISCARD_X if slot == -1 else PAY_OFF_X

func _on_plaque(id: StringName) -> void:
	match id:
		&"deal":
			_say(&"deal")
			Audio.sfx(&"tabletop/deck_deal_1")
			table.deal_all_in()
		&"hit": table.hit()
		&"stand": table.stand()
		&"double": table.double_down()
		&"next": table.next_hand()
		&"pay_off": table.pay_off()
		&"skip": run.skip_offer()
		&"cancel":
			_discarding = false
			_pending_pick = null
		&"discard": _discarding = true
	_refresh()

# ---------------------------------------------------------------- view state

func _row_target(row: Vector3, index: int, count: int) -> Vector3:
	return row + Vector3((index - (count - 1) / 2.0) * CARD_SPACING, index * 0.003, 0.0)

func _relayout(list: Array, row: Vector3, skip = null) -> void:
	for i in list.size():
		var actor = list[i]
		if actor == skip:
			continue
		var tween := create_tween()
		tween.tween_property(actor, "position", _row_target(row, i, list.size()), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _say(event: StringName) -> void:
	_subtitle.text = DealerText.line(event)

func _add_text_node(pos: Vector3, message: String, color: Color) -> void:
	var t := FloatingText.new()
	add_child(t)
	t.play(pos, message, color)

func _pulse_lamp(factor: float, duration: float) -> void:
	if _lamp == null:
		return
	var tween := create_tween()
	tween.tween_property(_lamp, "light_energy", _lamp_energy * factor, duration * 0.25)
	tween.tween_property(_lamp, "light_energy", _lamp_energy, duration * 0.75)

func _update_totals() -> void:
	_dealer_total.text = str(_dealer_shown.total()) if not _dealer_shown.cards.is_empty() else ""
	_player_total.text = "" if _player_shown.cards.is_empty() else str(_player_shown.total()) + (" *" if _player_shown.is_soft() else "")

func _update_ledger() -> void:
	var lines := ["%s %d" % [tr("TABLE_CHIPS"), _chips_text]]
	lines.append(tr("TABLE_DEBT") % _debt_text)
	if run.win_streak >= 2:
		lines.append(tr("TABLE_STREAK") % run.win_streak)
	_hud.text = "\n".join(lines)

## While steps play, nothing on the table may be pressed.
func _set_interactive(on: bool) -> void:
	if on:
		return
	for id in _plaques:
		_plaques[id].set_enabled(false)
	for t in _tokens:
		if is_instance_valid(t):
			t.set_enabled(false)
	for c in _offer_cards:
		if is_instance_valid(c):
			c.set_enabled(false)

func _refresh() -> void:
	if _queue.busy:
		return
	var phase: int = table.phase
	var alive: bool = run.alive
	var betting := phase == Table.Phase.BETTING and alive
	var playing := phase == Table.Phase.PLAYER_TURN
	var stage: int = run.offer_stage if betting else RunState.Offer.NONE
	var picking := stage == RunState.Offer.CHOOSING
	var replacing := picking and _pending_pick != null
	var normal := betting and not picking and not _discarding
	var show: Array = []
	if normal:
		show = [&"deal", &"pay_off"]
		if not run.effects.is_empty():
			show.append(&"discard")
	elif _discarding or replacing:
		show = [&"cancel"]
	elif picking:
		show = [&"skip"]
	elif playing:
		show = [&"hit", &"stand"]
		if table.can_double():
			show.append(&"double")
	elif phase == Table.Phase.RESOLVED and alive:
		show = [&"next"]
	for id in _plaques:
		_plaques[id].show_plaque(id in show)
	_plaques[&"deal"].set_enabled(table.can_deal_all_in())
	_plaques[&"hit"].set_enabled(playing)
	_plaques[&"stand"].set_enabled(playing)
	_plaques[&"double"].set_enabled(table.can_double())
	_plaques[&"next"].set_enabled(true)
	_plaques[&"discard"].set_enabled(true)
	_plaques[&"cancel"].set_enabled(true)
	_plaques[&"skip"].set_enabled(true)
	_plaques[&"pay_off"].set_caption(tr("TABLE_PAY_OFF") % run.debt)
	_plaques[&"pay_off"].set_enabled(table.can_pay_off())
	var selecting := _discarding or replacing
	for t in _tokens:
		if is_instance_valid(t):
			t.refresh(table)
			if selecting:
				t.set_enabled(true)
			t.show_ring(selecting, RED if selecting else KindStyle.NEUTRAL)
	_sync_offer_cards(picking)
	for c in _offer_cards:
		c.set_enabled(not replacing)
	_update_prompt(stage, replacing)
	_update_ledger()

## Cards on offer stand in the middle of the table while the player is choosing.
func _sync_offer_cards(show: bool) -> void:
	var want: Array = run.offer if show else []
	var have: Array = _offer_cards.map(func(c): return c.data)
	if have == want:
		return
	for c in _offer_cards:
		c.queue_free()
	_offer_cards.clear()
	for i in want.size():
		var card := OfferCard.new()
		add_child(card)
		card.bind(want[i])
		card.position = Vector3((i - (want.size() - 1) / 2.0) * OFFER_SPACING, TOP + 0.014, OFFER_Z)
		card.appear(i * 0.1)
		card.activated.connect(_on_offer_card.bind(card))
		_offer_cards.append(card)

func _update_prompt(stage: int, replacing: bool) -> void:
	var key := "%d|%s|%s" % [stage, replacing, _discarding]
	if key == _ui_state:
		return
	_ui_state = key
	if replacing:
		_subtitle.text = tr("OFFER_REPLACE")
	elif _discarding:
		_subtitle.text = tr("DISCARD_PICK")
	elif stage == RunState.Offer.CHOOSING:
		_subtitle.text = tr("OFFER_FREE")
