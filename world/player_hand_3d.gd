extends Node3D
## The player's right hand: it does everything the player does. It rests on the table at the right; `reach()` carries
## it over the felt to an object and taps it with one finger, so every press is a visible gesture. Each death takes a
## finger (`set_lives`). Poses and the tap live in `hands/hand_r.tscn` (AnimationPlayer): edit them there.

const Rules := preload("res://core/rules.gd")
const HAND_SCENE: PackedScene = preload("res://world/hands/hand_r.tscn")
## The glove texture (tools/generate_gloves.py) is lit by its own emission as well, so the hand is not black in the dark room.
const GLOVE_TEXTURE: Texture2D = preload("res://assets/textures/glove_r.png")
const HAND_SCALE := 3.5
## The felt is at y 1.03; the hand rests a little above it, at the right of the near edge.
const REST_POS := Vector3(1.2, 1.14, 1.45)
const PRESENT_POS := Vector3(0.5, 1.7, 1.3)
## For the scenes that come to the hand (cleaver, burst, gun) it lies flat on the table, in the open, and waits.
## On the right, near the collector who holds the gun.
const LAY_POS := Vector3(1.05, 1.14, 0.95)
const HOVER := 0.3
const REACH_TIME := 0.2
const DIP_TIME := 0.07
const RETURN_TIME := 0.3
## Fingers go in this order, one per lost life: the index finger, which does the tapping, goes last.
const CUT_ORDER: Array[String] = ["Little", "Ring", "Middle", "Thumb", "Index"]

var _anim: AnimationPlayer
var _tween: Tween
var _skeleton: Skeleton3D
var _gen: int = 0
var _strain_base: Dictionary = {}
var _glove: StandardMaterial3D

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
	_glove = glove
	glove.albedo_texture = GLOVE_TEXTURE
	glove.emission_texture = GLOVE_TEXTURE
	glove.roughness = 0.55
	glove.emission_enabled = true
	# The emission colour is added to the texture's: black leaves just the texture.
	glove.emission = Color.BLACK
	glove.emission_energy_multiplier = 0.55
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = glove
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Where the index fingertip is relative to the hand's origin, in the current pose.
func _tip_offset() -> Vector3:
	var bone := _skeleton.find_bone("Index_Tip_R")
	var tip := (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin
	return tip - global_position

## Carries the fingertip over `world_pos`, dips, and calls `on_contact` the moment it lands. Awaitable; the hand then
## drifts back on its own. A newer action (another reach, the finger being cut) cancels this one: it simply returns.
## Sequenced with timers, never by awaiting a tween, because a killed tween never reports `finished`.
func reach(world_pos: Vector3, on_contact: Callable) -> void:
	var gen := _begin()
	_anim.play("point")
	_anim.advance(0.3)
	var over := world_pos - _tip_offset() + Vector3(0.0, HOVER, 0.0)
	_move(over, REACH_TIME, Tween.TRANS_CUBIC)
	await get_tree().create_timer(REACH_TIME).timeout
	if gen != _gen:
		return
	_anim.play("tap")
	_move(over - Vector3(0.0, HOVER, 0.0), DIP_TIME, Tween.TRANS_LINEAR)
	await get_tree().create_timer(DIP_TIME).timeout
	if gen != _gen:
		return
	on_contact.call()
	await get_tree().create_timer(0.15).timeout
	if gen != _gen:
		return
	_anim.play("idle")
	_move(REST_POS, RETURN_TIME, Tween.TRANS_SINE)

func _begin() -> int:
	_gen += 1
	if _tween != null:
		_tween.kill()
	return _gen

func _move(to: Vector3, time: float, trans: int) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", to, time).set_trans(trans)

## Hides the fingers already lost: with `lives` left, 5 - lives fingers are gone.
func set_lives(lives: int) -> void:
	for i in CUT_ORDER.size():
		_set_finger(CUT_ORDER[i], i < Rules.LIVES - lives)

func _set_finger(finger: String, cut: bool) -> void:
	var bone := _skeleton.find_bone("%s_Proximal_R" % finger)
	if bone >= 0:
		_skeleton.set_bone_pose_scale(bone, Vector3.ZERO if cut else Vector3.ONE)

## Raises the hand into view, open, ready to lose a finger. Awaitable.
func raise_for_cut() -> void:
	var gen := _begin()
	_anim.play("open")
	_move(PRESENT_POS, 0.4, Tween.TRANS_CUBIC)
	await get_tree().create_timer(0.6).timeout
	if gen != _gen:
		return

## Lays the hand flat on the felt in front of the player and waits. Awaitable.
func lay_for_cut() -> void:
	var gen := _begin()
	_anim.play("open")
	_move(LAY_POS, 0.45, Tween.TRANS_CUBIC)
	await get_tree().create_timer(0.6).timeout
	if gen != _gen:
		return

## The finger the next loss takes strains: it trembles harder and the hand flushes red, `amount` 0..1 (no growing; the
## size never changes). A negative amount puts everything back.
func strain_finger(lives_after: int, amount: float) -> void:
	var finger: String = CUT_ORDER[clampi(Rules.LIVES - lives_after - 1, 0, CUT_ORDER.size() - 1)]
	for seg in ["Proximal", "Intermediate", "Distal"]:
		var bone := _skeleton.find_bone("%s_%s_R" % [finger, seg])
		if bone < 0:
			continue
		if not _strain_base.has(bone):
			_strain_base[bone] = _skeleton.get_bone_pose_rotation(bone)
		var base: Quaternion = _strain_base[bone]
		if amount < 0.0:
			_skeleton.set_bone_pose_rotation(bone, base)
			continue
		var axis := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_skeleton.set_bone_pose_rotation(bone, base * Quaternion(axis, amount * 0.22 * randf()))
	if amount < 0.0:
		_strain_base.clear()
	var glow := clampf(amount, 0.0, 1.0)
	_glove.emission = Color(0.95, 0.04, 0.03) * glow * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.03))

## Where the finger that the next loss takes is, in the world.
func finger_tip(lives_after: int) -> Vector3:
	var bone := _skeleton.find_bone("%s_Tip_R" % CUT_ORDER[clampi(Rules.LIVES - lives_after - 1, 0, CUT_ORDER.size() - 1)])
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin

## The finger goes and the hand clenches.
func cut_finger(lives_after: int) -> void:
	set_lives(lives_after)
	_anim.play("fist")

## Lowers the hand back to the table. Awaitable.
func lower_after_cut(lives_after: int) -> void:
	var gen := _begin()
	set_lives(lives_after)
	await get_tree().create_timer(0.5).timeout
	if gen != _gen:
		return
	_anim.play("idle")
	_move(REST_POS, 0.4, Tween.TRANS_SINE)
	await get_tree().create_timer(0.4).timeout
