extends "res://world/pickable_3d.gd"
## One of the three cards laid out by the Fan of Cards: a face-up card on the table that can be tapped to take it.

const CardActor := preload("res://world/card_actor.gd")
const LIFT := 0.06

var card
var _actor

func bind(c, texture: Texture2D) -> void:
	card = c
	_actor = CardActor.new()
	add_child(_actor)
	_actor.setup(card, texture, true)
	add_box_shape(Vector3(CardActor.SIZE.x, 0.3, CardActor.SIZE.y), Vector3(0.0, 0.1, 0.0))
	make_ring(0.4)

func appear(from: Vector3, to: Vector3, delay: float) -> void:
	position = from
	scale = Vector3.ONE * 0.6
	var tween := create_tween()
	tween.tween_property(self, "position", to, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector3.ONE * 1.2, 0.35).set_delay(delay)

func leave() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(queue_free)

func _refresh_visual() -> void:
	if _actor == null:
		return
	var tween := new_tween()
	tween.tween_property(_actor, "position:y", LIFT if hovered else 0.0, 0.08)
