extends "res://world/pickable_3d.gd"
## An artifact on offer: a big disc standing on the table, tinted by its kind, with the name underneath.
## Tapping it takes it; hovering (or the first tap on a touch screen) shows the full text in the corner.

const KindStyle := preload("res://core/kind_style.gd")
const TITLE_FONT: Font = preload("res://ui/fonts/title_font.tres")
const RADIUS := 0.3
const HEIGHT := 0.06

var data
var _disc: MeshInstance3D
var _material: StandardMaterial3D
var _icon: Sprite3D
var _name: Label3D

func bind(artifact) -> void:
	data = artifact
	var color := KindStyle.color_of(artifact.kind)
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS * 1.05
	cyl.height = HEIGHT
	cyl.rings = 1
	cyl.radial_segments = 24
	_disc.mesh = cyl
	_material = StandardMaterial3D.new()
	_material.albedo_color = color * 0.16
	_material.metallic = 0.4
	_material.roughness = 0.4
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 0.35
	_disc.material_override = _material
	_disc.position.y = HEIGHT / 2.0
	add_child(_disc)
	_icon = Sprite3D.new()
	_icon.texture = artifact.icon
	_icon.pixel_size = (RADIUS * 1.5) / 128.0
	_icon.axis = Vector3.AXIS_Y
	_icon.shaded = false
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.modulate = color.lerp(Color.WHITE, 0.7)
	_icon.position.y = HEIGHT + 0.003
	add_child(_icon)
	_name = Label3D.new()
	_name.text = artifact.title()
	_name.font = TITLE_FONT
	_name.font_size = 56
	_name.pixel_size = 0.0026
	_name.outline_size = 10
	_name.modulate = color
	_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name.no_depth_test = true
	_name.width = 380.0
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.position = Vector3(0.0, 0.34, 0.12)
	_name.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_name)
	add_box_shape(Vector3(RADIUS * 2.5, 0.5, RADIUS * 2.5), Vector3(0, 0.2, 0))
	make_ring(RADIUS * 1.15)

func appear(delay: float) -> void:
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_visual() -> void:
	if _material == null:
		return
	_material.emission_energy_multiplier = 0.65 if hovered else 0.3
	var tween := new_tween()
	tween.tween_property(_disc, "position:y", HEIGHT / 2.0 + (0.05 if hovered else 0.0), 0.08)
	tween.parallel().tween_property(_icon, "position:y", HEIGHT + 0.003 + (0.05 if hovered else 0.0), 0.08)
