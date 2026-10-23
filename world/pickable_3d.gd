extends StaticBody3D
## Anything the player can tap or click in the 3D room. Pickables live on physics layer 2, so the view's
## ray only ever sees them. Subclasses override `_refresh_visual`.

signal activated

const PICK_LAYER_BIT := 2

var enabled: bool = true
var hovered: bool = false
var _tween: Tween

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

func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	_refresh_visual()

func activate() -> void:
	if enabled:
		activated.emit()

func _refresh_visual() -> void:
	pass
