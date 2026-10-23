extends "res://world/pickable_3d.gd"
## A fixed pile of one chip value. Tapping it adds that value to the bet.

const ChipVisual := preload("res://world/chip_visual.gd")

var denomination: int = 10
var _chips: Node3D

func setup(value: int) -> void:
	denomination = value
	_chips = ChipVisual.make_column(value, 5)
	add_child(_chips)
	add_box_shape(Vector3(0.34, 0.12, 0.34), Vector3(0, 0.05, 0))
	make_ring(0.125)

func _refresh_visual() -> void:
	if _chips == null:
		return
	var tween := new_tween()
	tween.tween_property(_chips, "position:y", 0.04 if (hovered and enabled) else 0.0, 0.08)
	_chips.scale = Vector3.ONE if enabled else Vector3(0.92, 0.8, 0.92)
