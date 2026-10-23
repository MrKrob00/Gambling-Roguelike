extends "res://world/pickable_3d.gd"
## An equipped artifact standing on the table as a disc tinted by its kind. Tap it to use it (buttons) or
## to read what it does (passives). The text itself is the info panel in the corner.

const KindStyle := preload("res://core/kind_style.gd")
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")
const RADIUS := 0.19
const HEIGHT := 0.045

var fx
var _disc: MeshInstance3D
var _material: StandardMaterial3D
var _icon: Sprite3D
var _charges: Label3D
var _kind_color: Color

func bind(effect) -> void:
	fx = effect
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS * 1.04
	cyl.height = HEIGHT
	cyl.rings = 1
	cyl.radial_segments = 20
	_disc.mesh = cyl
	_material = StandardMaterial3D.new()
	var color := KindStyle.color_of(effect.data.kind)
	_material.albedo_color = color * 0.2
	_material.metallic = 0.5
	_material.roughness = 0.45
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 0.3
	_disc.material_override = _material
	_disc.position.y = HEIGHT / 2.0
	add_child(_disc)
	_icon = Sprite3D.new()
	_icon.texture = effect.data.icon
	_icon.pixel_size = (RADIUS * 1.5) / 128.0
	_icon.axis = Vector3.AXIS_Y
	_icon.shaded = false
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.position.y = HEIGHT + 0.002
	_icon.modulate = color.lerp(Color.WHITE, 0.55)
	add_child(_icon)
	_charges = Label3D.new()
	_charges.font = TITLE_FONT
	_charges.font_size = 48
	_charges.pixel_size = 0.0035
	_charges.outline_size = 6
	_charges.rotation_degrees.x = -90.0
	_charges.position = Vector3(RADIUS * 0.7, HEIGHT + 0.004, RADIUS * 0.6)
	add_child(_charges)
	_kind_color = color
	add_box_shape(Vector3(RADIUS * 2.8, 0.3, RADIUS * 2.8), Vector3(0, 0.1, 0))
	make_ring(RADIUS * 1.12)

func refresh(table) -> void:
	var usable: bool = fx.data.button and fx.can_use(table)
	set_enabled(usable)
	_charges.text = fx.charges_text()
	_icon.modulate = _kind_color.lerp(Color.WHITE, 0.55) if (usable or not fx.data.button) else Color(0.4, 0.38, 0.45)

func _refresh_visual() -> void:
	if _material == null:
		return
	_material.emission_energy_multiplier = 0.9 if hovered else (0.3 if (enabled or not fx.data.button) else 0.05)
	var tween := new_tween()
	tween.tween_property(_disc, "position:y", HEIGHT / 2.0 + (0.03 if hovered else 0.0), 0.08)
	tween.parallel().tween_property(_icon, "position:y", HEIGHT + 0.002 + (0.03 if hovered else 0.0), 0.08)
