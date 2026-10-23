extends Node3D
## The debt made flesh: two collectors stand at the player's shoulders, the same faceless man in a black suit twice (a CC0
## base mesh, matte black, arms hung at the sides, breathing). The nearer the payment, the closer they lean in
## (`set_urgency`, 0..1).

const MODEL: PackedScene = preload("res://assets/models/enforcers/male_base_mesh.glb")
const SUIT := Color(0.09, 0.09, 0.12)
const FAR_X := 2.45
const NEAR_X := 2.0
## They turn toward the player, a little.
const TURN := 0.55
## The model is a T-pose: this lowers the arms to the sides.
const ARM_DROP := 1.45
const BREATH := 0.012

var _bodies: Array = []
var _chests: Array = []
var _time: float = 0.0

func _ready() -> void:
	var suit := StandardMaterial3D.new()
	suit.albedo_color = SUIT
	suit.roughness = 0.55
	suit.emission_enabled = true
	suit.emission = Color(0.11, 0.11, 0.15)
	suit.rim_enabled = true
	suit.rim = 0.9
	suit.rim_tint = 0.2
	for i in 2:
		var side: int = -1 if i == 0 else 1
		var body := Node3D.new()
		body.position = Vector3(side * FAR_X, 0.0, 0.0)
		body.rotation.y = -side * TURN
		add_child(body)
		var model: Node3D = MODEL.instantiate()
		# The mesh faces +x: turn it to face the player.
		model.rotation_degrees.y = 90.0
		body.add_child(model)
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
		# The mesh origin is its centre: stand the feet on the floor.
		model.position.y = -mesh.get_aabb().position.y
		mesh.material_override = suit
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		for arm_side in ["L", "R"]:
			var bone := skeleton.find_bone("upper_arm." + arm_side)
			var dir := 1.0 if arm_side == "L" else -1.0
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * Quaternion(Vector3.UP, ARM_DROP * dir))
		_bodies.append([body, side])
		_chests.append([skeleton, skeleton.find_bone("spine.003"), randf() * TAU])

func _process(delta: float) -> void:
	_time += delta
	for c in _chests:
		var skeleton: Skeleton3D = c[0]
		skeleton.set_bone_pose_scale(c[1], Vector3(1.0 + BREATH * sin(_time * 1.6 + c[2]), 1.0, 1.0 + BREATH * sin(_time * 1.6 + c[2])))

func set_urgency(urgency: float) -> void:
	for pair in _bodies:
		var tween := create_tween()
		tween.tween_property(pair[0], "position:x", pair[1] * lerpf(FAR_X, NEAR_X, urgency), 0.8).set_trans(Tween.TRANS_SINE)
