extends PanelContainer
## What an artifact is, readable at a glance: a coloured title and kind tag, the uses line, and the effect
## as short lines, green for a benefit and red for a cost. Lives in a screen corner, not on the 3D object,
## so it stays crisp and readable on a phone.

const KindStyle := preload("res://core/kind_style.gd")
const ArtifactData := preload("res://data/artifact_data.gd")
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")

const WIDTH := 172.0

var _icon: TextureRect
var _title: Label
var _tag: Label
var _bar: ColorRect
var _body: RichTextLabel
var _foot: Label

func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(26, 26)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	head.add_child(_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_title = Label.new()
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_font_size_override("font_size", 16)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_title)
	_tag = Label.new()
	_tag.add_theme_font_size_override("font_size", 10)
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_tag)
	_bar = ColorRect.new()
	_bar.custom_minimum_size = Vector2(0, 2)
	box.add_child(_bar)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.add_theme_font_size_override("normal_font_size", 11)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)
	_foot = Label.new()
	_foot.add_theme_font_size_override("font_size", 10)
	_foot.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_foot)

## `effect` is the held effect (charges left), or null for an offered or collection artifact.
func show_artifact(data, effect = null, footer: String = "") -> void:
	var color := KindStyle.color_of(data.kind)
	_icon.texture = data.icon
	_title.text = data.title()
	_title.add_theme_color_override("font_color", color)
	var tag := tr(KindStyle.KIND_KEYS[data.kind])
	if data.button and data.cooldown_hands > 0:
		tag += "  ·  " + tr("COOLDOWN") % data.cooldown_hands
	elif data.button and data.uses_per_hand > 0:
		tag += "  ·  " + tr("USES_PER_HAND")
	elif data.charges > 0:
		var left: int = effect.charges_left if effect != null else data.charges
		tag += "  ·  " + tr("CHARGES") % left
	_tag.text = tag
	_tag.add_theme_color_override("font_color", color)
	_bar.color = color
	_body.text = KindStyle.describe_bbcode(data.description())
	_foot.text = footer
	_foot.visible = not footer.is_empty()
	visible = true

func show_locked(data) -> void:
	var color := KindStyle.color_of(data.kind)
	_icon.texture = data.icon
	_icon.modulate = Color(0.25, 0.25, 0.3)
	_title.text = "???"
	_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_tag.text = tr(KindStyle.KIND_KEYS[data.kind])
	_tag.add_theme_color_override("font_color", color)
	_bar.color = Color(0.3, 0.3, 0.4)
	_body.text = "[color=#%s]%s[/color]" % [KindStyle.COST.to_html(false), tr("ARTIFACT_LOCKED")]
	_foot.visible = false
	visible = true

func clear() -> void:
	visible = false
	if _icon != null:
		_icon.modulate = Color.WHITE
