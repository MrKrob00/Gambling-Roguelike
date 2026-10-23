extends SceneTree
## Plays many runs with a basic-strategy bot and prints how the economy in core/rules.gd behaves: how often the first
## debt is closed on the first life, debts closed per run, hands per run, deaths. Run: godot --headless --path . --script res://tools/balance.gd
## RUNS=2000 sets the sample size.

const RUN_LIMIT := 600

func _initialize() -> void:
	await process_frame
	var Table = load("res://games/blackjack/blackjack_table.gd")
	var RunState = load("res://core/run_state.gd")
	root.get_node("Profile").save_path = "user://balance_profile.json"
	root.get_node("Profile").reset()
	var runs := int(OS.get_environment("RUNS")) if OS.has_environment("RUNS") else 2000
	var first_life_clears := 0
	var total_debts := 0
	var total_hands := 0
	var debts_hist := {}
	var hands_list: Array = []
	for seed_value in runs:
		var run = RunState.new(&"blackjack", [])
		var table = Table.new(run, seed_value)
		var hands := 0
		var closed_on_first_life := false
		while run.alive and hands < RUN_LIMIT:
			if run.can_pay_off():
				run.pay_off()
				run.skip_offer()
			if run.payments_paid > 0 and run.lives == 5:
				closed_on_first_life = true
			table.deal_all_in()
			_play(table)
			table.next_hand()
			hands += 1
		if closed_on_first_life:
			first_life_clears += 1
		total_debts += run.payments_paid
		total_hands += hands
		hands_list.append(hands)
		debts_hist[run.payments_paid] = debts_hist.get(run.payments_paid, 0) + 1
	hands_list.sort()
	print("runs ", runs)
	print("first debt closed without losing a life: %.1f%%" % (100.0 * first_life_clears / runs))
	print("debts closed per run: %.2f" % (float(total_debts) / runs))
	print("hands per run: mean %.1f median %d p90 %d" % [float(total_hands) / runs, hands_list[runs / 2], hands_list[int(runs * 0.9)]])
	var keys := debts_hist.keys()
	keys.sort()
	var line := "debts closed histogram:"
	for k in keys:
		line += " %d:%.0f%%" % [k, 100.0 * debts_hist[k] / runs]
	print(line)
	quit()

## Basic strategy: stand on 17+, on 12-16 against a weak dealer card, otherwise hit.
func _play(table) -> void:
	var guard := 0
	while table.is_player_turn() and guard < 30:
		guard += 1
		var total: int = table.player.total()
		var up: int = mini(table.dealer.cards[0].rank, 10)
		var soft: bool = table.player.is_soft()
		if total >= 18 or (total == 17 and not soft):
			table.stand()
		elif total >= 12 and up <= 6 and not soft:
			table.stand()
		else:
			table.hit()
