extends Node3D
## The player's eyes at the table: a slow breath, a little parallax toward the pointer, and shake or a
## fov punch when something hits.

const REST_POSITION := Vector3(0.0, 2.8, 2.25)
const LOOK_TARGET := Vector3(0.0, 0.9, -0.25)
const PARALLAX_YAW := 0.05
const PARALLAX_PITCH := 0.03
const BASE_FOV := 58.0

var camera: Camera3D
var _look := Vector2.ZERO
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_total: float = 0.0
var _noise := FastNoiseLite.new()
var _base_basis: Basis

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.current = true
	add_child(camera)
	position = REST_POSITION
	look_at_from_position(REST_POSITION, LOOK_TARGET)
	_base_basis = basis
	_noise.frequency = 2.0

func shake(strength: float = 0.05, duration: float = 0.35) -> void:
	_shake_strength = strength
	_shake_time = duration
	_shake_total = duration

func punch_fov(delta_degrees: float, duration: float = 0.45) -> void:
	var tween := create_tween()
	tween.tween_property(camera, "fov", BASE_FOV + delta_degrees, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "fov", BASE_FOV, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	var pointer := viewport.get_mouse_position() / size - Vector2(0.5, 0.5)
	_look = _look.lerp(pointer.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), clampf(delta * 3.0, 0.0, 1.0))
	var shake_offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		var k := _shake_strength * (_shake_time / _shake_total)
		shake_offset = Vector3(_noise.get_noise_2d(t * 40.0, 0.0), _noise.get_noise_2d(t * 40.0, 50.0), 0.0) * k
	position = REST_POSITION + Vector3(0.0, sin(t * 0.9) * 0.012, sin(t * 0.55) * 0.01) + shake_offset
	basis = _base_basis * Basis.from_euler(Vector3(-_look.y * PARALLAX_PITCH * 2.0, -_look.x * PARALLAX_YAW * 2.0, 0.0))
