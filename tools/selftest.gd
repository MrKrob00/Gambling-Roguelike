extends SceneTree
## Headless self-test: loads every script and scene, plays scripted blackjack hands against the real
## rules, then fuzzes random runs with random artifacts.
## Run: godot --headless --path <copy of repo> --script res://tools/selftest.gd
## Classes are loaded at run time: this harness compiles before the autoloads exist.

var Table
var RunState
var Card
var Stat
var Rules
var failures := 0
var checks := 0

func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	await process_frame  # autoloads are only ready after the first frame
	Table = load("res://games/blackjack/blackjack_table.gd")
	RunState = load("res://core/run_state.gd")
	Card = load("res://core/card.gd")
	Stat = load("res://core/stat.gd")
	Rules = load("res://core/rules.gd")
	root.get_node("Profile").save_path = "user://selftest_profile.json"
	root.get_node("Profile").reset()
	for autoload in ["Events", "Loc", "Catalog", "Profile", "Audio", "Game"]:
		check(root.has_node(autoload), "autoload %s is up" % autoload)
	_load_everything("res://")
	_catalog()
	_scripted_hands()
	_artifacts()
	_payments_and_death()
	_offers()
	await _step_queue()
	_fuzz()
	_unlocks()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://selftest_profile.json"))
	print("selftest: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------- loading

func _load_everything(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub in [".godot", "assets", "tools", ".git"]:
			continue
		_load_everything(path.path_join(sub))
	for f in dir.get_files():
		var full := path.path_join(f)
		if f.ends_with(".gd"):
			check(load(full) != null, "script loads: " + full)
		elif f.ends_with(".tscn"):
			var scene: PackedScene = load(full)
			check(scene != null, "scene loads: " + full)
			if scene != null:
				var node := scene.instantiate()
				check(node != null, "scene instantiates: " + full)
				if node != null:
					node.free()
		elif f.ends_with(".tres"):
			check(load(full) != null, "resource loads: " + full)

func _catalog() -> void:
	var cat = root.get_node("Catalog")
	check(cat.all().size() == 37, "catalog holds 37 artifacts, has %d" % cat.all().size())
	var tr_ok := true
	for a in cat.all():
		for part in ["NAME", "DESC", "HINT"]:
			var key: String = a.key(part)
			for locale in ["en", "ru"]:
				TranslationServer.set_locale(locale)
				if TranslationServer.translate(key) == key:
					tr_ok = false
					printerr("missing translation ", locale, " ", key)
		check(a.icon != null, "icon set for " + String(a.id))
		check(a.effect_script != null, "effect set for " + String(a.id))
	TranslationServer.set_locale("en")
	check(tr_ok, "every artifact text exists in en and ru")
	for event in ["welcome", "deal", "blackjack", "player_wins", "push", "player_bust", "player_loses",
			"payment", "peek", "trick", "death_broke", "death_debt"]:
		for i in range(1, 4):
			var key := "DEALER_%s_%d" % [event.to_upper(), i]
			check(TranslationServer.translate(key) != key, "dealer line " + key)

# ---------------------------------------------------------------- helpers

func _artifact(id: StringName):
	return root.get_node("Catalog").by_id(id)

func _run(ids: Array = []):
	var loadout := []
	for id in ids:
		loadout.append(_artifact(id))
	var run = RunState.new(&"blackjack", loadout)
	run.chips = 500  # the mechanics tests below want a fat purse; the economy has its own tests
	return run

## `spec` lists cards in the order they are drawn: player, dealer up, player, dealer hole, then extras.
func _stack(table, spec: Array) -> void:
	var cards := []
	for s in spec:
		cards.append(Card.new(s[0], s[1] if s.size() > 1 else 0))
	cards.reverse()
	table.shoe.cards = cards
	table.shoe.total = cards.size() * 2

func _fx(run, id: StringName):
	for fx in run.effects:
		if fx.data.id == id:
			return fx
	return null

# ---------------------------------------------------------------- scripted hands

func _scripted_hands() -> void:
	# Natural blackjack pays 3:2.
	var run = _run()
	var table = Table.new(run, 1)
	_stack(table, [[1], [9], [13], [7]])
	table.add_bet(100)
	table.deal()
	check(table.phase == Table.Phase.RESOLVED, "natural resolves at once")
	check(run.chips == 650, "natural pays 3:2, chips %d" % run.chips)

	# Bust loses the bet.
	run = _run()
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [10]])
	table.add_bet(100)
	table.deal()
	check(table.phase == Table.Phase.PLAYER_TURN, "16 vs 10 keeps playing")
	table.hit()
	check(table.phase == Table.Phase.RESOLVED and run.chips == 400, "bust loses the bet, chips %d" % run.chips)

	# Dealer draws to 17 and stands.
	run = _run()
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [6], [5]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(table.dealer.total() == 21 and run.chips == 400, "dealer drew 21 and won, chips %d" % run.chips)

	# Double down wins double.
	run = _run()
	table = Table.new(run, 1)
	_stack(table, [[5], [10], [6], [7], [10]])
	table.add_bet(100)
	table.deal()
	check(table.can_double(), "can double on two cards")
	table.double_down()
	check(table.phase == Table.Phase.RESOLVED and run.chips == 700, "double down win, chips %d" % run.chips)

	# Push returns the bet.
	run = _run()
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [9]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(run.chips == 500, "push returns the bet, chips %d" % run.chips)

	# Betting rules.
	run = _run()
	table = Table.new(run, 1)
	table.add_bet(9999)
	check(table.bet == 0, "cannot bet more than the purse")
	table.add_bet(25)
	table.clear_bet()
	check(table.bet == 0 and run.chips == 500, "clear_bet refunds")
	check(not table.can_deal(), "cannot deal below the minimum bet")

# ---------------------------------------------------------------- artifacts

func _artifacts() -> void:
	# Lucky clover undoes a bust, three charges.
	var run = _run([&"lucky_clover"])
	var table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [10]])
	table.add_bet(100)
	table.deal()
	var fired := []
	var peeked := []
	run.artifact_triggered.connect(func(fx) -> void: fired.append(fx.data.id))
	table.next_card_peeked.connect(func(c) -> void: peeked.append(c))
	table.hit()
	check(fired == [&"lucky_clover"], "clover announces that it triggered, got %s" % str(fired))
	check(table.phase == Table.Phase.PLAYER_TURN and table.player.total() == 16, "clover undoes the bust")
	check(_fx(run, &"lucky_clover").charges_left == 2, "clover spends a charge")
	check(peeked.size() == 1 and peeked[0] == table.shoe.cards.back(), "clover lays the undone card face up beside the shoe")

	# Stacked deck buries the next card and shows the one beneath.
	run = _run([&"stacked_deck"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [4], [9]])
	table.add_bet(100)
	table.deal()
	var shown := []
	table.next_card_peeked.connect(func(c) -> void: shown.append(c))
	var next_before = table.shoe.cards.back()
	table.use_artifact(_fx(run, &"stacked_deck"))
	check(shown.size() == 1 and shown[0] != next_before and table.shoe.cards.back() == shown[0] and table.shoe.cards[0] == next_before, "stacked deck buries the next card and shows the one beneath")

	# Borrowed time: two more hands, a smaller loan.
	run = _run([&"borrowed_time"])
	check(_fx(run, &"borrowed_time").modify_deadline(Rules.PAYMENT_EVERY) == Rules.PAYMENT_EVERY + 2, "borrowed time adds two hands")
	check(_fx(run, &"borrowed_time").modify_new_loan(150) == 120, "borrowed time shrinks the loan by a fifth")

	# Credit line: a double down with an empty purse, the borrowed chips go on the debt.
	run = _run([&"credit_line"])
	table = Table.new(run, 1)
	_stack(table, [[5], [10], [6], [7], [10], [8]])
	table.deal_all_in()
	check(table.can_double() and run.chips == 0, "credit line lets the player double with an empty purse")
	var debt_before: int = run.debt
	table.double_down()
	check(run.debt == debt_before + 500, "the credit adds the borrowed stake to the debt, debt %d" % run.debt)

	# Magpie: a free offer shows one artifact more; shaky hand: the dealer stands on 16.
	run = _run([&"magpie"])
	var profile = root.get_node("Profile")
	for a in root.get_node("Catalog").all():
		profile.unlocked.append(String(a.id))
	run.start_free_offer()
	check(run.offer.size() == Rules.OFFER_SIZE + 1, "magpie adds one artifact to the offer, got %d" % run.offer.size())
	profile.reset()
	run = _run([&"shaky_hand"])
	table = Table.new(run, 1)
	check(table._dealer_stands_on() == Rules.DEALER_STANDS_ON - 1, "shaky hand makes the dealer stand on 16")

	# Rematch: a push changes the dealer's last card, he plays on.
	run = _run([&"rematch"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [9], [5], [3]])
	table.deal_all_in()
	table.stand()
	check(table.dealer.total() == 18 and run.chips == 1000, "rematch replays the dealer's last card, dealer %d chips %d" % [table.dealer.total(), run.chips])
	check(_fx(run, &"rematch").cooldown_left == 3, "rematch needs hands to recharge")

	# Fan of cards: three cards laid out, one taken, the rest go to the bottom.
	run = _run([&"card_fan"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [2], [9], [5]])
	table.deal_all_in()
	var offered := []
	table.draft_offered.connect(func(c: Array) -> void: offered.append(c))
	table.use_artifact(_fx(run, &"card_fan"))
	check(offered.size() == 1 and offered[0].size() == 3 and not table.draft.is_empty(), "the fan lays three cards out")
	table.hit()
	check(table.player.cards.size() == 2, "nothing else is allowed while choosing")
	var third = table.draft[2]
	table.pick_draft(2)
	check(table.player.cards.back() == third and table.draft.is_empty(), "the chosen card goes to the player")
	check(table.shoe.cards.size() == 7 - 4 - 3 + 2 + 0 + 0 or table.shoe.cards.size() == 2, "the other two cards go under the shoe, %d left" % table.shoe.cards.size())

	# Traitor's chip: a bet on the dealer.
	run = _run([&"traitors_chip"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7]])
	check(_fx(run, &"traitors_chip").can_use(table), "the traitor's chip is used between hands")
	table.use_artifact(_fx(run, &"traitors_chip"))
	table.deal_all_in()
	table.stand()
	check(run.chips == 1000, "a lost hand pays 1:1 when betting on the dealer, chips %d" % run.chips)
	run = _run([&"traitors_chip"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [7]])
	table.use_artifact(_fx(run, &"traitors_chip"))
	table.deal_all_in()
	table.stand()
	check(run.chips == 150 and run.lives == Rules.LIVES - 1, "a won hand loses the stake when betting on the dealer: a finger and the loan again, chips %d" % run.chips)

	# Counter's notebook counts the cards seen: 10 -1, 10 -1, 6 +1, then the hole 7 is 0.
	run = _run([&"card_counter"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7]])
	table.deal_all_in()
	check(table.count == -1, "the count after the deal is -1, got %d" % table.count)
	table.stand()
	check(table.count == -1, "a seven does not change the count, got %d" % table.count)

	# Pickpocket takes the dealer's open card, hand swap changes the hands.
	run = _run([&"pickpocket"])
	table = Table.new(run, 1)
	_stack(table, [[10], [5], [6], [7], [2]])
	table.deal_all_in()
	table.use_artifact(_fx(run, &"pickpocket"))
	check(table.player.cards.size() == 3 and table.player.cards[2].rank == 5 and table.dealer.cards[0].rank == 2, "the pickpocket takes the dealer's open card for a fresh one")
	run = _run([&"hand_swap"])
	table = Table.new(run, 1)
	_stack(table, [[10], [5], [6], [9]])
	table.deal_all_in()
	table.use_artifact(_fx(run, &"hand_swap"))
	check(table.player.total() == 14 and table.dealer.total() == 16, "the hands change places, player %d dealer %d" % [table.player.total(), table.dealer.total()])

	# Marked deck is passive: the hole card is known from the deal.
	run = _run([&"marked_deck"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7]])
	table.add_bet(100)
	table.deal()
	check(table.hole_known, "marked deck shows the hole card at the deal")

	# An undone card goes back on top of the shoe, so the next draw is the same card.
	run = _run([&"lucky_clover"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [9], [4]])
	table.add_bet(100)
	table.deal()
	table.hit()
	check(table.shoe.cards.back().rank == 9, "the undone card is on top of the shoe again")

	# Card up the sleeve swaps the last card and costs hush money.
	run = _run([&"card_sleeve"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [2]])
	table.add_bet(100)
	table.deal()
	var before: int = run.chips
	table.use_artifact(_fx(run, &"card_sleeve"))
	check(table.player.total() == 12, "sleeve swapped 6 for 2, total %d" % table.player.total())
	check(run.chips == before - 20, "sleeve costs 20%% of the stake, chips %d" % run.chips)
	check(not _fx(run, &"card_sleeve").can_use(table) or table.phase != Table.Phase.PLAYER_TURN, "sleeve recharges: not usable right after use")
	check(_fx(run, &"card_sleeve").cooldown_left == 3, "sleeve waits 3 hands")

	# Top hat turns the last card into an ace.
	run = _run([&"top_hat"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7]])
	table.add_bet(100)
	table.deal()
	table.use_artifact(_fx(run, &"top_hat"))
	check(table.player.total() == 21 or table.phase == Table.Phase.RESOLVED, "top hat made an ace: 10+A")
	check(_fx(run, &"top_hat") == null, "a spent consumable leaves the slots")

	# Cursed doll swings both ways.
	run = _run([&"cursed_doll"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [7]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(run.chips == 500 - 100 + 250, "doll win pays half a stake more, chips %d" % run.chips)
	run = _run([&"cursed_doll"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [10]])
	table.add_bet(100)
	table.deal()
	table.hit()
	check(run.chips == 400, "doll loss takes the stake, chips %d" % run.chips)
	run = _run([&"cursed_doll"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [9]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(run.chips == 400, "doll turns a push into a loss, chips %d" % run.chips)

	# Sleight of hand: natural pays 2:1.
	run = _run([&"sleight_of_hand"])
	table = Table.new(run, 1)
	_stack(table, [[1], [9], [13], [7]])
	table.add_bet(100)
	table.deal()
	check(run.chips == 500 - 100 + 300, "sleight pays 2:1, chips %d" % run.chips)

	# Gambler's nerve: a won hand of four cards pays half a stake more.
	run = _run([&"gamblers_nerve"])
	table = Table.new(run, 1)
	_stack(table, [[2], [10], [3], [7], [6], [10]])
	table.add_bet(100)
	table.deal()
	table.hit()
	table.hit()
	check(run.chips == 500 - 100 + 250, "nerve adds half a stake on four cards, chips %d" % run.chips)

	# Rabbit's foot: the third win in a row pays more.
	run = _run([&"rabbits_foot"])
	table = Table.new(run, 1)
	for i in 3:
		_stack(table, [[10], [10], [9], [7]])
		table.add_bet(100)
		table.deal()
		table.stand()
		table.next_hand()
	# wins: +100, then streak 2 pays +100 +20, then streak 3 pays +100 +30
	check(run.chips == 500 + 100 + 120 + 130, "rabbit foot streak bonus, chips %d" % run.chips)

	# Loose change gives half of a lost stake back, once every few hands.
	run = _run([&"loose_change"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [10]])
	table.deal_all_in()
	check(table.bet == 500, "loose change stakes the whole purse, bet %d" % table.bet)
	table.hit()
	check(table.phase == Table.Phase.RESOLVED and run.chips == 250, "loose change returns half of a lost stake, chips %d" % run.chips)
	check(_fx(run, &"loose_change").cooldown_left == 4, "loose change needs a few hands to recharge")

	# Lucky penny: a push pays half a stake more.
	run = _run([&"lucky_penny"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [9]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(run.chips == 500 - 100 + 150, "penny pays a push 150, chips %d" % run.chips)

	# Cracked mirror shows the next card and recharges.
	run = _run([&"cracked_mirror"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [4]])
	table.add_bet(100)
	table.deal()
	var seen := []
	table.next_card_peeked.connect(func(c) -> void: seen.append(c.rank))
	table.use_artifact(_fx(run, &"cracked_mirror"))
	check(seen == [4] and _fx(run, &"cracked_mirror").cooldown_left == 3, "mirror shows the 4 and waits 3 hands, got %s" % str(seen))

	# Hourglass: two more hands, usable between hands, spent after two uses.
	run = _run([&"hourglass"])
	table = Table.new(run, 1)
	var glass = _fx(run, &"hourglass")
	check(glass.can_use(table), "hourglass works between hands")
	table.use_artifact(glass)
	check(run.hands_to_payment == Rules.PAYMENT_EVERY + 2, "hourglass adds two hands, got %d" % run.hands_to_payment)
	table.use_artifact(glass)
	check(_fx(run, &"hourglass") == null and run.hands_to_payment == Rules.PAYMENT_EVERY + 4, "two uses, then it is gone")

	# Hush envelope cuts the debt by a quarter.
	run = _run([&"hush_envelope"])
	table = Table.new(run, 1)
	table.use_artifact(_fx(run, &"hush_envelope"))
	check(run.debt == 190 and _fx(run, &"hush_envelope") == null, "envelope cuts 250 to 190 and is spent, debt %d" % run.debt)

	# Sleeping powder: the dealer stands on what he has.
	run = _run([&"sleeping_powder"])
	table = Table.new(run, 1)
	_stack(table, [[10], [6], [8], [5]])
	table.add_bet(100)
	table.deal()
	table.use_artifact(_fx(run, &"sleeping_powder"))
	table.stand()
	check(table.dealer.cards.size() == 2 and run.chips == 500 - 100 + 200, "the frozen dealer keeps 11 and loses to 18, chips %d" % run.chips)

	# Second wind throws the hand away and deals two new cards; the old ones go to the bottom of the shoe.
	run = _run([&"second_wind"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [5], [3]])
	table.add_bet(100)
	table.deal()
	table.use_artifact(_fx(run, &"second_wind"))
	check(table.player.total() == 8 and table.shoe.cards[0].rank == 10 and table.shoe.cards[1].rank == 6, "second wind redeals 5+3 and buries the old hand, total %d" % table.player.total())

	# Black cat: 19 or more pays double, 17 or less only returns the stake.
	run = _run([&"black_cat"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [10], [7]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(run.chips == 500 - 100 + 300, "cat pays a 20 three to one, chips %d" % run.chips)
	run = _run([&"black_cat"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [7], [6], [10]])
	table.add_bet(100)
	table.deal()
	table.stand()
	check(run.chips == 500, "cat returns only the stake on a 17, chips %d" % run.chips)

	# Pawn ticket and fat purse change what the house writes.
	run = _run([&"pawn_ticket"])
	run.payments_paid = 1
	check(run.current_debt() == 530, "pawn ticket writes 625 as 530, got %d" % run.current_debt())
	run = _run([&"fat_purse"])
	check(run.current_loan() == 225 and run.current_debt() == 440, "fat purse: loan 225, debt 440, got %d / %d" % [run.current_loan(), run.current_debt()])

	# Collector's ledger raises the minimum bet and lowers payments.
	run = _run([&"collectors_ledger"])
	check(run.payment_every() == Rules.PAYMENT_EVERY - 1, "ledger brings the deadline a hand sooner")
	check(run.next_payment() == 175, "ledger cuts the debt due to 175, got %d" % run.next_payment())
	run = _run([&"silver_chip"])
	check(run.next_payment() == 225, "silver chip cuts the debt due to 225, got %d" % run.next_payment())

# ---------------------------------------------------------------- payments and death

func _push_hands(table, count: int, bet: int) -> void:
	for i in count:
		if not table.run.alive:
			return
		_stack(table, [[10], [10], [9], [9]])
		table.add_bet(bet)
		table.deal()
		table.stand()
		table.next_hand()

func _payments_and_death() -> void:
	var fresh = RunState.new(&"blackjack", [])
	check(fresh.chips == 150 and fresh.debt == 250, "the house lends 150 and writes 250, got %d / %d" % [fresh.chips, fresh.debt])
	check([Rules.loan_for(1), Rules.loan_for(2), Rules.loan_for(3)] == [300, 600, 1200], "loans grow exponentially")
	check([Rules.debt_for(1), Rules.debt_for(2)] == [625, 1565], "debts grow exponentially, faster than the loans")
	var run = _run()
	var table = Table.new(run, 1)
	var paid := []
	run.payment_made.connect(func(amount: int, index: int) -> void: paid.append([amount, index]))
	_push_hands(table, Rules.PAYMENT_EVERY, 10)
	check(paid == [[250, 1]], "the debt of 250 is taken after 4 hands, got %s" % str(paid))
	check(run.chips == 550 and run.hands_to_payment == Rules.PAYMENT_EVERY, "paid, the new loan of 300 arrives, chips %d" % run.chips)
	check(run.debt == 625 and run.payments_paid == 1, "the next debt is 625, got %d" % run.debt)
	check(run.offer_stage == RunState.Offer.CHOOSING, "a paid debt opens the free offer")

	# All in is the only stake.
	run = _run()
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [9], [9]])
	table.deal_all_in()
	check(table.phase == Table.Phase.PLAYER_TURN and run.chips == 0 and table.bet == 500, "deal_all_in stakes the whole purse")

	# Cannot pay: death by debt.
	run = _run()
	table = Table.new(run, 1)
	run.chips = 60
	var reason := []
	run.life_lost.connect(func(_left: int, r: StringName) -> void: reason.append(r))
	_push_hands(table, Rules.PAYMENT_EVERY, 10)
	check(reason == [&"debt"] and run.alive and run.lives == 4, "an unpaid debt costs a finger, got %s" % str(reason))
	check(run.chips == 60 + 150 and run.debt == 250 and run.hands_to_payment == Rules.PAYMENT_EVERY, "the house lends the loan again on top of what is left, chips %d" % run.chips)
	for i in 4:
		run.chips = 0
		run._die(&"debt")
	check(not run.alive and run.lives == 0, "the fifth finger ends the run")

	# Broke: below the minimum bet with nothing on the table.
	run = _run()
	table = Table.new(run, 1)
	run.chips = 10
	reason.clear()
	run.life_lost.connect(func(_left: int, r: StringName) -> void: reason.append(r))
	_stack(table, [[10], [10], [6], [7], [10]])
	table.add_bet(10)
	table.deal()
	table.hit()
	check(reason == [&"broke"], "out of chips costs a finger, got %s" % str(reason))

	# A lost hand costs a finger only when less than the loan is left; the loan then comes on top of what is left.
	run = _run([&"loose_change"])
	table = Table.new(run, 1)
	run.chips = 1000
	_stack(table, [[10], [10], [6], [7], [10]])
	table.deal_all_in()
	table.hit()
	check(run.lives == Rules.LIVES and run.chips == 500, "a loss that leaves more than the loan costs no finger, lives %d chips %d" % [run.lives, run.chips])
	run = _run([&"loose_change"])
	table = Table.new(run, 1)
	run.chips = 100
	_stack(table, [[10], [10], [6], [7], [10]])
	table.deal_all_in()
	table.hit()
	check(run.lives == Rules.LIVES - 1 and run.chips == 50 + 150, "a loss that leaves less than the loan costs a finger and the loan is added, lives %d chips %d" % [run.lives, run.chips])

	# Candle of mercy forgives one payment.
	run = _run([&"candle_of_mercy"])
	table = Table.new(run, 1)
	run.chips = 60
	_push_hands(table, Rules.PAYMENT_EVERY, 10)
	check(run.alive and run.chips == 210 and run.payments_paid == 0 and run.debt == 250, "candle forgives the payment and hands over the last loan again, chips %d" % run.chips)
	check(_fx(run, &"candle_of_mercy") == null, "the spent candle is gone")

# ---------------------------------------------------------------- offers

func _offers() -> void:
	var profile = root.get_node("Profile")
	profile.reset()
	var Offer = RunState.Offer
	# At the start only the four open artifacts can be offered, three of them at a time.
	var run = RunState.new(&"blackjack", [])
	run.start_free_offer()
	check(run.offer_stage == Offer.CHOOSING and run.offer.size() == Rules.OFFER_SIZE, "free offer shows %d of the open artifacts, got %d" % [Rules.OFFER_SIZE, run.offer.size()])
	var first = run.offer[0]
	check(run.choose_offer(first) and run.effects.size() == 1, "taking an offer equips it")
	check(run.offer_stage == Offer.NONE and run.offer.is_empty(), "the offer closes after a pick")
	check(not run.choose_offer(first), "cannot take a closed offer")
	# Unlock everything: offers hold three distinct artifacts the player does not own.
	for a in root.get_node("Catalog").all():
		profile.unlocked.append(String(a.id))
	run = RunState.new(&"blackjack", [_artifact(&"lucky_clover")])
	run.start_free_offer()
	check(run.offer.size() == 3, "an offer holds three artifacts")
	var ids: Array = run.offer.map(func(a): return a.id)
	check(not (&"lucky_clover" in ids), "an owned artifact is never offered")
	var seen := {}
	for id in ids:
		seen[id] = true
	check(seen.size() == ids.size(), "offered artifacts are distinct")
	# Full slots: a replacement is required.
	run = RunState.new(&"blackjack", [_artifact(&"lucky_clover"), _artifact(&"marked_deck"), _artifact(&"silver_chip")])
	run.start_free_offer()
	check(run.slots_full(), "three artifacts fill the slots")
	var wanted = run.offer[0]
	check(not run.choose_offer(wanted), "full slots refuse a pick without a replacement")
	var out = run.effects[1]
	check(run.choose_offer(wanted, out), "a pick with a replacement works")
	check(run.effects.size() == 3 and not (out in run.effects), "the replaced artifact is gone")
	check(run.effects.any(func(fx): return fx.data == wanted), "the new artifact is held")
	# Discard.
	var dropped = run.effects[0]
	run.discard(dropped)
	check(run.effects.size() == 2 and not (dropped in run.effects), "discard removes an artifact")
	# Closing a debt opens the free offer, early or on the deadline.
	run = RunState.new(&"blackjack", [])
	run.chips = 1000
	var table = Table.new(run, 1)
	check(run.offer_stage == Offer.NONE, "no offer before a debt is paid")
	check(table.can_pay_off(), "a rich player can pay the debt off between hands")
	var closed := []
	run.loan_closed.connect(func(p: int, n: int, d: int) -> void: closed.append([p, n, d]))
	table.pay_off()
	check(closed == [[250, 300, 625]], "paying off closes the debt and writes a bigger one: %s" % str(closed))
	check(run.chips == 1050 and run.debt == 625 and run.payments_paid == 1, "the new loan comes with its chips, chips %d" % run.chips)
	check(run.offer_stage == Offer.CHOOSING, "a paid debt opens the free offer")
	run.skip_offer()
	check(run.offer_stage == Offer.NONE, "skipping closes the offer")
	run = RunState.new(&"blackjack", [])
	check(not run.can_pay_off() and not run.pay_off(), "a poor player cannot pay off")
	profile.reset()

# ---------------------------------------------------------------- the step queue

func _hung_step() -> void:
	await Signal(self, "never_emitted")

signal never_emitted

## A step that never finishes must not freeze the game: the queue gives up on it and plays the next one.
func _step_queue() -> void:
	var queue = load("res://core/step_queue.gd").new()
	queue.timeout = 0.2
	var order := []
	queue.push(func() -> void: order.append(1))
	queue.push(_hung_step)
	queue.push(func() -> void: order.append(3))
	await queue.drained
	check(order == [1, 3] and not queue.busy, "the queue survives a hung step, ran %s" % str(order))

# ---------------------------------------------------------------- unlocks

func _unlocks() -> void:
	var profile = root.get_node("Profile")
	var events = root.get_node("Events")
	profile.reset()
	for id in [&"lucky_clover", &"card_sleeve", &"cursed_doll", &"silver_chip"]:
		check(profile.is_unlocked(_artifact(id)), "%s is open from the start" % id)
	check(not profile.is_unlocked(_artifact(&"loose_change")), "loose change starts locked")
	events.stat_added.emit(Stat.DEATHS, 1)
	check(not profile.is_unlocked(_artifact(&"loose_change")), "one death does not open loose change")
	events.stat_added.emit(Stat.DEATHS, 1)
	check(profile.is_unlocked(_artifact(&"loose_change")), "two deaths open loose change")
	check(profile.fresh_unlocks.size() == 1, "one fresh unlock is waiting")
	events.stat_peaked.emit(Stat.CHIPS_PEAK, 1600)
	check(profile.is_unlocked(_artifact(&"fat_purse")), "1500 chips unlock the fat purse")
	check(_artifact(&"gamblers_nerve").unlock_reason() == "Won 12 hands", "unlock reason reads naturally: %s" % _artifact(&"gamblers_nerve").unlock_reason())
	events.stat_peaked.emit(Stat.CHIPS_PEAK, 300)
	check(profile.stat(Stat.CHIPS_PEAK) == 1600, "a peak never goes down")
	check(not profile.is_unlocked(_artifact(&"lucky_penny")) and not profile.is_unlocked(_artifact(&"paupers_crown")), "penny and crown start locked")
	events.stat_added.emit(Stat.PUSHES, 1)
	check(profile.is_unlocked(_artifact(&"lucky_penny")), "the first push opens the lucky penny")
	events.stat_added.emit(Stat.LOW_WINS, 1)
	check(profile.is_unlocked(_artifact(&"paupers_crown")), "a win with 10 or less opens the pauper's crown")
	check(not profile.is_unlocked(_artifact(&"credit_line")), "the credit line starts locked")
	events.stat_added.emit(Stat.DEALER_BLACKJACKS, 1)
	check(profile.is_unlocked(_artifact(&"credit_line")), "a dealer's blackjack opens the credit line")
	for pair in [[&"rematch", Stat.TWENTY_ONE_PUSHES, 1], [&"card_fan", Stat.LUCKY_SEVENS, 1], [&"traitors_chip", Stat.NARROW_PAYOFFS, 1], [&"pickpocket", Stat.QUICK_PAYOFFS, 1]]:
		check(not profile.is_unlocked(_artifact(pair[0])), "%s starts locked" % pair[0])
		events.stat_added.emit(pair[1], pair[2])
		check(profile.is_unlocked(_artifact(pair[0])), "%s opens on its event" % pair[0])
	events.stat_peaked.emit(Stat.SAME_KIND, 2)
	check(not profile.is_unlocked(_artifact(&"hand_swap")), "two of a kind do not open the hand swap")
	events.stat_peaked.emit(Stat.SAME_KIND, 3)
	check(profile.is_unlocked(_artifact(&"hand_swap")), "three of a kind open the hand swap")
	check(not profile.is_unlocked(_artifact(&"marked_deck")), "the marked deck starts locked")
	for i in 9:
		events.stat_added.emit(Stat.MIRROR_USES, 1)
	check(not profile.is_unlocked(_artifact(&"marked_deck")), "nine mirror uses do not open the marked deck")
	events.stat_added.emit(Stat.MIRROR_USES, 1)
	check(profile.is_unlocked(_artifact(&"marked_deck")), "ten mirror uses open the marked deck")
	check(not profile.is_unlocked(_artifact(&"glass_eye")), "the glass eye starts locked")
	for i in 3:
		events.stat_added.emit(Stat.SHUFFLES, 1)
	check(profile.is_unlocked(_artifact(&"glass_eye")), "three shuffles open the glass eye")
	check(not profile.is_unlocked(_artifact(&"stacked_deck")), "the stacked deck starts locked")
	for i in 6:
		events.stat_added.emit(Stat.DEALER_BUSTS, 1)
	check(profile.is_unlocked(_artifact(&"stacked_deck")), "six dealer busts open the stacked deck")
	profile.reset()

# ---------------------------------------------------------------- fuzz

func _fuzz() -> void:
	var ids := []
	for a in root.get_node("Catalog").all():
		ids.append(a.id)
	var rng := RandomNumberGenerator.new()
	var hands := 0
	for seed_value in 60:
		rng.seed = seed_value
		var pool := ids.duplicate()
		pool.shuffle()
		var run = _run(pool.slice(0, 3))
		var table = Table.new(run, seed_value)
		var guard := 0
		while run.alive and guard < 400:
			guard += 1
			if run.chips < table.min_bet():
				break
			var steps: Array = [10, 25, 100, 500].filter(func(s: int) -> bool: return s <= run.chips)
			table.add_bet(steps[rng.randi() % steps.size()])
			if not table.can_deal():
				table.clear_bet()
				continue
			table.deal()
			hands += 1
			var actions := 0
			while table.is_player_turn() and actions < 25:
				actions += 1
				if not table.draft.is_empty():
					table.pick_draft(rng.randi() % 3)
					continue
				var pick := rng.randi() % 6
				if pick == 0:
					table.stand()
				elif pick == 1 and table.can_double():
					table.double_down()
				elif pick == 2:
					for fx in run.effects:
						table.use_artifact(fx)
				else:
					table.hit()
			if not table.draft.is_empty():
				table.pick_draft(0)
			if table.is_player_turn():
				table.stand()
			check(run.chips >= 0, "fuzz seed %d: chips never negative" % seed_value)
			check(table.phase == Table.Phase.RESOLVED, "fuzz seed %d: hand always resolves" % seed_value)
			if not run.alive:
				break
			table.next_hand()
	print("fuzz: %d hands played" % hands)
