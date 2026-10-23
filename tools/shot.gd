extends SceneTree
## Renders a screen with a real GL driver and saves a PNG. Headless never draws.
## SHOT=menu|lobby|bet|play|result  OUT=/tmp/shot.png  LOCALE=en|ru
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
		"bet", "play":
			var loadout := [catalog.by_id(&"lucky_clover"), catalog.by_id(&"marked_deck"), catalog.by_id(&"cursed_doll")]
			game.run = load("res://core/run_state.gd").new(&"blackjack", loadout)
			scene = load("res://games/blackjack/blackjack_scene.tscn").instantiate()
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
	if shot == "play":
		scene.get_node("%ChipButtons").get_child(1).pressed.emit()
		scene.get_node("%ChipButtons").get_child(1).pressed.emit()
		await create_timer(0.3).timeout
		scene.get_node("%DealButton").pressed.emit()
		await create_timer(4.0).timeout
	await create_timer(0.3).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
