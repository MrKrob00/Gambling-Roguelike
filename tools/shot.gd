extends SceneTree
## Renders a screen with a real GL driver and saves a PNG. Headless never draws.
## SHOT=menu|lobby|result|table3d|table3d_play  OUT=/tmp/shot.png  LOCALE=en|ru
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
		"table3d", "table3d_play":
			var loadout3 := [catalog.by_id(&"lucky_clover"), catalog.by_id(&"marked_deck"), catalog.by_id(&"cursed_doll")]
			game.run = load("res://core/run_state.gd").new(&"blackjack", loadout3)
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
	if shot == "table3d_play":
		await create_timer(0.8).timeout
		var view = scene
		view.table.add_bet(25)
		view.table.add_bet(100)
		await create_timer(0.6).timeout
		view.table.deal()
		await create_timer(5.0).timeout
	await create_timer(0.3).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
