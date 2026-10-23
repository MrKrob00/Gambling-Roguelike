extends StaticBody3D
## Anything the player can tap or click in the 3D room. Pickables live on physics layer 2, so the view's
## ray only ever sees them. Every pickable answers the pointer visibly: a ring and a glow on hover, a
## squash and a click when pressed, a shake and a dull tick when the action is not available right now
## (a touch screen has no hover, so the press feedback has to carry the message).

signal activated

const PICK_LAYER_BIT := 2
const RING_COLOR := Color(0.96, 0.63, 0.23)

var enabled: bool = true
var hovered: bool = false
var _tween: Tween
var _ring: MeshInstance3D

func _init() -> void:
	collision_layer = PICK_LAYER_BIT
	collision_mask = 0

func add_box_shape(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	add_child(shape)

## A thin gold ring on the table under the object; shown while the pointer is on it.
func make_ring(radius: float, height: float = 0.012, color: Color = RING_COLOR) -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.018
	torus.rings = 28
	torus.ring_segments = 6
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_ring.material_override = mat
	_ring.scale = Vector3(1.0, 0.2, 1.0)
	_ring.position = Vector3(0.0, height, 0.0)
	_ring.visible = false
	add_child(_ring)

## One tween at a time: a new animation replaces the one still running, so a late callback of an old
## hide can never undo a newer show.
func new_tween() -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween

func set_enabled(value: bool) -> void:
	enabled = value
	_refresh_visual()

## Used by the modes that pick a token (replace, discard): a red ring means "this one will go".
func show_ring(on: bool, color: Color = RING_COLOR) -> void:
	if _ring != null:
		(_ring.material_override as StandardMaterial3D).albedo_color = color
		_ring.visible = on or hovered

func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	if _ring != null:
		_ring.visible = value
	_refresh_visual()

func activate() -> void:
	if enabled:
		Audio.sfx(&"ui/ui_click")
		_press_feedback()
		activated.emit()
	else:
		Audio.sfx(&"ui/ui_error", 1.0, -9.0)
		_deny_feedback()

func _press_feedback() -> void:
	var rest := scale
	var tween := create_tween()
	tween.tween_property(self, "scale", rest * 0.88, 0.05)
	tween.tween_property(self, "scale", rest, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _deny_feedback() -> void:
	var rest := position
	var tween := create_tween()
	for i in 3:
		tween.tween_property(self, "position:x", rest.x + 0.02, 0.035)
		tween.tween_property(self, "position:x", rest.x - 0.02, 0.035)
	tween.tween_property(self, "position:x", rest.x, 0.035)

func _refresh_visual() -> void:
	pass
