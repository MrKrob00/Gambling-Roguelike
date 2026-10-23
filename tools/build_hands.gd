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

## One rotation track per finger joint, keyed with the bone's rest rotation bent by the curl.
func _pose_animation(root: Node, skeleton: Skeleton3D, side: String, pose: Dictionary, breathe: bool) -> Animation:
	var anim := Animation.new()
	anim.length = 1.2 if breathe else 0.3
	anim.loop_mode = Animation.LOOP_LINEAR if breathe else Animation.LOOP_NONE
	for finger in FINGERS + ["Thumb"]:
		for joint in JOINTS:
			var bone := "%s_%s_%s" % [finger, joint, side]
			var index := skeleton.find_bone(bone)
			if index < 0:
				continue
			var track := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(track, NodePath("%s:%s" % [root.get_path_to(skeleton), bone]))
			var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
			var curl := _curl_of(pose, finger)
			if breathe:
				anim.rotation_track_insert_key(track, 0.0, rest * Quaternion(Vector3.RIGHT, -curl - 0.05))
				anim.rotation_track_insert_key(track, 0.6, rest * Quaternion(Vector3.RIGHT, -curl + 0.05))
				anim.rotation_track_insert_key(track, 1.2, rest * Quaternion(Vector3.RIGHT, -curl - 0.05))
			else:
				anim.rotation_track_insert_key(track, 0.0, rest * Quaternion(Vector3.RIGHT, -curl))
	return anim

## The index finger pointing, then pressing down and back up: a tap.
func _tap_animation(root: Node, skeleton: Skeleton3D, side: String) -> Animation:
	var anim := _pose_animation(root, skeleton, side, POSES["point"], false)
	anim.length = 0.3
	for joint in JOINTS:
		var bone := "Index_%s_%s" % [joint, side]
		var track := anim.find_track(NodePath("%s:%s" % [root.get_path_to(skeleton), bone]), Animation.TYPE_ROTATION_3D)
		var rest := skeleton.get_bone_rest(skeleton.find_bone(bone)).basis.get_rotation_quaternion()
		anim.rotation_track_insert_key(track, 0.0, rest)
		anim.rotation_track_insert_key(track, 0.12, rest * Quaternion(Vector3.RIGHT, -0.5))
		anim.rotation_track_insert_key(track, 0.3, rest)
	return anim
