extends Node3D
## The player's left hand, a child of the camera so it stays in the lower-left corner of the screen. The
## equipped artifacts are fanned between its fingers, turned half edge-on so they never cover the table.
## `focus(token)` lifts one toward the eye and spins it like a coin to show its emblem; the others stay put.

const HAND_SCENE: PackedScene = preload("res://world/hands/hand_l.tscn")
const GLOVE := Color(0.4, 0.27, 0.22)
const HAND_POS := Vector3(-0.66, -0.5, -0.9)
const MODEL_SCALE := 2.4
const REST_SCALE := 0.36
const FOCUS_SCALE := 0.6
const REST_YAW := 1.0
const SLOT_SPACING := 0.12
const FOCUS_LIFT := Vector3(0.24, 0.1, 0.2)

var _rest: Dictionary = {}
var _focused
var _tweens: Dictionary = {}
var _anim: AnimationPlayer

func _ready() -> void:
	position = HAND_POS
	var model: Node3D = HAND_SCENE.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	# The model lies with its fingers along -Z; stand it up so the fingers point up and the back faces the eye.
	model.rotation_degrees = Vector3(90.0, 0.0, 18.0)
	add_child(model)
	_anim = model.get_node("Anim")
	var glove := StandardMaterial3D.new()
	glove.albedo_color = GLOVE
	glove.roughness = 0.55
	glove.emission_enabled = true
	glove.emission = GLOVE
	glove.emission_energy_multiplier = 0.6
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = glove
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Puts a token into slot `index` of `count`, fanned.
func add_token(token, index: int, count: int) -> void:
	add_child(token)
	var pos := Vector3(-0.02 + (index - (count - 1) / 2.0) * SLOT_SPACING, 0.31 + 0.02 * (index % 2), -0.08 + index * 0.02)
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
	_anim.play("open" if is_instance_valid(token) else "idle")
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
