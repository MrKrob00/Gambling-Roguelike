extends Node3D
## A collector's hand reaches over the table and raps one finger on the felt: the debt falls due next hand. The glove
## is the same rigged hand as the player's (`hands/hand_r.tscn`, poses `point` and `tap`) in a dark sleeve; it lives
## off-screen until `knock()` plays.

const HAND_SCENE: PackedScene = preload("res://world/hands/hand_r.tscn")
const HAND_SCALE := 4.0
const GLOVE := Color(0.05, 0.05, 0.06)
const SLEEVE := Color(0.04, 0.04, 0.06)
const CUFF := Color(0.75, 0.74, 0.7)
const OFFSCREEN_X := 3.4
const HOVER := 0.3

var _hand: Node3D
var _anim: AnimationPlayer

func _ready() -> void:
	visible = false
	_hand = Node3D.new()
	add_child(_hand)
	var model: Node3D = HAND_SCENE.instantiate()
	model.scale = Vector3.ONE * HAND_SCALE
	# Palm down, fingers pointing along -x, toward the middle of the table.
	model.rotation_degrees = Vector3(0.0, 90.0, 90.0)
	_hand.add_child(model)
	_anim = model.get_node("Anim")
	var glove := _material(GLOVE, 0.5)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = glove
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(1.6, 0.26, 0.26), Vector3(1.0, 0.0, 0.0), SLEEVE)
	_box(Vector3(0.08, 0.28, 0.28), Vector3(0.22, 0.0, 0.0), CUFF)

func _material(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	return mat

func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, 0.8)
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand.add_child(mesh)

## Slides in, raps `taps` times (`on_tap` fires at each contact), slides out. Awaitable.
func knock(taps: int, on_tap: Callable) -> void:
	_anim.play("point")
	_hand.position = Vector3(OFFSCREEN_X, HOVER, 0.0)
	visible = true
	var slide := create_tween()
	slide.tween_property(_hand, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide.finished
	for i in taps:
		_anim.play("tap")
		var tap := create_tween()
		tap.tween_property(_hand, "position:y", 0.02, 0.08).set_ease(Tween.EASE_IN)
		await tap.finished
		on_tap.call(i)
		var up := create_tween()
		up.tween_property(_hand, "position:y", HOVER, 0.18).set_ease(Tween.EASE_OUT)
		await up.finished
		await get_tree().create_timer(0.24).timeout
	var leave := create_tween()
	leave.tween_property(_hand, "position:x", OFFSCREEN_X, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await leave.finished
	visible = false
