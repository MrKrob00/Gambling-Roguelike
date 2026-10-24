extends SceneTree
## Plays runs with ONE artifact held from the start and compares them with a run of nothing: debts closed per run and
## hands per run. A bot with basic strategy uses every button artifact when it is usable and the hand is in danger.
## Run: RUNS=600 godot --headless --path <copy> --script res://tools/artifact_balance.gd
## Reads as a rough guide only: the bot picks no offers and does not manage the pocket.

const RUN_LIMIT := 400

func _initialize() -> void:
	await process_frame
	var Table = load("res://games/blackjack/blackjack_table.gd")
	var RunState = load("res://core/run_state.gd")
	var catalog = root.get_node("Catalog")
	root.get_node("Profile").save_path = "user://artifact_balance_profile.json"
	root.get_node("Profile").reset()
	var runs := int(OS.get_environment("RUNS")) if OS.has_environment("RUNS") else 600
	var only := OS.get_environment("ONLY") if OS.has_environment("ONLY") else ""
	var rows: Array = []
	var base := _measure(Table, RunState, null, runs)
	print("%-18s debts %.2f  hands %.1f  first-life %.0f%%" % ["(nothing)", base[0], base[1], base[2]])
	for data in catalog.all():
		if only != "" and not (str(data.id) in only.split(",")):
			continue
		var m := _measure(Table, RunState, data, runs)
		rows.append([data.id, m[0], m[1], m[2], m[0] - base[0]])
	rows.sort_custom(func(a, b) -> bool: return a[4] > b[4])
	for r in rows:
		print("%-18s debts %.2f (%+.2f)  hands %.1f  first-life %.0f%%" % [r[0], r[1], r[4], r[2], r[3]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://artifact_balance_profile.json"))
	quit()

func _measure(Table, RunState, data, runs: int) -> Array:
	var debts := 0
	var hands_total := 0
	var first_life := 0
	for seed_value in runs:
		var run = RunState.new(&"blackjack", [data] if data != null else [])
		var table = Table.new(run, seed_value * 7 + 3)
		var hands := 0
		var cleared := false
		while run.alive and hands < RUN_LIMIT:
			if run.can_pay_off():
				run.pay_off()
				run.skip_offer()
			if run.offer_stage != RunState.Offer.NONE:
				run.skip_offer()
			if run.payments_paid > 0 and run.lives == RunState.new(&"blackjack", []).lives:
				cleared = true
			table.deal_all_in()
			_play(table)
			table.next_hand()
			hands += 1
		if cleared:
			first_life += 1
		debts += run.payments_paid
		hands_total += hands
	return [float(debts) / runs, float(hands_total) / runs, 100.0 * first_life / runs]

func _play(table) -> void:
	var guard := 0
	while table.is_player_turn() and guard < 30:
		guard += 1
		if not table.draft.is_empty():
			table.pick_draft(_best_draft(table))
			continue
		var total: int = table.player.total()
		var up: int = mini(table.dealer.cards[0].rank, 10)
		var soft: bool = table.player.is_soft()
		if total < 21:
			for fx in table.run.effects:
				if fx.data.button and total >= _window(fx.data.id)[0] and total <= _window(fx.data.id)[1] and fx.can_use(table):
					table.use_artifact(fx)
					break
		if not table.is_player_turn():
			break
		total = table.player.total()
		soft = table.player.is_soft()
		if total >= 18 or (total == 17 and not soft):
			table.stand()
		elif total >= 12 and up <= 6 and not soft:
			table.stand()
		else:
			table.hit()

## The draft card that keeps the hand nearest to 21 without busting.
func _best_draft(table) -> int:
	var best := 0
	var best_total := -1
	for i in table.draft.size():
		var total: int = table.player.total() + mini(table.draft[i].rank, 10)
		if total <= 21 and total > best_total:
			best_total = total
			best = i
	return best

## The hand totals at which the bot presses a button; the default is a stiff hand.
func _window(id: StringName) -> Array:
	match id:
		&"card_sleeve": return [14, 16]
		&"pickpocket": return [4, 11]
		_: return [13, 20]
