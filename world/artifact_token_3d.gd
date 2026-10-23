extends "res://world/pickable_3d.gd"
## An equipped artifact standing on the table as a dark disc with its icon. Tap it to use it (buttons)
## or to read what it does (passives). Hovering shows the name and text above it.

const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")
const BODY_FONT: Font = preload("res://ui/fonts/body_font.tres")
const RADIUS := 0.19
const HEIGHT := 0.045

var fx
var _disc: MeshInstance3D
var _material: StandardMaterial3D
var _icon: Sprite3D
var _charges: Label3D
var _tip: Label3D

func bind(effect) -> void:
	fx = effect
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS * 1.04
	cyl.height = HEIGHT
	cyl.radial_segments = 24
	_disc.mesh = cyl
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.1, 0.07, 0.16)
	_material.metallic = 0.5
	_material.roughness = 0.45
	_material.emission_enabled = true
	_material.emission = Color(0.96, 0.63, 0.23)
	_material.emission_energy_multiplier = 0.0
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
	_icon.modulate = Color(0.95, 0.9, 1.0)
	add_child(_icon)
	_charges = Label3D.new()
	_charges.font = TITLE_FONT
	_charges.font_size = 48
	_charges.pixel_size = 0.0035
	_charges.outline_size = 6
	_charges.rotation_degrees.x = -90.0
	_charges.position = Vector3(RADIUS * 0.7, HEIGHT + 0.004, RADIUS * 0.6)
	add_child(_charges)
	_tip = Label3D.new()
	_tip.font = BODY_FONT
	_tip.font_size = 40
	_tip.pixel_size = 0.0028
	_tip.outline_size = 8
	_tip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tip.no_depth_test = true
	_tip.width = 520.0
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.position = Vector3(0.0, 0.42, 0.0)
	_tip.visible = false
	_tip.text = "%s\n%s" % [effect.data.title(), effect.data.description()]
	add_child(_tip)
	add_box_shape(Vector3(RADIUS * 2.2, 0.16, RADIUS * 2.2), Vector3(0, 0.05, 0))

func refresh(table) -> void:
	var usable: bool = fx.data.button and fx.can_use(table)
	set_enabled(usable)
	_charges.text = fx.charges_text()
	_icon.modulate = Color(0.95, 0.9, 1.0) if (usable or not fx.data.button) else Color(0.5, 0.45, 0.6)

func _refresh_visual() -> void:
	if _material == null:
		return
	_material.emission_energy_multiplier = 0.5 if (hovered and (enabled or not fx.data.button)) else 0.0
	_tip.visible = hovered
	var tween := new_tween()
	tween.tween_property(_disc, "position:y", HEIGHT / 2.0 + (0.03 if hovered else 0.0), 0.08)
	tween.parallel().tween_property(_icon, "position:y", HEIGHT + 0.002 + (0.03 if hovered else 0.0), 0.08)
