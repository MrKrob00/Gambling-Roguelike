extends "res://world/pickable_3d.gd"
## A fixed pile of one chip value. Tapping it adds that value to the bet.

const ChipVisual := preload("res://world/chip_visual.gd")

var denomination: int = 10
var _chips: Node3D

func setup(value: int) -> void:
	denomination = value
	_chips = Node3D.new()
	add_child(_chips)
	for k in 5:
		var chip := ChipVisual.make(value)
		chip.position.y = k * ChipVisual.HEIGHT
		chip.rotation.y = randf() * TAU
		_chips.add_child(chip)
	add_box_shape(Vector3(0.2, 0.2, 0.2), Vector3(0, 0.08, 0))

func _refresh_visual() -> void:
	if _chips == null:
		return
	var tween := new_tween()
	tween.tween_property(_chips, "position:y", 0.04 if (hovered and enabled) else 0.0, 0.08)
	_chips.visible = true
	for chip in _chips.get_children():
		chip.scale = Vector3.ONE if enabled else Vector3(0.9, 0.7, 0.9)
