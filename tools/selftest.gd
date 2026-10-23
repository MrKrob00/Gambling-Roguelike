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
	check(cat.all().size() == 11, "catalog holds 11 artifacts, has %d" % cat.all().size())
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
	run.artifact_triggered.connect(func(fx) -> void: fired.append(fx.data.id))
	table.hit()
	check(fired == [&"lucky_clover"], "clover announces that it triggered, got %s" % str(fired))
	check(table.phase == Table.Phase.PLAYER_TURN and table.player.total() == 16, "clover undoes the bust")
	check(_fx(run, &"lucky_clover").charges_left == 2, "clover spends a charge")

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
	check(run.chips == before - 25, "sleeve costs 25%% of the bet, chips %d" % run.chips)
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
	check(run.chips == 500 - 100 + 225, "doll win pays 225, chips %d" % run.chips)
	run = _run([&"cursed_doll"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7], [10]])
	table.add_bet(100)
	table.deal()
	table.hit()
	check(run.chips == 500 - 100 - 25, "doll loss costs 125, chips %d" % run.chips)

	# Sleight of hand: natural pays 2:1.
	run = _run([&"sleight_of_hand"])
	table = Table.new(run, 1)
	_stack(table, [[1], [9], [13], [7]])
	table.add_bet(100)
	table.deal()
	check(run.chips == 500 - 100 + 300, "sleight pays 2:1, chips %d" % run.chips)

	# Gambler's nerve: doubled win pays half a bet more.
	run = _run([&"gamblers_nerve"])
	table = Table.new(run, 1)
	_stack(table, [[5], [10], [6], [7], [10]])
	table.add_bet(100)
	table.deal()
	table.double_down()
	check(run.chips == 500 - 200 + 400 + 100, "nerve adds half a doubled bet, chips %d" % run.chips)

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

	# Collector's ledger raises the minimum bet and lowers payments.
	run = _run([&"collectors_ledger"])
	check(run.min_bet() == 25, "ledger raises the minimum bet")
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
	check(run.chips == 150 and run.debt == 250 and run.hands_to_payment == Rules.PAYMENT_EVERY, "the house lends the loan again, chips %d" % run.chips)
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
	# At the start only the two open artifacts can be offered.
	var run = RunState.new(&"blackjack", [])
	run.start_free_offer()
	check(run.offer_stage == Offer.CHOOSING and run.offer.size() == 2, "free offer shows the 2 open artifacts, got %d" % run.offer.size())
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

# ---------------------------------------------------------------- unlocks

func _unlocks() -> void:
	var profile = root.get_node("Profile")
	var events = root.get_node("Events")
	profile.reset()
	check(profile.is_unlocked(_artifact(&"lucky_clover")), "clover is open from the start")
	check(not profile.is_unlocked(_artifact(&"cursed_doll")), "doll starts locked")
	events.stat_added.emit(Stat.DEATHS, 1)
	check(profile.is_unlocked(_artifact(&"cursed_doll")), "first death unlocks the doll")
	check(profile.fresh_unlocks.size() == 1, "one fresh unlock is waiting")
	events.stat_peaked.emit(Stat.CHIPS_PEAK, 1200)
	check(profile.is_unlocked(_artifact(&"silver_chip")), "1000 chips unlock the silver chip")
	check(_artifact(&"card_sleeve").unlock_reason() == "Won 5 hands", "unlock reason reads naturally: %s" % _artifact(&"card_sleeve").unlock_reason())
	events.stat_peaked.emit(Stat.CHIPS_PEAK, 300)
	check(profile.stat(Stat.CHIPS_PEAK) == 1200, "a peak never goes down")
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
			if table.is_player_turn():
				table.stand()
			check(run.chips >= 0, "fuzz seed %d: chips never negative" % seed_value)
			check(table.phase == Table.Phase.RESOLVED, "fuzz seed %d: hand always resolves" % seed_value)
			if not run.alive:
				break
			table.next_hand()
	print("fuzz: %d hands played" % hands)
