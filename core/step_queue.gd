extends RefCounted
## Runs animation steps strictly one after another. The rules resolve instantly; the view pushes one step
## per event and the screen plays them in order, so nothing is spoiled early.
## A step that never finishes (a killed tween, a freed node) must not freeze the game: after STEP_TIMEOUT seconds
## the queue moves on, and the late step, if it ever resumes, is ignored.

signal drained
signal _finished(id: int)

const STEP_TIMEOUT := 12.0

var busy: bool = false
var timeout: float = STEP_TIMEOUT
var _steps: Array[Callable] = []
var _next_id: int = 0
var _completed: int = 0

func push(step: Callable) -> void:
	_steps.append(step)
	if not busy:
		_run()

func _run() -> void:
	busy = true
	while not _steps.is_empty():
		var step: Callable = _steps.pop_front()
		_next_id += 1
		var id := _next_id
		_call(step, id)
		if _completed != id:
			var timer: SceneTreeTimer = (Engine.get_main_loop() as SceneTree).create_timer(timeout)
			timer.timeout.connect(_on_timeout.bind(id))
			while _completed != id:
				await _finished
	busy = false
	drained.emit()

func _call(step: Callable, id: int) -> void:
	await step.call()
	if id > _completed:
		_completed = id
	_finished.emit(id)

func _on_timeout(id: int) -> void:
	if _completed < id:
		push_warning("step_queue: step %d timed out, moving on" % id)
		_completed = id
		_finished.emit(id)
