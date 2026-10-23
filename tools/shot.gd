extends SceneTree
## Renders a screen with a real GL driver and saves a PNG. Headless never draws.
## SHOT=menu|lobby|result|table3d|table3d_play|table3d_offer  OUT=/tmp/shot.png  LOCALE=en|ru
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path <copy> --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/shot.gd

func _initialize() -> void:
	await process_frame
	var shot := OS.get_environment("SHOT")
	var out := OS.get_environment("OUT") if OS.has_environment("OUT") else "/tmp/shot.png"
	if OS.has_environment("LOCALE"):
		TranslationServer.set_locale(OS.get_environment("LOCALE"))
	var game = root.get_node("Game")
	var catalog = root.get_node("Catalog")
	var scene: Node
	match shot:
		"menu":
			scene = load("res://ui/menu/main_menu.tscn").instantiate()
		"lobby":
			scene = load("res://ui/lobby/lobby.tscn").instantiate()
		"table3d", "table3d_play", "pickcheck", "table3d_offer":
			var loadout3 := [catalog.by_id(&"lucky_clover"), catalog.by_id(&"marked_deck"), catalog.by_id(&"cursed_doll")]
			game.run = load("res://core/run_state.gd").new(&"blackjack", loadout3)
			if shot == "table3d_offer":
				var profile = root.get_node("Profile")
				profile.save_path = "user://shot_profile.json"
				for id in ["cursed_doll", "silver_chip", "top_hat"]:
					profile.unlocked.append(id)
				game.run = load("res://core/run_state.gd").new(&"blackjack", [])
				game.run.start_free_offer()
			scene = load("res://games/blackjack/blackjack_scene_3d.tscn").instantiate()
		"result":
			var run = load("res://core/run_state.gd").new(&"blackjack", [])
			run.payments_paid = 3
			run.peak_chips = 820
			run.hands_played = 17
			game.last_run = run
			game.last_reason = &"debt"
			scene = load("res://ui/result/result.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	if shot == "lobby":
		var tiles := scene.get_node("%Grid").get_children()
		tiles[0].button_pressed = true
		tiles[0].pressed.emit()
		tiles[1].pressed.emit()
		await create_timer(0.2).timeout
	if shot == "pickcheck":
		await create_timer(0.8).timeout
		var view = scene
		var failures := 0
		var checked := 0
		var everything: Array = view._piles + view._tokens + view._plaques.values()
		for phase_name in ["betting", "playing"]:
			if phase_name == "playing":
				view.table.add_bet(25)
				view.table.deal()
				await create_timer(5.0).timeout
			else:
				await create_timer(0.5).timeout
			var active: Array = everything.filter(func(o): return o.collision_layer != 0 and o.visible)
			for p in active:
				var screen: Vector2 = view._rig.camera.unproject_position(p.global_position + Vector3(0, 0.1, 0))
				var hit = view._pick(screen)
				checked += 1
				if hit != p:
					failures += 1
					print("PICK MISS ", phase_name, " ", p.name, " at ", screen, " hit ", hit)
		print("pickcheck: ", checked, " objects, ", failures, " misses")
	if shot == "table3d" and OS.has_environment("TOAST"):
		await create_timer(1.0).timeout
		scene._toast.show_unlock(catalog.by_id(&"card_sleeve"))
		await create_timer(0.8).timeout
	if shot == "table3d" and OS.has_environment("FLASH"):
		await create_timer(1.0).timeout
		scene._flash.play(catalog.by_id(&"cursed_doll"))
		await create_timer(float(OS.get_environment("FLASH")) if OS.get_environment("FLASH").is_valid_float() else 0.3).timeout
	if shot == "table3d_offer":
		await create_timer(1.0).timeout
		if OS.has_environment("PICK"):
			var view = scene
			var checked_o := 0
			var misses_o := 0
			var active: Array = (view._offer_cards + view._plaques.values()).filter(func(o): return o.collision_layer != 0 and o.visible)
			for o in active:
				var screen: Vector2 = view._rig.camera.unproject_position(o.global_position + Vector3(0, 0.1, 0))
				var hit = view._pick(screen)
				checked_o += 1
				if hit != o:
					misses_o += 1
					print("PICK MISS offer ", o.name, " hit ", hit)
			print("pickcheck offer: ", checked_o, " objects, ", misses_o, " misses")
		if OS.has_environment("HOVER"):
			scene._set_hover(scene._offer_cards[0])
			await create_timer(0.4).timeout
	if shot == "table3d_play":
		await create_timer(0.8).timeout
		var view = scene
		view.table.add_bet(25)
		view.table.add_bet(100)
		await create_timer(0.6).timeout
		view.table.deal()
		await create_timer(5.0).timeout
		if OS.has_environment("HOVER"):
			var target = view._plaques[&"hit"]
			target.set_hovered(true)
			await create_timer(0.4).timeout
	await create_timer(0.3).timeout
	if OS.has_environment("INFO"):
		for n in ["TOTAL_OBJECTS_IN_FRAME", "TOTAL_PRIMITIVES_IN_FRAME", "TOTAL_DRAW_CALLS_IN_FRAME"]:
			print("INFO ", n, " ", RenderingServer.get_rendering_info(RenderingServer["RENDERING_INFO_" + n]))
		var lights := scene.find_children("*", "Light3D", true, false)
		var shadowed := lights.filter(func(l): return l.shadow_enabled)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		print("INFO lights ", lights.size(), " shadowed ", shadowed.size(), " meshes ", meshes.size(), " labels3d ", scene.find_children("*", "Label3D", true, false).size())
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
