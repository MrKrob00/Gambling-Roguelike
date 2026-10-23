extends Node
## Global signal bus. Only cross-system facts go here (stats, run end, unlocks); a table talks to
## its own view through its own signals.

signal stat_added(stat: StringName, amount: int)
signal stat_peaked(stat: StringName, value: int)
signal artifact_unlocked(data)
signal run_started(run)
signal run_ended(run, reason: StringName)
signal language_changed(locale: String)
