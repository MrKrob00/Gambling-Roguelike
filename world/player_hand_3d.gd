extends Node3D
## The player's right hand: it does everything the player does. A child of the camera, resting in the lower-right
## corner; `reach()` slides it over the screen to an object and taps it with one finger, so every press is a
## visible gesture. Poses and the tap live in `hands/hand_r.tscn` (AnimationPlayer): edit them there.

const HAND_SCENE: PackedScene = preload("res://world/hands/hand_r.tscn")
const GLOVE := Color(0.4, 0.27, 0.22)
const REST_POS := Vector3(0.74, -0.62, -0.9)
const DEPTH := 0.9
const MODEL_SCALE := 2.4
const REACH_TIME := 0.14
const RETURN_TIME := 0.25
## Where the fingertip is relative to the hand origin, in the hand's resting orientation (camera space).
const TIP_OFFSET := Vector3(0.05, 0.42, 0.0)

var _anim: AnimationPlayer
var _tween: Tween

func _ready() -> void:
	position = REST_POS
	var model: Node3D = HAND_SCENE.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation_degrees = Vector3(70.0, 0.0, -18.0)
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

## Points at `world_pos`, taps it, and calls `on_contact` the moment the finger lands. Awaitable; the hand then
## drifts back on its own.
func reach(camera: Camera3D, world_pos: Vector3, on_contact: Callable) -> void:
	var screen := camera.unproject_position(world_pos)
	var target := camera.to_local(camera.project_position(screen, DEPTH)) - TIP_OFFSET
	if _tween != null:
		_tween.kill()
	_anim.play("point")
	_tween = create_tween()
	_tween.tween_property(self, "position", target, REACH_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _tween.finished
	_anim.play("tap")
	on_contact.call()
	_tween = create_tween()
	_tween.tween_interval(0.2)
	_tween.tween_callback(_anim.play.bind("idle"))
	_tween.tween_property(self, "position", REST_POS, RETURN_TIME).set_trans(Tween.TRANS_SINE)
