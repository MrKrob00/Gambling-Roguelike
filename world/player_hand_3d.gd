extends Node3D
## The player's right hand: it does everything the player does. It rests on the table at the right; `reach()` carries
## it over the felt to an object and taps it with one finger, so every press is a visible gesture. Each death takes a
## finger (`set_lives`). Poses and the tap live in `hands/hand_r.tscn` (AnimationPlayer): edit them there.

const Rules := preload("res://core/rules.gd")
const HAND_SCENE: PackedScene = preload("res://world/hands/hand_r.tscn")
const GLOVE := Color(0.4, 0.27, 0.22)
const HAND_SCALE := 3.5
## The felt is at y 1.03; the hand rests a little above it, at the right of the near edge.
const REST_POS := Vector3(1.2, 1.14, 1.45)
const PRESENT_POS := Vector3(0.5, 1.7, 1.3)
const HOVER := 0.3
const REACH_TIME := 0.2
const DIP_TIME := 0.07
const RETURN_TIME := 0.3
## Fingers go in this order, one per lost life: the index finger, which does the tapping, goes last.
const CUT_ORDER: Array[String] = ["Little", "Ring", "Middle", "Thumb", "Index"]

var _anim: AnimationPlayer
var _tween: Tween
var _skeleton: Skeleton3D

func _ready() -> void:
	position = REST_POS
	var model: Node3D = HAND_SCENE.instantiate()
	model.scale = Vector3.ONE * HAND_SCALE
	# The mirror of the left hand: its back is on -x, so turn it the other way to lie palm down.
	model.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(model)
	_anim = model.get_node("Anim")
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_anim.play("idle")
	var glove := StandardMaterial3D.new()
	glove.albedo_color = GLOVE
	glove.roughness = 0.55
	glove.emission_enabled = true
	glove.emission = GLOVE
	glove.emission_energy_multiplier = 0.6
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = glove
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Where the index fingertip is relative to the hand's origin, in the current pose.
func _tip_offset() -> Vector3:
	var bone := _skeleton.find_bone("Index_Tip_R")
	var tip := (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin
	return tip - global_position

## Carries the fingertip over `world_pos`, dips, and calls `on_contact` the moment it lands. Awaitable; the hand then
## drifts back on its own.
func reach(world_pos: Vector3, on_contact: Callable) -> void:
	if _tween != null:
		_tween.kill()
	_anim.play("point")
	_anim.advance(0.3)
	var over := world_pos - _tip_offset() + Vector3(0.0, HOVER, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "global_position", over, REACH_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _tween.finished
	_anim.play("tap")
	_tween = create_tween()
	_tween.tween_property(self, "global_position", over - Vector3(0.0, HOVER, 0.0), DIP_TIME).set_ease(Tween.EASE_IN)
	await _tween.finished
	on_contact.call()
	_tween = create_tween()
	_tween.tween_interval(0.15)
	_tween.tween_callback(_anim.play.bind("idle"))
	_tween.tween_property(self, "global_position", REST_POS, RETURN_TIME).set_trans(Tween.TRANS_SINE)

## Hides the fingers already lost: with `lives` left, 5 - lives fingers are gone.
func set_lives(lives: int) -> void:
	for i in CUT_ORDER.size():
		_set_finger(CUT_ORDER[i], i < Rules.LIVES - lives)

func _set_finger(finger: String, cut: bool) -> void:
	var bone := _skeleton.find_bone("%s_Proximal_R" % finger)
	if bone >= 0:
		_skeleton.set_bone_pose_scale(bone, Vector3.ZERO if cut else Vector3.ONE)

## Raises the hand into view and takes the next finger. Awaitable.
func present_cut(lives: int) -> void:
	if _tween != null:
		_tween.kill()
	_anim.play("open")
	_tween = create_tween()
	_tween.tween_property(self, "global_position", PRESENT_POS, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.5)
	_tween.tween_callback(set_lives.bind(lives))
	_tween.tween_interval(1.1)
	_tween.tween_callback(_anim.play.bind("idle"))
	_tween.tween_property(self, "global_position", REST_POS, 0.4).set_trans(Tween.TRANS_SINE)
	await _tween.finished
