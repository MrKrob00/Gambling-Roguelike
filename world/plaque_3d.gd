extends "res://world/pickable_3d.gd"
## A wooden-looking plaque with a word on it: the 3D replacement for a button.

const BODY_COLOR := Color(0.2, 0.13, 0.3)
const TEXT_COLOR := Color(0.96, 0.63, 0.23)
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")
const SIZE := Vector3(0.5, 0.05, 0.22)
const TILT := 32.0

var label: Label3D
var _body: MeshInstance3D
var _material: StandardMaterial3D
var _rest_scale := Vector3.ONE
var _shown: bool = true

func setup(text_key: String, width: float = SIZE.x) -> void:
	_body = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, SIZE.y, SIZE.z)
	_body.mesh = box
	_material = StandardMaterial3D.new()
	_material.albedo_color = BODY_COLOR
	_material.roughness = 0.5
	_material.metallic = 0.3
	_material.emission_enabled = true
	_material.emission = Color(0.4, 0.2, 0.7)
	_material.emission_energy_multiplier = 0.12
	_body.material_override = _material
	add_child(_body)
	label = Label3D.new()
	label.text = text_key
	label.font = TITLE_FONT
	label.font_size = 52
	label.pixel_size = 0.0042
	label.outline_size = 8
	label.modulate = TEXT_COLOR
	label.rotation_degrees.x = -90.0
	label.position.y = SIZE.y / 2.0 + 0.002
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(label)
	add_box_shape(Vector3(width + 0.04, 0.12, SIZE.z + 0.06), Vector3(0, 0.03, 0))
	rotation_degrees.x = TILT

func show_plaque(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	visible = true
	var tween := new_tween()
	tween.tween_property(self, "scale", _rest_scale if on else Vector3.ONE * 0.001, 0.14)
	if not on:
		tween.tween_callback(func() -> void: visible = false)
	_refresh_visual()

func set_enabled(value: bool) -> void:
	super.set_enabled(value)

func _refresh_visual() -> void:
	if _material == null:
		return
	_material.emission_energy_multiplier = 0.9 if (hovered and enabled) else 0.12
	label.modulate = TEXT_COLOR if enabled else Color(0.45, 0.4, 0.5)
	if _shown:
		var target := _rest_scale * (1.08 if (hovered and enabled) else 1.0)
		var tween := new_tween()
		tween.tween_property(self, "scale", target, 0.08)
