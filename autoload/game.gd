extends Node
## Owns the current run and moves between screens. Autoload `Game`.

const Rules := preload("res://core/rules.gd")
const RunState := preload("res://core/run_state.gd")

const SCENE_MENU := "res://ui/menu/main_menu.tscn"
const SCENE_LOBBY := "res://ui/lobby/lobby.tscn"
const SCENE_RESULT := "res://ui/result/result.tscn"
const TABLES := {
	&"blackjack": "res://games/blackjack/blackjack_scene_3d.tscn",
}

var run
var last_run
var last_reason: StringName = &""

func start_run(game_id: StringName, loadout: Array) -> void:
	run = RunState.new(game_id, loadout)
	last_run = null
	Events.run_started.emit(run)
	goto(TABLES[game_id])

func finish_run(reason: StringName) -> void:
	last_run = run
	last_reason = reason
	run = null
	goto(SCENE_RESULT)

func goto(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
