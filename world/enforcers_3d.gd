extends Node3D
## The debt made flesh: two collectors stand at the player's shoulders, the same faceless man in a black suit twice (a CC0
## base mesh, matte black, arms hung down, breathing), a little behind the player. The nearer the payment, the closer
## they lean in (`set_urgency`, 0..1). When a finger is shot off, one steps up and fires from his own raised arm
## (`begin_gun`, `end_gun`).

const MODEL: PackedScene = preload("res://assets/models/enforcers/male_base_mesh.glb")
const SUIT := Color(0.1, 0.1, 0.14)
## The mesh is human-sized and the room is oversized (a chip is 20 cm).
const FIGURE_SCALE := 1.5
const FAR_X := 2.2
const NEAR_X := 2.0
## They face the table, turned a little toward the player.
const TURN := 0.12
const BREATH := 0.012
## Resting arm: down along the body, the forearm a little forward (skeleton space, x is the side of the arm).
const UPPER_DIR := Vector3(0.1, -1.0, 0.0)
const FORE_DIR := Vector3(0.08, -0.85, 0.5)
const STEP_TIME := 0.55
## Which way a finger joint bends (about the bone's side axis); the fist is closed with this sign.
const CURL_DIR := 1.0
## The fist rises this far over the felt between knocks.
const KNOCK_LIFT := 0.45
## How much of the straight reach the gunman uses: the rest is a bent elbow.
const ELBOW_BEND := 0.78

var _figures: Array = []
var _time: float = 0.0
## The gunman: his figure, the gun node, the target and how far he has stepped up (0..1).
var _gunner: Dictionary = {}
var _gun: Node3D
var _gun_grip := Vector3.ZERO
var _gun_tip := Vector3.ZERO
## Palm to the finger: the gun's length plus the gap.
var _hold := 0.0
## Bone lengths of the arm in metres: upper arm, forearm.
var _upper_len := 0.0
var _fore_len := 0.0
var _lean := 0.0
var _pointing := false
var _arm := "L"
var _step: float = 0.0
## Barrel lift in radians, for the recoil.
var kick: float = 0.0

func _ready() -> void:
	var suit := StandardMaterial3D.new()
	suit.albedo_color = SUIT
	suit.roughness = 0.55
	suit.emission_enabled = true
	suit.emission = Color(0.12, 0.12, 0.17)
	suit.rim_enabled = true
	suit.rim = 1.0
	suit.rim_tint = 0.2
	for i in 2:
		var side: int = -1 if i == 0 else 1
		var body := Node3D.new()
		body.position = Vector3(side * FAR_X, 0.0, 0.0)
		body.rotation.y = side * TURN
		add_child(body)
		# `step` is what walks up to the table; `body` only holds the home spot the urgency tween moves.
		var step := Node3D.new()
		body.add_child(step)
		var model: Node3D = MODEL.instantiate()
		model.scale = Vector3.ONE * FIGURE_SCALE
		# The skeleton faces +z: turn the figure to face the table (-z).
		model.rotation_degrees.y = 180.0
		step.add_child(model)
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.material_override = suit
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The skinned mesh reports its bind-pose box, which sits a metre off the posed figure: never cull it by that.
		mesh.custom_aabb = AABB(Vector3(-1.0, -0.2, -1.0), Vector3(2.0, 2.4, 2.0))
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		# The imported skeleton sits a metre below its node: stand the feet on the floor.
		model.position.y -= skeleton.global_position.y
		var figure := {"body": body, "step": step, "side": side, "skeleton": skeleton, "chest": skeleton.find_bone("spine.003"), "phase": randf() * TAU}
		_figures.append(figure)
		_rest_arms(figure)
	_show_gunner(false)

func _process(delta: float) -> void:
	_time += delta
	for f in _figures:
		var skeleton: Skeleton3D = f.skeleton
		var s := 1.0 + BREATH * sin(_time * 1.6 + f.phase)
		skeleton.set_bone_pose_scale(f.chest, Vector3(s, 1.0, s))
	if not _gunner.is_empty():
		_pose_gunner()

## The collectors stand mostly out of frame, so they are not drawn or animated at all until the right-hand one has
## something to do: a skinned figure costs a skeleton update and draw calls every frame (a measurable lag on phones).
func _show_gunner(on: bool) -> void:
	for f in _figures:
		f.body.visible = on and f == _figures[1]
	set_process(on)

func set_urgency(urgency: float) -> void:
	for f in _figures:
		var tween := create_tween()
		tween.tween_property(f.body, "position:x", f.side * lerpf(FAR_X, NEAR_X, urgency), 0.8).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------- arms

func _rest_arms(figure: Dictionary) -> void:
	for arm in ["L", "R"]:
		var lat := 1.0 if arm == "L" else -1.0
		var skeleton: Skeleton3D = figure.skeleton
		_point_arm(skeleton, arm, Vector3(UPPER_DIR.x * lat, UPPER_DIR.y, UPPER_DIR.z), Vector3(FORE_DIR.x * lat, FORE_DIR.y, FORE_DIR.z))

## Swings the upper arm and the forearm so their bones point along the given directions (skeleton space). A bone's pose is its whole local
## transform (not a delta on the rest), so the swing is measured against the rest pose in skeleton space. Parents are posed first.
func _point_arm(skeleton: Skeleton3D, arm: String, upper_dir: Vector3, fore_dir: Vector3, hand_dir: Vector3 = Vector3.ZERO) -> void:
	if hand_dir == Vector3.ZERO:
		hand_dir = fore_dir
	var chain := [["upper_arm.", "forearm.", upper_dir], ["forearm.", "hand.", fore_dir], ["hand.", "f_middle.01.", hand_dir]]
	for link in chain:
		var bone := skeleton.find_bone(link[0] + arm)
		var child := skeleton.find_bone(link[1] + arm)
		var rest := skeleton.get_bone_global_rest(bone)
		var rest_dir: Vector3 = (skeleton.get_bone_global_rest(child).origin - rest.origin).normalized()
		var swing := Quaternion(rest_dir, (link[2] as Vector3).normalized())
		var global_basis := Basis(swing) * rest.basis
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis
		var local := parent_basis.inverse() * global_basis
		skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())

# ---------------------------------------------------------------- the gunman

## The right-hand collector draws the gun from beside the player: his body stays where it is, he leans over and his arm
## reaches out with `gun` in the palm, its barrel along the arm (`grip` is the point of the gun node held in the palm,
## `reach` the grip to muzzle distance), `gap` short of `tip`.
func begin_gun(tip: Vector3, gun: Node3D, grip: Vector3, reach: float, gap: float) -> void:
	_begin(tip, gun, grip, gap + reach, false)

## The same arm raps on the felt at `spot`, with the first finger out and the rest curled.
func knock(spot: Vector3, taps: int, on_tap: Callable) -> void:
	var raised := spot + Vector3(0.0, KNOCK_LIFT, 0.0)
	_begin(raised, null, Vector3.ZERO, 0.02, true)
	await get_tree().create_timer(STEP_TIME + 0.25).timeout
	for i in taps:
		var fall := create_tween()
		fall.tween_property(self, "_gun_tip:y", spot.y, 0.1).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(0.1).timeout
		on_tap.call(i)
		var lift := create_tween()
		lift.tween_property(self, "_gun_tip:y", raised.y, 0.16).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(0.3).timeout
	await end_gun()

## Raises the arm toward `tip`, the hand ending `hold` short of it. The lean (a bow of the spine) is how far he has to
## stoop for the elbow to stay bent: found once, here.
func _begin(tip: Vector3, gun: Node3D, grip: Vector3, hold: float, pointing: bool) -> void:
	_show_gunner(true)
	_gun = gun
	_gun_grip = grip
	_gun_tip = tip
	_hold = hold
	_pointing = pointing
	_gunner = _figures[1]
	var skeleton: Skeleton3D = _gunner.skeleton
	var upper := skeleton.find_bone("upper_arm.L")
	var fore := skeleton.find_bone("forearm.L")
	var hand := skeleton.find_bone("hand.L")
	_upper_len = (skeleton.get_bone_global_rest(fore).origin - skeleton.get_bone_global_rest(upper).origin).length() * FIGURE_SCALE
	_fore_len = (skeleton.get_bone_global_rest(hand).origin - skeleton.get_bone_global_rest(fore).origin).length() * FIGURE_SCALE
	_arm = "L"
	_lean = 0.0
	for i in 14:
		var angle := i * 0.1
		_apply_lean(skeleton, angle)
		_lean = angle
		var shoulder := _shoulder_world(skeleton, "L")
		var aim := (tip - shoulder).normalized()
		if shoulder.distance_to(tip - aim * hold) <= (_upper_len + _fore_len) * ELBOW_BEND:
			break
	_apply_lean(skeleton, 0.0)
	_step = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_step", 1.0, STEP_TIME).set_trans(Tween.TRANS_SINE)

func end_gun() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_step", 0.0, STEP_TIME).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(STEP_TIME + 0.05).timeout
	_gunner = {}
	_gun = null
	kick = 0.0
	for f in _figures:
		_apply_lean(f.skeleton, 0.0)
		_rest_arms(f)
		_curl_hand(f.skeleton, "L", 0.0)
	_show_gunner(false)

## Bows the spine toward the table (a pitch about the figure's own side axis, shared by three bones).
func _apply_lean(skeleton: Skeleton3D, angle: float) -> void:
	for bone_name in ["spine", "spine.001", "spine.002"]:
		var bone := skeleton.find_bone(bone_name)
		var base := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone, base * Quaternion(Vector3.RIGHT, angle / 3.0))

## Curls the three fingers after the first one, so only the first finger knocks.
func _curl_hand(skeleton: Skeleton3D, arm: String, amount: float) -> void:
	for finger in ["middle", "ring", "pinky"]:
		for joint in ["01", "02", "03"]:
			var bone := skeleton.find_bone("f_%s.%s.%s" % [finger, joint, arm])
			if bone < 0:
				continue
			var base := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(bone, base * Quaternion(Vector3.RIGHT, CURL_DIR * amount * 1.3))

func _shoulder_world(skeleton: Skeleton3D, arm: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm." + arm)).origin

func _pose_gunner() -> void:
	var skeleton: Skeleton3D = _gunner.skeleton
	var t := _step
	_apply_lean(skeleton, _lean * t)
	if _pointing:
		_curl_hand(skeleton, _arm, t)
	var shoulder := _shoulder_world(skeleton, _arm)
	var aim_world := (_gun_tip - shoulder).normalized()
	var hand_at := _gun_tip - aim_world * _hold
	# Two-bone reach: the elbow drops down and out, so the arm bends instead of stretching.
	var to_hand := hand_at - shoulder
	var span := clampf(to_hand.length(), 0.05, _upper_len + _fore_len - 0.01)
	var along := to_hand.normalized()
	var a := (span * span + _upper_len * _upper_len - _fore_len * _fore_len) / (2.0 * span)
	var h := sqrt(maxf(_upper_len * _upper_len - a * a, 0.0))
	var body: Node3D = _gunner.body
	var outward := shoulder - body.global_position
	outward.y = 0.0
	var pole := Vector3.DOWN + outward.normalized() * 0.5
	pole = (pole - along * pole.dot(along)).normalized()
	var elbow := shoulder + along * a + pole * h
	var to_local := skeleton.global_transform.basis.inverse()
	var lat := 1.0 if _arm == "L" else -1.0
	var down := Vector3(UPPER_DIR.x * lat, UPPER_DIR.y, UPPER_DIR.z).normalized()
	var fore_down := Vector3(FORE_DIR.x * lat, FORE_DIR.y, FORE_DIR.z).normalized()
	var upper_dir := down.slerp((to_local * (elbow - shoulder)).normalized(), t)
	var fore_dir := fore_down.slerp((to_local * (hand_at - elbow)).normalized(), t)
	var hand_dir := fore_down.slerp((to_local * aim_world).normalized(), t)
	_point_arm(skeleton, _arm, upper_dir, fore_dir, hand_dir)
	if not is_instance_valid(_gun):
		return
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand." + _arm)).origin
	var palm := hand + aim_world * 0.1
	var x_axis := -aim_world
	var up := (Vector3.UP - x_axis * Vector3.UP.dot(x_axis)).normalized()
	var z_axis := x_axis.cross(up)
	var frame := Basis(x_axis, up, z_axis).rotated(z_axis, kick)
	_gun.global_transform = Transform3D(frame, palm - frame * _gun_grip)
