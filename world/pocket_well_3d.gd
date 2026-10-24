extends "res://world/pickable_3d.gd"
## One well of the pocket: a dark dish let into the felt. The artifact put away lies in it as a flat coin that does not work.
## `fx` is the artifact in the well (null when empty), so the info panel reads it like any token.

const Token := preload("res://world/artifact_token_3d.gd")
const KindStyle := preload("res://core/kind_style.gd")
const RADIUS := 0.2

var fx
var _coin
var _dish_material: StandardMaterial3D

func _init() -> void:
	super()
	var dish := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS
	cyl.height = 0.01
	cyl.radial_segments = 24
	cyl.rings = 1
	dish.mesh = cyl
	_dish_material = StandardMaterial3D.new()
	_dish_material.albedo_color = Color(0.05, 0.03, 0.06)
	_dish_material.roughness = 0.9
	dish.material_override = _dish_material
	dish.position.y = 0.005
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dish)
	add_box_shape(Vector3(RADIUS * 2.2, 0.2, RADIUS * 2.2), Vector3(0, 0.08, 0))
	make_ring(RADIUS * 1.02, 0.014)

func put(effect) -> void:
	if is_instance_valid(_coin):
		_coin.queue_free()
		_coin = null
	fx = effect
	if effect == null:
		return
	_coin = Token.new()
	_coin.bind(effect)
	_coin.collision_layer = 0
	_coin.scale = Vector3.ONE * 0.85
	add_child(_coin)
	_coin.position.y = 0.01
