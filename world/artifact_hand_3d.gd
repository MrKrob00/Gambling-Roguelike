extends Node3D
## The player's left hand, resting on the table, relaxed, with the artifacts wedged on edge in the grooves between the
## knuckles like coins. `focus(token)` rolls one out of the grip, turns it to face the player and spins it over the
## fingers (a coin roll) to show its emblem; the others stay put. Poses live in `hands/hand_l.tscn` (AnimationPlayer).

const HAND_SCENE: PackedScene = preload("res://world/hands/hand_l.tscn")
## The glove texture (tools/generate_gloves.py) is lit by its own emission as well, so the hand is not black in the dark room.
const GLOVE_TEXTURE: Texture2D = preload("res://assets/textures/glove_l.png")
## The room is scaled up (a chip is 20 cm across), so the hand is too.
const HAND_SCALE := 3.5
const COIN_SCALE := 0.45
## How much of the coin's height sits inside the grip.
const GRIP_SHARE := 0.1
const Token := preload("res://world/artifact_token_3d.gd")
const FOCUS_SCALE := 0.6
## The finger pairs the coins sit between: the joints of the first finger of each pair and the next one.
const PAIRS: Array = [["Index", "Middle"], ["Middle", "Ring"], ["Ring", "Little"]]
## The fingers slope down toward the tips; the coins follow.
const COIN_PITCH := 0.3
const COIN_YAW := 0.6
const FOCUS_LIFT := Vector3(0.55, 0.45, 0.15)
const FOCUS_TILT := 1.25
const ROLL_TIME := 0.6

var _rest: Dictionary = {}
var _focused
var _tweens: Dictionary = {}
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
## Per token: the slot (0 = between index and middle) it sits in.
var _pair: Dictionary = {}
## Per slot: where the coin is pinched, in the frame of each of the two finger bones next to it (the proximal ones).
## The slots are the Marker3D nodes `slot1`..`slot3` placed in `hands/hand_l.tscn` by hand, against the pose the scene
## is saved in; a marker cannot be bound to a bone in the editor, so it is bound here: when the fingers spread, curl
## or close, the point moves with both of its bones instead of staying in one place.
var _slot_local: Array = []
var _lift: Dictionary = {}

func _ready() -> void:
	var model: Node3D = HAND_SCENE.instantiate()
	model.scale = Vector3.ONE * HAND_SCALE
	# Palm down: the model stands with its palm on +x, so lay its back upwards.
	model.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	# The markers were placed against the pose the scene is saved in, so their frames are taken before any animation runs.
	for i in PAIRS.size():
		var marker := model.find_child("slot%d" % (i + 1), true, false) as Marker3D
		var frames: Array = []
		for finger in PAIRS[i]:
			var bone := _skeleton.find_bone("%s_Proximal_L" % finger)
			frames.append(_skeleton.get_bone_global_pose(bone).affine_inverse() * marker.position if marker != null else Vector3.ZERO)
		_slot_local.append(frames)
	add_child(model)
	_anim = model.get_node("Anim")
	_anim.play("idle")
	var glove := StandardMaterial3D.new()
	glove.albedo_texture = GLOVE_TEXTURE
	glove.emission_texture = GLOVE_TEXTURE
	glove.roughness = 0.85
	glove.metallic_specular = 0.2
	glove.emission_enabled = true
	# The emission colour is added to the texture's: black leaves just the texture.
	glove.emission = Color.BLACK
	glove.emission_energy_multiplier = 0.55
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = glove
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Puts a token into the knuckle gap `index`, standing on edge and fanned a little.
func add_token(token, index: int, _count: int) -> void:
	add_child(token)
	var rotation_at_rest := Vector3(COIN_PITCH, -COIN_YAW, -PI / 2.0)
	var q := Quaternion.from_euler(rotation_at_rest)
	# The coin is pinched by the lowest tenth of its height, like a coin held for a flip: the slot is the pinch,
	# the centre rides over it by the radius less that tenth, along the disc's own upward direction.
	var normal := q * Vector3.UP
	var up_in_disc := (Vector3.UP - normal * Vector3.UP.dot(normal)).normalized()
	var radius: float = Token.RADIUS * COIN_SCALE
	var slot := mini(index, PAIRS.size() - 1)
	_lift[token] = up_in_disc * radius * (1.0 - 2.0 * GRIP_SHARE)
	_pair[token] = slot
	var pos: Vector3 = _slot_position(slot) + _lift[token]
	_rest[token] = [pos, q]
	token.position = pos
	token.quaternion = _rest[token][1]
	token.scale = Vector3.ONE * 0.01
	var pop := create_tween()
	pop.tween_property(token, "scale", Vector3.ONE * COIN_SCALE, 0.25).set_delay(index * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func clear() -> void:
	_rest.clear()
	_pair.clear()
	_lift.clear()
	_tweens.clear()
	_focused = null

## Rolls `token` out and spins it; null puts the focused one back. Safe with freed tokens.
func focus(token) -> void:
	if token == _focused:
		return
	if is_instance_valid(_focused) and _rest.has(_focused):
		_roll(_focused, false)
	_focused = token
	_anim.play("open" if is_instance_valid(token) else "idle")
	if is_instance_valid(token) and _rest.has(token):
		Audio.sfx(&"ui/ui_hover")
		_roll(token, true)

func _roll(token, out: bool) -> void:
	if _tweens.has(token) and _tweens[token] != null:
		_tweens[token].kill()
	var rest: Array = _rest[token]
	var from_pos: Vector3 = token.position
	var from_q: Quaternion = token.quaternion
	var from_s: float = token.scale.x
	var to_pos: Vector3 = rest[0] + FOCUS_LIFT if out else rest[0]
	var to_q: Quaternion = Quaternion.from_euler(Vector3(FOCUS_TILT, 0.0, 0.0)) if out else rest[1]
	var to_s := FOCUS_SCALE if out else COIN_SCALE
	var tween := create_tween()
	tween.tween_method(_roll_step.bind(token, from_pos, to_pos, from_q, to_q, from_s, to_s, out), 0.0, 1.0, ROLL_TIME if out else ROLL_TIME * 0.6).set_trans(Tween.TRANS_SINE)
	_tweens[token] = tween

## One frame of the roll: move, turn toward the target orientation and spin once around the coin's own axis.
func _roll_step(t: float, token, from_pos: Vector3, to_pos: Vector3, from_q: Quaternion, to_q: Quaternion, from_s: float, to_s: float, spin: bool) -> void:
	if not is_instance_valid(token):
		return
	token.position = from_pos.lerp(to_pos, t)
	token.scale = Vector3.ONE * lerpf(from_s, to_s, t)
	var q := from_q.slerp(to_q, t)
	token.quaternion = q * Quaternion(Vector3.UP, TAU * t) if spin else q

## Where slot `i` is now, in this node's space: the marker carried by both of its bones, averaged.
func _slot_position(i: int) -> Vector3:
	var total := Vector3.ZERO
	for k in 2:
		var bone := _skeleton.find_bone("%s_Proximal_L" % PAIRS[i][k])
		total += _skeleton.get_bone_global_pose(bone) * _slot_local[i][k]
	return to_local(_skeleton.global_transform * (total / 2.0))

## The coins ride on the hand: each follows its slot through the breathing and the other animations.
func _process(_delta: float) -> void:
	for token in _rest:
		if not is_instance_valid(token):
			continue
		var pos: Vector3 = _slot_position(_pair[token]) + _lift[token]
		_rest[token][0] = pos
		if token == _focused:
			continue
		if _tweens.has(token) and _tweens[token] != null and _tweens[token].is_running():
			continue
		token.position = pos
