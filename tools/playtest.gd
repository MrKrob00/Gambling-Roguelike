extends SceneTree
## Plays a whole run through the real screens by pressing the real buttons: bet, deal, hit/stand/double,
## next hand, until the collectors win and the result screen shows. Time is sped up.
## Run: godot --headless --path <copy> --script res://tools/playtest.gd

const MAX_REAL_SECONDS := 120.0

var scene_log: Array = []
var steps := 0

func _initialize() -> void:
	await process_frame
	Engine.time_scale = 12.0
	var profile = root.get_node("Profile")
	profile.save_path = "user://playtest_profile.json"
	profile.reset()
	var game = root.get_node("Game")
	var catalog = root.get_node("Catalog")
	var loadout := [catalog.by_id(&"lucky_clover"), catalog.by_id(&"marked_deck")]
	game.start_run(&"blackjack", loadout)
	var started := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while (Time.get_ticks_msec() - started) / 1000.0 < MAX_REAL_SECONDS:
		await process_frame
		var scene := current_scene
		if scene == null:
			continue
		if scene_log.is_empty() or scene_log.back() != scene.name:
			scene_log.append(scene.name)
		if scene.name == "Result":
			break
		if scene.name == "BlackjackScene":
			_act(scene, rng)
	print("scenes visited: ", scene_log)
	print("steps: ", steps, " stats: ", profile.stats)
	print("unlocked: ", profile.unlocked)
	var ok: bool = scene_log.has("Result")
	if ok:
		var result := current_scene
		print("result title: ", result.get_node("%TitleLabel").text, " | ", result.get_node("%PaymentsLabel").text)
	print("PLAYTEST ", "OK" if ok else "TIMEOUT")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest_profile.json"))
	quit(0 if ok else 1)

func _act(scene: Node, rng: RandomNumberGenerator) -> void:
	if scene._pumping or scene.table == null or not scene.run.alive:
		return
	var table = scene.table
	steps += 1
	match table.phase:
		0:  # BETTING
			if table.bet == 0:
				var chips: Node = scene.get_node("%ChipButtons")
				var pick := rng.randi() % 3  # never the 500 chip: the run should last through payments
				var btn: BaseButton = chips.get_child(pick)
				if btn.disabled:
					btn = chips.get_child(0)
				btn.pressed.emit()
			elif not scene.deal_button.disabled:
				scene.deal_button.pressed.emit()
		1:  # PLAYER_TURN
			for s in scene._slots:
				if not s.disabled and s.fx.data.button and rng.randf() < 0.3:
					s.pressed.emit()
					return
			if table.player.total() < 15 or (table.player.total() < 17 and rng.randf() < 0.3):
				scene.hit_button.pressed.emit()
			elif table.can_double() and rng.randf() < 0.2:
				scene.double_button.pressed.emit()
			else:
				scene.stand_button.pressed.emit()
		3:  # RESOLVED
			scene.next_button.pressed.emit()
