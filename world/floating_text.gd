extends Label3D
## A number or word that rises from a point on the table and fades: "+150", "-100".

const FONT: Font = preload("res://ui/fonts/title_font.tres")
const RISE := 0.55
const LIFETIME := 1.3

func play(at: Vector3, message: String, color: Color, size: int = 96) -> void:
	text = message
	font = FONT
	font_size = size
	pixel_size = 0.0038
	outline_size = 14
	modulate = color
	outline_modulate = Color(0.04, 0.02, 0.08)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	position = at
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", at.y + RISE, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.45).set_delay(LIFETIME * 0.55)
	tween.tween_property(self, "outline_modulate:a", 0.0, LIFETIME * 0.45).set_delay(LIFETIME * 0.55)
	tween.chain().tween_callback(queue_free)
