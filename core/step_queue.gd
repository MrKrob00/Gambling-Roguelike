extends RefCounted
## Runs animation steps strictly one after another. The rules resolve instantly; the view pushes one step
## per event and the screen plays them in order, so nothing is spoiled early.

signal drained

var busy: bool = false
var _steps: Array[Callable] = []

func push(step: Callable) -> void:
	_steps.append(step)
	if not busy:
		_run()

func _run() -> void:
	busy = true
	while not _steps.is_empty():
		var step: Callable = _steps.pop_front()
		await step.call()
	busy = false
	drained.emit()
