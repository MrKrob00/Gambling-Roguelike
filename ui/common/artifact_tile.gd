extends Button
## One artifact in the lobby grid: toggles on pick, dark when still locked.
## The icon is a child TextureRect: a Button would share its pixel-art filter with the icon.

signal inspected(tile)

const SIZE := Vector2(44, 44)
const ICON_MARGIN := 7.0

var data
var locked: bool = false
var _icon: TextureRect

func _init() -> void:
	custom_minimum_size = SIZE
	theme_type_variation = &"TileButton"
	toggle_mode = true
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
	_icon.texture = data.icon if data != null else null
	mouse_entered.connect(func() -> void: inspected.emit(self))

func bind(artifact, is_locked: bool) -> void:
	data = artifact
	locked = is_locked
	if _icon != null:
		_icon.texture = artifact.icon
	modulate = Color(0.25, 0.25, 0.3, 1) if is_locked else Color.WHITE
