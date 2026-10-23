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
const ChipPile := preload("res://world/chip_pile_3d.gd")
const Plaque := preload("res://world/plaque_3d.gd")
const Token := preload("res://world/artifact_token_3d.gd")
const FloatingText := preload("res://world/floating_text.gd")
const Vignette := preload("res://ui/common/vignette.gd")
const ROOM: PackedScene = preload("res://world/casino_room.tscn")
const BODY_FONT: Font = preload("res://ui/fonts/body_font.tres")

## Everything below is in metres, table-centred; the felt is at TOP.
const TOP := 1.03
const CARD_SPACING := 0.33
const SHOE := Vector3(1.55, TOP + 0.12, -1.05)
const DEALER_ROW := Vector3(0.0, TOP + 0.004, -0.74)
const PLAYER_ROW := Vector3(0.0, TOP + 0.004, -0.0)
const BET_SPOT := Vector3(0.0, TOP, 0.7)
const DEALER_SPOT := Vector3(0.0, 0.0, -2.4)
## Three zones: artifacts on a tray at the left, the bet and the chip piles in the middle, actions in a
## column on the right. The tray and column each stand on their own plate so they never blend into the felt.
const TRAY_X := -1.5
const TRAY_Z: Array[float] = [-0.45, 0.15, 0.75]
const ACTION_X := 1.5
const ACTION_Z: Array[float] = [-0.45, 0.15, 0.75]
const PILE_Z := 1.06
const PILE_X: Array[float] = [-0.5, -0.17, 0.17, 0.5]
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
var _piles: Array = []
var _tokens: Array = []
var _plaques: Dictionary = {}
var _dealer_cards: Array = []
var _player_cards: Array = []
var _dealer_shown: Hand = Hand.new()
var _player_shown: Hand = Hand.new()
var _hole_actor
var _hovered
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
	_dealer = Dealer3D.new()
	_dealer.position = DEALER_SPOT
	add_child(_dealer)
	_rig = CameraRig.new()
	add_child(_rig)
	_faces = CardFaces.new()
	add_child(_faces)
	_bet_stack = ChipStack.new()
	_bet_stack.position = BET_SPOT
	add_child(_bet_stack)
	_add_bet_ring()
	_add_plates()
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
	disc.radial_segments = 32
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
	caption.position = BET_SPOT + Vector3(-0.52, 0.006, 0.0)
	caption.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(caption)

## Two dark plates with a gold edge: the artifact tray (left) and the action column (right).
func _add_plates() -> void:
	for spec in [[TRAY_X, 0.62, 1.78], [ACTION_X, 0.7, 1.78]]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(spec[1] + 0.05, 0.008, spec[2] + 0.05)
		edge.mesh = edge_mesh
		var edge_mat := StandardMaterial3D.new()
		edge_mat.albedo_color = Color(0.4, 0.28, 0.1)
		edge_mat.emission_enabled = true
		edge_mat.emission = Color(0.5, 0.34, 0.1)
		edge_mat.emission_energy_multiplier = 0.35
		edge.material_override = edge_mat
		edge.position = Vector3(spec[0], TOP + 0.004, 0.15)
		add_child(edge)
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(spec[1], 0.012, spec[2])
		plate.mesh = plate_mesh
		var plate_mat := StandardMaterial3D.new()
		plate_mat.albedo_color = Color(0.05, 0.04, 0.08)
		plate_mat.roughness = 0.6
		plate.material_override = plate_mat
		plate.position = Vector3(spec[0], TOP + 0.008, 0.15)
		add_child(plate)

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
	for i in Rules.BET_STEPS.size():
		var pile := ChipPile.new()
		add_child(pile)
		pile.setup(Rules.BET_STEPS[i])
		pile.position = Vector3(PILE_X[i], TOP, PILE_Z)
		pile.activated.connect(_on_pile.bind(pile))
		_piles.append(pile)
	## Slot 0 is the far end of the right column, slot 2 the near end. Phases share slots.
	var defs := {
		&"clear": ["TABLE_CLEAR", 0], &"deal": ["TABLE_DEAL", 1], &"all_in": ["TABLE_ALL_IN", 2],
		&"hit": ["TABLE_HIT", 0], &"stand": ["TABLE_STAND", 1], &"double": ["TABLE_DOUBLE", 2],
		&"next": ["TABLE_NEXT", 1],
	}
	for id in defs:
		var plaque := Plaque.new()
		add_child(plaque)
		plaque.setup(defs[id][0])
		plaque.position = Vector3(ACTION_X, TOP + 0.045, ACTION_Z[defs[id][1]])
		plaque.activated.connect(_on_plaque.bind(id))
		plaque.show_plaque(false)
		plaque.scale = Vector3.ONE * 0.001
		_plaques[id] = plaque
	for i in run.effects.size():
		var token := Token.new()
		add_child(token)
		token.bind(run.effects[i])
		token.position = Vector3(TRAY_X, TOP + 0.014, TRAY_Z[i])
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

func _do_peek(card) -> void:
	var ghost := CardActor.new()
	add_child(ghost)
	ghost.setup(card, _faces.texture_for(card), true)
	ghost.position = DEALER_ROW + Vector3(0.0, 0.5, 0.35)
	ghost.rotation.x = 1.0
	ghost.scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(ghost, "scale", Vector3.ONE * 1.1, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.2)
	tween.tween_property(ghost, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(ghost.queue_free)
	Audio.sfx(&"trick/sparkle")
	_dealer.react(&"peek")
	_say(&"peek")
	await _pause(0.5)

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

func _do_trick(fx) -> void:
	if fx.data.id != &"marked_deck":
		Audio.sfx(&"trick/poof")
		_say(&"trick")
		_dealer.react(&"trick")
	_subtitle.text = fx.data.title()
	await _pause(0.3)

func _do_chips(chips: int) -> void:
	_chips_text = chips
	_update_ledger()

func _do_countdown(hands_left: int, amount: int) -> void:
	_countdown = [hands_left, amount]
	_update_ledger()

func _do_payment(amount: int, _index: int) -> void:
	_add_text_node(BET_SPOT + Vector3(0.0, 0.35, 0.0), "-%d" % amount, RED)
	_subtitle.text = tr("PAYMENT_PAID") % amount
	Audio.sfx(&"game/coin_ding")
	_say(&"payment")
	_dealer.react(&"payment")
	_rig.shake(0.04, 0.3)
	await _pause(1.0)

func _do_waived(_index: int) -> void:
	_subtitle.text = tr("PAYMENT_WAIVED")
	Audio.sfx(&"trick/sparkle")
	await _pause(1.3)

func _do_death(reason: StringName) -> void:
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
	if event is InputEventMouseMotion:
		_set_hover(_pick(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit = _pick(event.position)
		_set_hover(hit)
		if hit != null and not _queue.busy:
			hit.activate()

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
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_pile(pile) -> void:
	table.add_bet(pile.denomination)
	_refresh()

func _on_token(token) -> void:
	if token.fx.data.button:
		table.use_artifact(token.fx)
	else:
		_subtitle.text = "%s: %s" % [token.fx.data.title(), token.fx.data.description()]
	_refresh()

func _on_plaque(id: StringName) -> void:
	Audio.sfx(&"ui/ui_click")
	match id:
		&"clear": table.clear_bet()
		&"all_in": table.all_in()
		&"deal":
			_say(&"deal")
			Audio.sfx(&"tabletop/deck_deal_1")
			table.deal()
		&"hit": table.hit()
		&"stand": table.stand()
		&"double": table.double_down()
		&"next": table.next_hand()
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
	if _countdown[0] <= 1:
		lines.append(tr("TABLE_PAYMENT_NOW") % _countdown[1])
	else:
		lines.append(tr("TABLE_PAYMENT") % [_countdown[1], _countdown[0]])
	if run.win_streak >= 2:
		lines.append(tr("TABLE_STREAK") % run.win_streak)
	_hud.text = "\n".join(lines)

## While steps play, nothing on the table may be pressed.
func _set_interactive(on: bool) -> void:
	if on:
		return
	for p in _piles:
		p.set_enabled(false)
	for id in _plaques:
		_plaques[id].set_enabled(false)
	for t in _tokens:
		t.set_enabled(false)

func _refresh() -> void:
	if _queue.busy:
		return
	var phase: int = table.phase
	var alive: bool = run.alive
	var betting := phase == Table.Phase.BETTING and alive
	var playing := phase == Table.Phase.PLAYER_TURN
	_plaques[&"deal"].show_plaque(betting)
	_plaques[&"clear"].show_plaque(betting)
	_plaques[&"all_in"].show_plaque(betting)
	_plaques[&"hit"].show_plaque(playing)
	_plaques[&"stand"].show_plaque(playing)
	_plaques[&"double"].show_plaque(playing)
	_plaques[&"next"].show_plaque(phase == Table.Phase.RESOLVED and alive)
	_plaques[&"deal"].set_enabled(table.can_deal())
	_plaques[&"clear"].set_enabled(table.bet > 0)
	_plaques[&"all_in"].set_enabled(run.chips > 0)
	_plaques[&"hit"].set_enabled(playing)
	_plaques[&"stand"].set_enabled(playing)
	_plaques[&"double"].set_enabled(table.can_double())
	_plaques[&"next"].set_enabled(true)
	for p in _piles:
		p.set_enabled(betting and table.can_add_bet(p.denomination))
	for t in _tokens:
		t.refresh(table)
	_update_ledger()
