extends Node3D
## A playing card lying on the table. Rotation x = 0 shows the face, x = PI shows the back.

const SIZE := Vector2(0.44, 0.66)
const BACK_TEXTURE: Texture2D = preload("res://assets/art/cards/card_back_purple.png")
const FLIP_TIME := 0.3

static var _back_material: StandardMaterial3D

var card
var face_up: bool = true
var _front: MeshInstance3D
var _front_material: StandardMaterial3D

func _init() -> void:
	var plane := PlaneMesh.new()
	plane.size = SIZE
	_front = MeshInstance3D.new()
	_front.mesh = plane
	_front_material = StandardMaterial3D.new()
	_front_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_front_material.roughness = 0.9
	_front_material.emission_enabled = true
	_front_material.emission_energy_multiplier = 0.3
	_front.material_override = _front_material
	add_child(_front)
	if _back_material == null:
		_back_material = StandardMaterial3D.new()
		_back_material.albedo_texture = BACK_TEXTURE
		_back_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_back_material.roughness = 0.9
		_back_material.emission_enabled = true
		_back_material.emission_texture = BACK_TEXTURE
		_back_material.emission_energy_multiplier = 0.3
	var back_plane := PlaneMesh.new()
	back_plane.size = SIZE
	back_plane.flip_faces = true
	var back := MeshInstance3D.new()
	back.mesh = back_plane
	back.material_override = _back_material
	back.position.y = -0.002
	add_child(back)

func setup(c, face_texture: Texture2D, up: bool) -> void:
	card = c
	set_face_texture(face_texture)
	face_up = up
	rotation.x = 0.0 if up else PI

func set_face_texture(texture: Texture2D) -> void:
	_front_material.albedo_texture = texture
	_front_material.emission_texture = texture

func flip_to(up: bool, lift: bool = true) -> void:
	if up == face_up:
		return
	face_up = up
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation:x", 0.0 if up else PI, FLIP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if lift:
		var hop := create_tween()
		hop.tween_property(self, "position:y", position.y + 0.14, FLIP_TIME / 2.0)
		hop.tween_property(self, "position:y", position.y, FLIP_TIME / 2.0)
	await tween.finished

## Flies from where it is to `target` along an arc.
func fly_to(target: Vector3, duration: float = 0.38, arc: float = 0.25) -> void:
	var start := position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _arc_step(start, target, arc, t), 0.0, 1.0, duration)
	await tween.finished

func _arc_step(from: Vector3, to: Vector3, arc: float, t: float) -> void:
	position = from.lerp(to, t) + Vector3(0.0, sin(t * PI) * arc, 0.0)
