extends SceneTree
## Plays a whole run through the real 3D table by activating the real objects on it: chip piles, plaques,
## tokens. Time is sped up. Ends when the collectors win and the result screen shows.
## Run: godot --headless --path <copy> --script res://tools/playtest.gd
## (headless is enough: the picking is done by calling `activate()` on the same objects a click would hit)

const MAX_REAL_SECONDS := 150.0

var scene_log: Array = []
var steps := 0
var chaos_clicks := 0

func _initialize() -> void:
	await process_frame
	Engine.time_scale = 12.0
	var profile = root.get_node("Profile")
	profile.save_path = "user://playtest_profile.json"
	profile.reset()
	var game = root.get_node("Game")
	var catalog = root.get_node("Catalog")
	game.start_run(&"blackjack")  # no loadout: the run opens with the free offer, like a real one
	var started := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 7
	while (Time.get_ticks_msec() - started) / 1000.0 < MAX_REAL_SECONDS:
		await process_frame
		var scene := current_scene
		if scene == null:
			continue
		if scene_log.is_empty() or scene_log.back() != scene.name:
			scene_log.append(scene.name)
		if scene.name == "Result":
			break
		if scene.name == "BlackjackView3D":
			_act(scene, rng)
	print("scenes visited: ", scene_log)
	print("steps: ", steps, " chaos clicks: ", chaos_clicks, " stats: ", profile.stats)
	print("unlocked: ", profile.unlocked)
	var ok: bool = scene_log.has("Result")
	if ok:
		var result := current_scene
		print("result title: ", result.get_node("%TitleLabel").text, " | ", result.get_node("%PaymentsLabel").text)
	print("PLAYTEST ", "OK" if ok else "TIMEOUT")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest_profile.json"))
	quit(0 if ok else 1)

func _press(plaque) -> void:
	if plaque.enabled:
		plaque.activate()

## A player who mashes the screen: presses on real objects while animations play, sometimes slides off before
## releasing. Nothing may hang or break; the run must still reach the result screen.
func _chaos(scene: Node, rng: RandomNumberGenerator) -> void:
	if rng.randf() > 0.35:
		return
	var targets: Array = scene._plaques.values() + scene._tokens + scene._offer_cards
	var target = targets[rng.randi() % targets.size()]
	if not is_instance_valid(target):
		return
	var pos: Vector2 = scene._rig.camera.unproject_position(target.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	scene._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos if rng.randf() < 0.7 else pos + Vector2(300, 100)
	scene._unhandled_input(release)
	chaos_clicks += 1

func _act(scene: Node, rng: RandomNumberGenerator) -> void:
	_chaos(scene, rng)
	if scene._queue.busy or not scene.run.alive:
		return
	var table = scene.table
	steps += 1
	match table.phase:
		0:  # BETTING
			var stage: int = scene.run.offer_stage
			if stage == 1:  # CHOOSING: take the first card; with full slots replace the first token
				if scene._pending_pick != null:
					scene._tokens[0].activate()
				elif not scene._offer_cards.is_empty() and rng.randf() < 0.85:
					scene._offer_cards[0].activate()
				else:
					_press(scene._plaques[&"skip"])
				return
			if scene.run.can_pay_off() and rng.randf() < 0.5:
				_press(scene._plaques[&"pay_off"])
			else:
				_press(scene._plaques[&"deal"])
		1:  # PLAYER_TURN
			for t in scene._tokens:
				if t.enabled and t.fx.data.button and rng.randf() < 0.3:
					t.activate()
					return
			var total: int = table.player.total()
			if total < 15 or (total < 17 and rng.randf() < 0.3):
				_press(scene._plaques[&"hit"])
			elif table.can_double() and rng.randf() < 0.2:
				_press(scene._plaques[&"double"])
			else:
				_press(scene._plaques[&"stand"])
		3:  # RESOLVED
			_press(scene._plaques[&"next"])
