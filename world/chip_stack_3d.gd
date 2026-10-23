extends Node3D
## A pile of chips standing for an amount: one column per denomination. New chips drop in.

const ChipVisual := preload("res://world/chip_visual.gd")

const COLUMN_GAP := 0.2
const MAX_SHOWN := 9
const DROP_HEIGHT := 0.35
const DROP_TIME := 0.16

var amount: int = 0

func set_amount(value: int, animate: bool = true) -> void:
	var grew := value > amount
	var old_chips := _count(amount)
	amount = value
	for c in get_children():
		c.queue_free()
	var parts := ChipVisual.split(value)
	var denoms := parts.keys()
	var x0 := -(denoms.size() - 1) * COLUMN_GAP / 2.0
	var placed := 0
	for i in denoms.size():
		var d: int = denoms[i]
		var shown := mini(parts[d], MAX_SHOWN)
		for k in shown:
			var chip := ChipVisual.make(d)
			add_child(chip)
			var rest := Vector3(x0 + i * COLUMN_GAP, k * ChipVisual.HEIGHT, 0.0)
			chip.position = rest
			chip.rotation.y = randf() * TAU
			placed += 1
			if animate and grew and placed > old_chips:
				chip.position.y += DROP_HEIGHT
				var tween := create_tween()
				tween.tween_property(chip, "position:y", rest.y, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _count(value: int) -> int:
	var n := 0
	for d in ChipVisual.split(value):
		n += mini(ChipVisual.split(value)[d], MAX_SHOWN)
	return n
