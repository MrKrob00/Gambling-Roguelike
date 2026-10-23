extends Node3D
## The debt made flesh: two collectors stand at the player's shoulders. The nearer the payment, the closer
## they lean in (`set_urgency`, 0..1). Primitives only, no shadows: two bodies, two heads.

const SUIT := Color(0.035, 0.035, 0.05)
const SKIN := Color(0.55, 0.45, 0.4)
const TIE := Color(0.5, 0.04, 0.06)
const FAR_X := 2.1
const NEAR_X := 1.75

var _bodies: Array = []

func _ready() -> void:
	var suit := StandardMaterial3D.new()
	suit.albedo_color = SUIT
	suit.roughness = 0.9
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	skin.roughness = 0.8
	var tie := StandardMaterial3D.new()
	tie.albedo_color = TIE
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 1.5
	torso.radial_segments = 10
	torso.rings = 2
	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.32
	head.radial_segments = 10
	head.rings = 5
	var knot := BoxMesh.new()
	knot.size = Vector3(0.05, 0.3, 0.02)
	for side in [-1, 1]:
		var body := Node3D.new()
		body.position = Vector3(side * FAR_X, 0.0, 0.0)
		body.rotation.y = -side * 0.5
		add_child(body)
		_part(body, torso, suit, Vector3(0.0, 0.75, 0.0))
		_part(body, head, skin, Vector3(0.0, 1.65, 0.0))
		_part(body, knot, tie, Vector3(0.0, 1.05, -0.3))
		_bodies.append([body, side])

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func set_urgency(urgency: float) -> void:
	for pair in _bodies:
		var tween := create_tween()
		tween.tween_property(pair[0], "position:x", pair[1] * lerpf(FAR_X, NEAR_X, urgency), 0.8).set_trans(Tween.TRANS_SINE)
