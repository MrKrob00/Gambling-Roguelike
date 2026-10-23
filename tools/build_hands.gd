extends SceneTree
## Builds world/hands/hand_l.tscn and hand_r.tscn: the glTF glove unpacked into plain nodes (Skeleton3D with its 26 bones,
## the mesh) plus an AnimationPlayer with a few finger poses. Open the scenes in the editor to pose and animate by hand;
## re-running this tool overwrites those edits. Run: godot --headless --path . --script res://tools/build_hands.gd

const MODELS := {"L": "res://assets/models/hand/Hand_Glove_low_L.gltf", "R": "res://assets/models/hand/Hand_Glove_low_R.gltf"}
const OUT := "res://world/hands/hand_%s.tscn"
const FINGERS := ["Index", "Middle", "Ring", "Little"]
const JOINTS := ["Proximal", "Intermediate", "Distal"]


## Curl in radians per joint; positive closes the finger. Missing fingers use `all`.
const POSES := {
	"idle": {"all": 0.45, "Thumb": 0.25},
	"open": {"all": 0.1, "Thumb": 0.0},
	"fist": {"all": 1.25, "Thumb": 0.7},
	"point": {"all": 1.25, "Index": 0.0, "Thumb": 0.7},
}

func _initialize() -> void:
	await process_frame
	for side in MODELS:
		_build(side)
	quit()

func _build(side: String) -> void:
	var root := Node3D.new()
	root.name = "Hand" + ("Left" if side == "L" else "Right")
	var model: Node3D = load(MODELS[side]).instantiate()
	model.name = "Model"
	model.scene_file_path = ""
	root.add_child(model)
	model.owner = root
	_own(model, root)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var player := AnimationPlayer.new()
	player.name = "Anim"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	for pose in POSES:
		library.add_animation(pose, _pose_animation(root, skeleton, side, POSES[pose], pose == "idle"))
	library.add_animation("tap", _tap_animation(root, skeleton, side))
	player.add_animation_library("", library)
	player.playback_default_blend_time = 0.15
	player.autoplay = "idle"
	var packed := PackedScene.new()
	packed.pack(root)
	print("saved ", OUT % side.to_lower(), " ", ResourceSaver.save(packed, OUT % side.to_lower()))
	root.free()

func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)

func _curl_of(pose: Dictionary, finger: String) -> float:
	return pose.get(finger, pose["all"])

## The local rotations of one finger's joints for `curl` radians per joint. Every joint bends about the same axis of
## the hand (model-space Y, across the palm), so splayed fingers such as the little one still close toward the palm;
## bending about each bone's own X, which carries the rest roll, twisted them. The thumb has no such axis and bends
## about its bone's X. Positive curl closes.
func _chain(skeleton: Skeleton3D, side: String, finger: String, curl: float) -> Array:
	var out: Array = []
	var meta := skeleton.find_bone("%s_Metacarpal_%s" % [finger, side])
	var parent_rotation := Quaternion.IDENTITY
	if meta >= 0:
		parent_rotation = skeleton.get_bone_global_rest(meta).basis.get_rotation_quaternion()
	var axis_in_skeleton: Vector3 = _model_transform(skeleton).basis.inverse() * Vector3.UP
	for joint in JOINTS:
		var index := skeleton.find_bone("%s_%s_%s" % [finger, joint, side])
		if index < 0:
			out.append(null)
			continue
		var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		var local: Quaternion
		if finger == "Thumb":
			local = rest * Quaternion(Vector3.RIGHT, -curl)
		else:
			var axis := parent_rotation.inverse() * axis_in_skeleton
			# The right hand is the mirror image, so its palm is on the other side of the axis.
			local = Quaternion(axis.normalized(), (-curl if side == "L" else curl)) * rest
		out.append(local)
		parent_rotation = parent_rotation * local
	return out

## The skeleton's transform inside the model (the scene is not in a tree while it is built).
func _model_transform(skeleton: Skeleton3D) -> Transform3D:
	var t := skeleton.transform
	var node := skeleton.get_parent()
	while node != null and node.name != "Model":
		t = (node as Node3D).transform * t
		node = node.get_parent()
	return t

## One rotation track per finger joint.
func _pose_animation(root: Node, skeleton: Skeleton3D, side: String, pose: Dictionary, breathe: bool) -> Animation:
	var anim := Animation.new()
	anim.length = 1.2 if breathe else 0.3
	anim.loop_mode = Animation.LOOP_LINEAR if breathe else Animation.LOOP_NONE
	for finger in FINGERS + ["Thumb"]:
		var curl := _curl_of(pose, finger)
		var keys: Array = [[0.0, _chain(skeleton, side, finger, curl)]]
		if breathe:
			keys = [[0.0, _chain(skeleton, side, finger, curl - 0.05)], [0.6, _chain(skeleton, side, finger, curl + 0.05)], [1.2, _chain(skeleton, side, finger, curl - 0.05)]]
		for j in JOINTS.size():
			var bone := "%s_%s_%s" % [finger, JOINTS[j], side]
			if skeleton.find_bone(bone) < 0:
				continue
			var track := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(track, NodePath("%s:%s" % [root.get_path_to(skeleton), bone]))
			for key in keys:
				anim.rotation_track_insert_key(track, key[0], key[1][j])
	return anim

## The index finger pointing, then pressing down and back up: a tap.
func _tap_animation(root: Node, skeleton: Skeleton3D, side: String) -> Animation:
	var anim := _pose_animation(root, skeleton, side, POSES["point"], false)
	anim.length = 0.3
	var straight := _chain(skeleton, side, "Index", 0.0)
	var pressed := _chain(skeleton, side, "Index", 0.5)
	for j in JOINTS.size():
		var bone := "Index_%s_%s" % [JOINTS[j], side]
		var track := anim.find_track(NodePath("%s:%s" % [root.get_path_to(skeleton), bone]), Animation.TYPE_ROTATION_3D)
		for k in range(anim.track_get_key_count(track) - 1, -1, -1):
			anim.track_remove_key(track, k)
		anim.rotation_track_insert_key(track, 0.0, straight[j])
		anim.rotation_track_insert_key(track, 0.12, pressed[j])
		anim.rotation_track_insert_key(track, 0.3, straight[j])
	return anim
