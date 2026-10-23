extends Node3D
## The player's left hand, a child of the camera so it stays in the lower-left corner of the screen. The
## equipped artifacts are fanned between its fingers, turned half edge-on so they never cover the table.
## `focus(token)` lifts one toward the eye and spins it like a coin to show its emblem; the others stay put.

const GLOVE := Color(0.3, 0.2, 0.17)
const CUFF := Color(0.55, 0.52, 0.5)
const HAND_POS := Vector3(-0.74, -0.3, -0.95)
const REST_SCALE := 0.42
const FOCUS_SCALE := 0.6
const REST_YAW := 1.0
const SLOT_SPACING := 0.14
const FOCUS_LIFT := Vector3(0.24, 0.1, 0.2)

var _rest: Dictionary = {}
var _focused
var _tweens: Dictionary = {}

func _ready() -> void:
	position = HAND_POS
	var glove := StandardMaterial3D.new()
	glove.albedo_color = GLOVE
	glove.roughness = 0.55
	glove.emission_enabled = true
	glove.emission = GLOVE
	glove.emission_energy_multiplier = 0.6
	var cuff := StandardMaterial3D.new()
	cuff.albedo_color = CUFF
	cuff.roughness = 0.8
	# Forearm climbs in from the corner; the back of the hand faces the eye; fingers curl up past the discs.
	_box(Vector3(0.16, 0.16, 0.9), Vector3(-0.28, -0.3, 0.35), Vector3(-25.0, -35.0, 0.0), glove)
	_box(Vector3(0.19, 0.19, 0.08), Vector3(-0.17, -0.2, 0.0), Vector3(-25.0, -35.0, 0.0), cuff)
	_box(Vector3(0.36, 0.1, 0.24), Vector3(0.0, -0.12, 0.0), Vector3(-20.0, 0.0, 0.0), glove)
	for i in 4:
		_box(Vector3(0.06, 0.06, 0.2), Vector3(-0.13 + i * 0.087, -0.03, -0.17), Vector3(-55.0, 0.0, 0.0), glove)
	_box(Vector3(0.07, 0.07, 0.2), Vector3(0.22, -0.08, 0.02), Vector3(-30.0, 30.0, 40.0), glove)

func _box(size: Vector3, pos: Vector3, euler_degrees: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	mesh.rotation_degrees = euler_degrees
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

## Puts a token into slot `index` of `count`, fanned.
func add_token(token, index: int, count: int) -> void:
	add_child(token)
	var pos := Vector3((index - (count - 1) / 2.0) * SLOT_SPACING, 0.1 + 0.02 * (index % 2), -0.08 + index * 0.02)
	var yaw := REST_YAW - index * 0.12
	_rest[token] = [pos, yaw]
	token.position = pos
	token.rotation = Vector3(PI / 2.0, yaw, 0.0)
	token.scale = Vector3.ONE * 0.01
	var pop := create_tween()
	pop.tween_property(token, "scale", Vector3.ONE * REST_SCALE, 0.25).set_delay(index * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func clear() -> void:
	_rest.clear()
	_tweens.clear()
	_focused = null

## Lifts and spins `token`; null puts the focused one back. Safe with freed tokens.
func focus(token) -> void:
	if token == _focused:
		return
	if is_instance_valid(_focused) and _rest.has(_focused):
		_move(_focused, _rest[_focused][0], REST_SCALE, _rest[_focused][1], 0.2)
	_focused = token
	if is_instance_valid(token) and _rest.has(token):
		Audio.sfx(&"ui/ui_hover")
		var base: Vector3 = _rest[token][0]
		token.rotation.y = _rest[token][1]
		_move(token, base + FOCUS_LIFT, FOCUS_SCALE, -TAU, 0.45)

func _move(token, pos: Vector3, scale_to: float, yaw: float, duration: float) -> void:
	if _tweens.has(token) and _tweens[token] != null:
		_tweens[token].kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(token, "position", pos, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(token, "scale", Vector3.ONE * scale_to, duration)
	tween.tween_property(token, "rotation:y", yaw, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens[token] = tween
