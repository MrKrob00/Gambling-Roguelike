extends "res://world/pickable_3d.gd"
## A button standing on the table. It is aligned with the camera's image plane (a billboard), so it is
## always an upright, unskewed rectangle on screen, wherever it stands. It has a bigger hit box than it
## looks and lights up under the pointer.

const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")
const SIZE := Vector2(0.56, 0.24)
const DEPTH := 0.06
const BODY_COLOR := Color(0.2, 0.13, 0.3)
const TRIM_COLOR := Color(0.55, 0.38, 0.12)
const TEXT_COLOR := Color(0.96, 0.63, 0.23)
const TEXT_OFF := Color(0.45, 0.4, 0.52)
const LIFT := 0.14

var label: Label3D
var _holder: Node3D
var _body_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _shown: bool = true

func setup(text_key: String) -> void:
	_holder = Node3D.new()
	_holder.position.y = LIFT
	add_child(_holder)
	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(SIZE.x + 0.05, SIZE.y + 0.05, DEPTH * 0.8)
	trim.mesh = trim_mesh
	_trim_material = StandardMaterial3D.new()
	_trim_material.albedo_color = TRIM_COLOR
	_trim_material.emission_enabled = true
	_trim_material.emission = Color(0.9, 0.6, 0.2)
	_trim_material.emission_energy_multiplier = 0.15
	trim.material_override = _trim_material
	trim.position.z = -0.012
	_holder.add_child(trim)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(SIZE.x, SIZE.y, DEPTH)
	body.mesh = body_mesh
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = BODY_COLOR
	_body_material.roughness = 0.5
	_body_material.metallic = 0.2
	_body_material.emission_enabled = true
	_body_material.emission = Color(0.45, 0.25, 0.8)
	_body_material.emission_energy_multiplier = 0.15
	body.material_override = _body_material
	_holder.add_child(body)
	label = Label3D.new()
	label.text = text_key
	label.font = TITLE_FONT
	label.font_size = 96
	label.pixel_size = 0.0030
	label.outline_size = 10
	label.modulate = TEXT_COLOR
	label.position.z = DEPTH / 2.0 + 0.003
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_holder.add_child(label)
	_fit()
	## The hit box is bigger than the button: a thumb should not have to be exact.
	add_box_shape(Vector3(SIZE.x + 0.14, SIZE.y + 0.14, 0.4), Vector3(0, LIFT, 0))

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not visible:
		return
	global_transform.basis = camera.global_transform.basis.orthonormalized() * Basis.from_scale(scale)

## Longer words (Russian especially) shrink to fit the button instead of spilling over its edge.
func _fit() -> void:
	var size := 96
	var text := tr(label.text)
	while size > 28 and label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * label.pixel_size > SIZE.x - 0.1:
		size -= 4
	label.font_size = size

func set_caption(text: String) -> void:
	label.text = text
	_fit()

func show_plaque(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	visible = true
	## A hidden plaque must not catch the pointer: several share one slot.
	collision_layer = PICK_LAYER_BIT if on else 0
	var tween := new_tween()
	tween.tween_property(self, "scale", Vector3.ONE if on else Vector3.ONE * 0.001, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not on:
		tween.tween_callback(func() -> void: visible = false)
	_refresh_visual()

func _press_feedback() -> void:
	var tween := new_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.9, 0.05)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_material.emission_energy_multiplier = 1.6

func _refresh_visual() -> void:
	if _body_material == null:
		return
	var lit := hovered and enabled
	_body_material.emission_energy_multiplier = 0.7 if lit else (0.15 if enabled else 0.0)
	_trim_material.emission_energy_multiplier = 1.1 if lit else (0.15 if enabled else 0.0)
	_body_material.albedo_color = BODY_COLOR if enabled else Color(0.1, 0.09, 0.13)
	_trim_material.albedo_color = TRIM_COLOR if enabled else Color(0.2, 0.17, 0.12)
	label.modulate = (Color(1.0, 0.85, 0.5) if lit else TEXT_COLOR) if enabled else TEXT_OFF
	if _shown:
		var tween := new_tween()
		tween.tween_property(self, "scale", Vector3.ONE * (1.1 if lit else 1.0), 0.08)
