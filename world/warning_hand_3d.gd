extends Node3D
## A collector's hand reaches over the table and raps one finger on the felt: the debt falls due next
## hand. Primitives only (a handful of boxes, no shadows); it lives off-screen until `knock()` plays.

const SKIN := Color(0.5, 0.38, 0.33)
const CUFF := Color(0.55, 0.55, 0.52)
const SLEEVE := Color(0.05, 0.05, 0.07)
const OFFSCREEN_X := 2.4
const HOVER := 0.2

var _hand: Node3D

func _ready() -> void:
	visible = false
	_hand = Node3D.new()
	_hand.scale = Vector3.ONE * 1.7
	add_child(_hand)
	# The arm runs along +x, away from the table; fingers point toward -x, the index one down at the felt.
	_box(Vector3(0.9, 0.11, 0.11), Vector3(0.55, 0.0, 0.0), SLEEVE)
	_box(Vector3(0.05, 0.12, 0.12), Vector3(0.09, 0.0, 0.0), CUFF)
	_box(Vector3(0.12, 0.05, 0.1), Vector3(-0.0, 0.0, 0.0), SKIN)
	_box(Vector3(0.026, 0.13, 0.026), Vector3(-0.07, -0.08, -0.035), SKIN)
	for i in 3:
		_box(Vector3(0.05, 0.03, 0.024), Vector3(-0.07, -0.03, -0.005 + i * 0.03), SKIN)
	_box(Vector3(0.05, 0.026, 0.026), Vector3(0.0, -0.01, 0.07), SKIN)

func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material_override = mat
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand.add_child(mesh)

## Slides in, raps `taps` times (`on_tap` fires at each contact), slides out. Awaitable.
func knock(taps: int, on_tap: Callable) -> void:
	_hand.position = Vector3(OFFSCREEN_X, HOVER, 0.0)
	visible = true
	var slide := create_tween()
	slide.tween_property(_hand, "position:x", 0.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide.finished
	for i in taps:
		var tap := create_tween()
		tap.tween_property(_hand, "position:y", 0.04, 0.07).set_ease(Tween.EASE_IN)
		await tap.finished
		on_tap.call(i)
		var up := create_tween()
		up.tween_property(_hand, "position:y", HOVER, 0.16).set_ease(Tween.EASE_OUT)
		await up.finished
		await get_tree().create_timer(0.22).timeout
	var leave := create_tween()
	leave.tween_property(_hand, "position:x", OFFSCREEN_X, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await leave.finished
	visible = false
