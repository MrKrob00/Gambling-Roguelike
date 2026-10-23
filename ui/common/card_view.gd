extends Control
## One card on the table: pixel template, rank in the corners, suit icon in the window.
## Built from code so a hand can create hundreds without a scene per card.

const Card := preload("res://core/card.gd")

const FACE: Texture2D = preload("res://assets/art/cards/card_front_common.png")
const BACK: Texture2D = preload("res://assets/art/cards/card_back_purple.png")
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")
const CARD_SIZE := Vector2(64, 96)
const COLOR_RED := Color("e8467c")
const COLOR_DARK := Color("d9d4f0")
const FLIP_TIME := 0.12

var card
var face_up: bool = false
var peeked: bool = false

var _art: TextureRect
var _rank_top: Label
var _rank_bottom: Label
var _suit: TextureRect

func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	_art = TextureRect.new()
	_art.size = CARD_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_suit = TextureRect.new()
	_suit.position = Vector2(18, 14)
	_suit.size = Vector2(28, 28)
	_suit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_suit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_suit.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_suit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_suit)
	_rank_top = _make_rank(Vector2(8, 4), HORIZONTAL_ALIGNMENT_LEFT)
	_rank_bottom = _make_rank(Vector2(8, 34), HORIZONTAL_ALIGNMENT_RIGHT)
	_apply()

func _make_rank(pos: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(48, 14)
	l.horizontal_alignment = align
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func setup(c, up: bool) -> void:
	card = c
	face_up = up
	if is_node_ready():
		_apply()

func set_peeked(value: bool) -> void:
	peeked = value
	if is_node_ready():
		_apply()

func _apply() -> void:
	_art.texture = FACE if face_up else BACK
	var show_face := face_up and card != null
	_suit.visible = show_face
	_rank_top.visible = show_face
	_rank_bottom.visible = show_face
	modulate = Color(1, 1, 1, 0.65) if peeked else Color.WHITE
	if not show_face:
		return
	var color := COLOR_RED if card.is_red() else COLOR_DARK
	_suit.texture = load(card.icon_path())
	_suit.modulate = color
	for l in [_rank_top, _rank_bottom]:
		l.text = card.label()
		l.add_theme_color_override("font_color", color)

## Squeezes the card to a line, swaps the side, and opens it again.
func flip_to(up: bool) -> void:
	if up == face_up:
		return
	var tween := create_tween()
	tween.tween_property(self, "scale:x", 0.0, FLIP_TIME)
	await tween.finished
	face_up = up
	_apply()
	tween = create_tween()
	tween.tween_property(self, "scale:x", 1.0, FLIP_TIME)
	await tween.finished
