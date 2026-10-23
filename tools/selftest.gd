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
	return RunState.new(&"blackjack", loadout)

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
	table.hit()
	check(table.phase == Table.Phase.PLAYER_TURN and table.player.total() == 16, "clover undoes the bust")
	check(_fx(run, &"lucky_clover").charges_left == 2, "clover spends a charge")

	# Marked deck peeks once per hand.
	run = _run([&"marked_deck"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7]])
	table.add_bet(100)
	table.deal()
	var deck = _fx(run, &"marked_deck")
	check(deck.can_use(table), "marked deck usable in the player's turn")
	table.use_artifact(deck)
	check(table.hole_known and not deck.can_use(table), "marked deck peeks once")

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

	# Top hat turns the last card into an ace.
	run = _run([&"top_hat"])
	table = Table.new(run, 1)
	_stack(table, [[10], [10], [6], [7]])
	table.add_bet(100)
	table.deal()
	table.use_artifact(_fx(run, &"top_hat"))
	check(table.player.total() == 21 or table.phase == Table.Phase.RESOLVED, "top hat made an ace: 10+A")
	check(_fx(run, &"top_hat").charges_left == 0, "top hat is spent")

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
	check(run.next_payment() == 70, "ledger cuts the first payment to 70, got %d" % run.next_payment())
	run = _run([&"silver_chip"])
	check(run.next_payment() == 90, "silver chip cuts the first payment to 90, got %d" % run.next_payment())

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
	var run = _run()
	var table = Table.new(run, 1)
	var paid := []
	run.payment_made.connect(func(amount: int, index: int) -> void: paid.append([amount, index]))
	_push_hands(table, 5, 10)
	check(paid == [[100, 1]], "first payment of 100 after 5 hands, got %s" % str(paid))
	check(run.chips == 400 and run.hands_to_payment == 5, "chips %d, clock reset" % run.chips)
	_push_hands(table, 5, 10)
	check(run.payments_paid == 2 and run.chips == 250, "second payment is 150, chips %d" % run.chips)

	# Cannot pay: death by debt.
	run = _run()
	table = Table.new(run, 1)
	run.chips = 60
	var reason := []
	run.died.connect(func(r: StringName) -> void: reason.append(r))
	_push_hands(table, 5, 10)
	check(reason == [&"debt"] and not run.alive, "unpaid payment kills, got %s" % str(reason))

	# Broke: below the minimum bet with nothing on the table.
	run = _run()
	table = Table.new(run, 1)
	run.chips = 10
	reason.clear()
	run.died.connect(func(r: StringName) -> void: reason.append(r))
	_stack(table, [[10], [10], [6], [7], [10]])
	table.add_bet(10)
	table.deal()
	table.hit()
	check(reason == [&"broke"], "out of chips kills, got %s" % str(reason))

	# Candle of mercy forgives one payment.
	run = _run([&"candle_of_mercy"])
	table = Table.new(run, 1)
	run.chips = 60
	_push_hands(table, 5, 10)
	check(run.alive and run.chips == 60 and run.payments_paid == 1, "candle forgives the payment, chips %d" % run.chips)
	check(_fx(run, &"candle_of_mercy").charges_left == 0, "candle is spent")

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
			var steps: Array = Rules.BET_STEPS.filter(func(s: int) -> bool: return s <= run.chips)
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
