extends Control
## The pop-up in the bottom-right corner when an artifact opens: its icon, its name in the kind colour and
## the reason it was earned. Several unlocks queue up and slide in one after another.

const KindStyle := preload("res://core/kind_style.gd")
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")

const WIDTH := 196.0
const COLUMN_WIDTH := 134.0
const MARGIN := 10.0
const SLIDE_TIME := 0.3
const HOLD_TIME := 3.2

var _panel: PanelContainer
var _icon: TextureRect
var _caption: Label
var _title: Label
var _reason: Label
var _bar: ColorRect
var _queue: Array = []
var _busy: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(34, 34)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(_icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	## A wrapping label needs a known width, or its height is computed one letter per line.
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	row.add_child(column)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 9)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.63, 0.23))
	column.add_child(_caption)
	_title = Label.new()
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 16)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(0, 2)
	column.add_child(_bar)
	_reason = Label.new()
	_reason.add_theme_font_size_override("font_size", 10)
	_reason.add_theme_color_override("font_color", KindStyle.BENEFIT)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_reason)

func show_unlock(data) -> void:
	_queue.append(data)
	if not _busy:
		_run()

func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var data = _queue.pop_front()
		await _play(data)
	_busy = false

func _play(data) -> void:
	var color := KindStyle.color_of(data.kind)
	_icon.texture = data.icon
	_icon.modulate = color.lerp(Color.WHITE, 0.55)
	_caption.text = tr("UNLOCK_TITLE").to_upper()
	_title.text = data.title()
	_title.add_theme_color_override("font_color", color)
	_bar.color = color
	_reason.text = data.unlock_reason()
	_panel.modulate.a = 0.0
	_panel.visible = true
	## Wrapping labels settle their height one frame after the text is set; measure only then, or the panel
	## keeps the oversized height it had while the labels still counted one letter per line.
	await get_tree().process_frame
	await get_tree().process_frame
	_panel.reset_size()
	_panel.modulate.a = 1.0
	var size := get_viewport_rect().size
	var shown := Vector2(size.x - _panel.size.x - MARGIN, size.y - _panel.size.y - MARGIN)
	_panel.position = Vector2(size.x + 10.0, shown.y)
	Audio.sfx(&"ui/ui_confirm")
	Audio.sfx(&"trick/sparkle", 1.0, -6.0)
	var tween := create_tween()
	tween.tween_property(_panel, "position:x", shown.x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_panel, "position:x", size.x + 10.0, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_panel.visible = false
