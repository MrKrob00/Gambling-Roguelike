extends Button
## An equipped artifact during a run: icon, charge counter, greyed out when it cannot be used now.

signal triggered(fx)
signal inspected(fx)

const SIZE := Vector2(40, 40)
const ICON_MARGIN := 6.0

var fx
var _icon: TextureRect
var _charges: Label

func _init() -> void:
	custom_minimum_size = SIZE
	theme_type_variation = &"TileButton"
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = ICON_MARGIN
	_icon.offset_top = ICON_MARGIN
	_icon.offset_right = -ICON_MARGIN
	_icon.offset_bottom = -ICON_MARGIN
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_charges = Label.new()
	_charges.position = Vector2(2, 26)
	_charges.size = Vector2(36, 12)
	_charges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_charges.add_theme_font_size_override("font_size", 10)
	_charges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_charges)
	pressed.connect(_on_pressed)

func bind(effect) -> void:
	fx = effect
	_icon.texture = effect.data.icon
	tooltip_text = "%s\n%s" % [effect.data.title(), effect.data.description()]

func refresh(table) -> void:
	var usable: bool = fx.data.button and fx.can_use(table)
	disabled = fx.data.button and not usable
	modulate = Color.WHITE if (usable or not fx.data.button) else Color(1, 1, 1, 0.45)
	_charges.text = fx.charges_text()

func _on_pressed() -> void:
	if fx.data.button:
		triggered.emit(fx)
	else:
		inspected.emit(fx)
