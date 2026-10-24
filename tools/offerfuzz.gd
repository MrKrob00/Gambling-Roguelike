extends SceneTree
## Mashes the artifact offer, the hand and the pocket on the real 3D table: random taps on every object that can be
## pressed, plus real pointer events. After every action the invariants must hold (the hand and the pocket are never
## overfull, no artifact stands twice) and the player must always be able to get out of any mode.
## Run: godot --headless --path <copy> --script res://tools/offerfuzz.gd   (SEED=n, ROUNDS=n)

const SCENARIOS := {
	"empty hand": [],
	"full hand, empty pocket": ["pickpocket", "hand_swap", "card_fan"],
	"full hand with the coat": ["smugglers_coat", "pickpocket", "hand_swap"],
	"full hand with the fist": ["clenched_fist", "pickpocket", "hand_swap"],
	"hand and a stocked pocket": ["pickpocket", "hand_swap", "card_fan", "|", "traitors_chip", "card_counter"],
}
var failures := 0
var actions := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _initialize() -> void:
	await process_frame
	Engine.time_scale = 10.0
	var profile = root.get_node("Profile")
	profile.save_path = "user://offerfuzz_profile.json"
	profile.reset()
	var catalog = root.get_node("Catalog")
	for a in catalog.all():
		if not profile.unlocked.has(a.id):
			profile.unlocked.append(a.id)
	var game = root.get_node("Game")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 11
	var rounds := int(OS.get_environment("ROUNDS")) if OS.has_environment("ROUNDS") else 120
	for label in SCENARIOS:
		var hand := []
		var stored := []
		var into: Array = hand
		for id in SCENARIOS[label]:
			if id == "|":
				into = stored
			else:
				into.append(catalog.by_id(StringName(id)))
		var run = load("res://core/run_state.gd").new(&"blackjack", hand)
		for data in stored:
			var fx = run._make_effect(data)
			run.pocket.append(fx)
		run.chips = 400
		game.run = run
		run.start_free_offer()
		var scene = load("res://games/blackjack/blackjack_scene_3d.tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		for i in 20:
			await process_frame
		var view = scene
		for r in rounds:
			await process_frame
			if not view.run.alive or view._queue.busy:
				continue
			if view.run.offer_stage == view.run.Offer.NONE and rng.randf() < 0.5:
				view.run.start_free_offer()
				view._refresh()
			_random_action(view, rng)
			_invariants(view, label)
		# The player can always leave every mode and close the offer.
		for i in 60:
			if view._plaques[&"cancel"].visible and view._plaques[&"cancel"].collision_layer != 0:
				view._plaques[&"cancel"].activate()
			await process_frame
		if view.run.offer_stage == view.run.Offer.CHOOSING:
			check(view._plaques[&"skip"].collision_layer != 0, "%s: the offer can always be skipped" % label)
			view._plaques[&"skip"].activate()
		_invariants(view, label)
		check(not view._stashing and view._swap_with == null and view._pending_pick == null, "%s: no mode is left hanging" % label)
		print("%s: hand %d, pocket %d/%d" % [label, view.run.effects.size(), view.run.pocket.size(), view.run.pocket_capacity()])
		scene.queue_free()
		await process_frame
	print("offerfuzz: ", actions, " actions, ", failures, " failures")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://offerfuzz_profile.json"))
	quit(0 if failures == 0 else 1)

func _random_action(view, rng: RandomNumberGenerator) -> void:
	var plaques: Array = view._plaques.keys().filter(func(k) -> bool: return not (k in [&"deal", &"pay_off"])).map(func(k) -> Object: return view._plaques[k])
	var targets: Array = plaques + view._tokens + view._offer_cards + view._wells
	targets = targets.filter(func(o) -> bool: return is_instance_valid(o) and o.collision_layer != 0 and o.visible)
	if targets.is_empty():
		return
	var target = targets[rng.randi() % targets.size()]
	actions += 1
	if rng.randf() < 0.5:
		target.activate()
	else:
		var pos: Vector2 = view._rig.camera.unproject_position(target.global_position)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = pos
		view._unhandled_input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = pos
		view._unhandled_input(release)

func _invariants(view, label: String) -> void:
	var run = view.run
	check(run.effects.size() <= Rules_SLOTS, "%s: the hand holds %d" % [label, run.effects.size()])
	check(run.pocket.size() <= run.pocket_capacity(), "%s: the pocket holds %d of %d" % [label, run.pocket.size(), run.pocket_capacity()])
	var seen := {}
	for fx in run.effects + run.pocket:
		check(not seen.has(fx.data.id), "%s: %s stands twice" % [label, fx.data.id])
		seen[fx.data.id] = true
	check(view._tokens.size() == run.effects.size() or view._queue.busy, "%s: tokens match the hand" % label)
	check(view._wells.size() >= run.pocket.size(), "%s: a well for every pocketed artifact" % label)

const Rules_SLOTS := 3
