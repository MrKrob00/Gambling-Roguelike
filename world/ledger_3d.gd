extends Node3D
## The purse written on the felt in gold, like the inlay of a real table: a small caption, the chip count in big
## letters between two thin rules, and the win streak under it. The number counts up and down on its own and flashes
## green or red on the way. Display only, so nothing here is pickable.

const FONT: Font = preload("res://ui/fonts/title_font.tres")
const GOLD := Color(0.93, 0.7, 0.28)
const DIM := Color(0.62, 0.45, 0.2)
const GAIN := Color(0.6, 1.0, 0.55)
const LOSS := Color(1.0, 0.35, 0.3)
const STREAK := Color(0.85, 0.85, 0.95)
const COUNT_TIME := 0.6
const WIDTH := 0.7

var _caption: Label3D
var _number: Label3D
var _streak: Label3D
var _shown: float = 0.0
var _target: int = -1
var _tween: Tween

func _ready() -> void:
	_caption = _label(44, 0.0026, DIM, Vector3(0.0, 0.0, -0.25))
	_caption.text = "TABLE_CHIPS"
	_number = _label(110, 0.0032, GOLD, Vector3(0.0, 0.0, 0.0))
	_streak = _label(44, 0.0026, STREAK, Vector3(0.0, 0.0, 0.3))
	_rule(-0.15)
	_rule(0.16)
	_set_number(0.0)

func _label(size: int, pixel: float, color: Color, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font = FONT
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 8
	l.outline_modulate = Color(0.04, 0.02, 0.0)
	l.modulate = color
	l.rotation_degrees.x = -90.0
	l.position = pos
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(l)
	return l

## A thin gold line inlaid in the felt, fading out at its ends by a second, shorter one.
func _rule(z: float) -> void:
	for i in 2:
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(WIDTH * (1.0 - i * 0.45), 0.0015, 0.006 if i == 0 else 0.012)
		line.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DIM if i == 0 else GOLD
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.5
		line.material_override = mat
		line.position = Vector3(0.0, -0.002, z)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)

## Counts the number to `chips`. `instant` jumps (the first frame of a table).
func show_chips(chips: int, instant: bool = false) -> void:
	if chips == _target:
		return
	_target = chips
	if _tween != null:
		_tween.kill()
	if instant or not is_inside_tree():
		_set_number(chips)
		return
	var gain := float(chips) > _shown
	_number.modulate = GAIN if gain else LOSS
	_tween = create_tween()
	_tween.tween_method(_set_number, _shown, float(chips), COUNT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_number, "modulate", GOLD, COUNT_TIME + 0.3)
	_tween.parallel().tween_property(_number, "scale", Vector3.ONE * 1.12, 0.15)
	_tween.tween_property(_number, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)

func _set_number(value: float) -> void:
	_shown = value
	_number.text = str(int(round(value)))

## A line under the number while the player is on a streak; hidden otherwise.
func show_streak(streak: int) -> void:
	_streak.visible = streak >= 2
	_streak.text = tr("TABLE_STREAK") % streak
