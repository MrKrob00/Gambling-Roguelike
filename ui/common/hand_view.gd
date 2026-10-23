extends Control
## A row of cards laid out by hand (a Container would overwrite the tweened positions).

const CardView := preload("res://ui/common/card_view.gd")

const SPACING := 40.0
const SLIDE_TIME := 0.18

var views: Array = []

func add_card(card, face_up: bool):
	var v := CardView.new()
	add_child(v)
	v.setup(card, face_up)
	v.position = Vector2(size.x + 20.0, -60.0)  # the shoe sits above and right of the table
	v.modulate.a = 0.0
	views.append(v)
	var fade := create_tween()
	fade.tween_property(v, "modulate:a", 1.0, SLIDE_TIME)
	_relayout()
	return v

func view_of(card):
	for v in views:
		if v.card == card:
			return v
	return null

func remove_card(card) -> void:
	var v = view_of(card)
	if v == null:
		return
	views.erase(v)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(v, "position:y", v.position.y - 30.0, SLIDE_TIME)
	tween.tween_property(v, "modulate:a", 0.0, SLIDE_TIME)
	tween.chain().tween_callback(v.queue_free)
	_relayout()

func clear() -> void:
	for v in views:
		v.queue_free()
	views.clear()

func _relayout() -> void:
	var n := views.size()
	if n == 0:
		return
	var total := (n - 1) * SPACING + CardView.CARD_SIZE.x
	var x0 := (size.x - total) / 2.0
	for i in n:
		var tween := create_tween()
		tween.tween_property(views[i], "position", Vector2(x0 + i * SPACING, 0.0), SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func settle_time() -> float:
	return SLIDE_TIME + 0.05
