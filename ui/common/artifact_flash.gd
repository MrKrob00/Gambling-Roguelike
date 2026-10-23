extends Control
## The flourish when an artifact does something: its icon pops into the middle of the screen with a violent
## little shake, holds a moment, and leaves just as abruptly. Coloured by the artifact's kind.

const KindStyle := preload("res://core/kind_style.gd")
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")

const IN_TIME := 0.14
const HOLD_TIME := 0.5
const OUT_TIME := 0.16
const SIZE := 150.0

var _holder: Control
var _glow: TextureRect
var _icon: TextureRect
var _label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_holder = Control.new()
	_holder.size = Vector2(SIZE, SIZE + 30.0)
	_holder.pivot_offset = Vector2(SIZE / 2.0, SIZE / 2.0)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_glow = TextureRect.new()
	_glow.size = Vector2(SIZE, SIZE)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.9))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var radial := GradientTexture2D.new()
	radial.gradient = gradient
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1.0, 0.5)
	radial.width = 128
	radial.height = 128
	_glow.texture = radial
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_glow)
	_icon = TextureRect.new()
	_icon.position = Vector2(SIZE * 0.2, SIZE * 0.2)
	_icon.size = Vector2(SIZE * 0.6, SIZE * 0.6)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_icon)
	_label = Label.new()
	_label.position = Vector2(-40.0, SIZE - 6.0)
	_label.size = Vector2(SIZE + 80.0, 26.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", TITLE_FONT)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.06))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_label)

## Shows the artifact and returns when it has left, so the caller can wait for it.
func play(data) -> void:
	var color := KindStyle.color_of(data.kind)
	_icon.texture = data.icon
	_icon.modulate = color.lerp(Color.WHITE, 0.6)
	_glow.modulate = color
	_label.text = data.title()
	_label.add_theme_color_override("font_color", color)
	visible = true
	var total := IN_TIME + HOLD_TIME + OUT_TIME
	var tween := create_tween()
	tween.tween_method(_step, 0.0, total, total)
	await tween.finished
	visible = false

func _step(t: float) -> void:
	var scale_now := 1.0
	var shake := 0.0
	var alpha := 1.0
	if t < IN_TIME:
		var k := t / IN_TIME
		scale_now = lerpf(0.2, 1.3, 1.0 - pow(1.0 - k, 3.0))
		shake = 16.0 * (1.0 - k * 0.4)
	elif t < IN_TIME + HOLD_TIME:
		var k := (t - IN_TIME) / HOLD_TIME
		scale_now = lerpf(1.3, 1.0, 1.0 - pow(1.0 - k, 2.0))
		shake = 6.0 * (1.0 - k)
	else:
		var k := (t - IN_TIME - HOLD_TIME) / OUT_TIME
		scale_now = lerpf(1.0, 0.15, k * k)
		shake = 12.0 * k
		alpha = 1.0 - k
	var size := get_viewport_rect().size
	var center := Vector2(size.x / 2.0, size.y * 0.4)  # above the buttons, clear of the near edge
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	_holder.scale = Vector2.ONE * scale_now
	_holder.position = center - Vector2(SIZE / 2.0, SIZE / 2.0) + jitter
	_holder.rotation = deg_to_rad(randf_range(-1.0, 1.0) * shake * 0.5)
	modulate.a = alpha
