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
	amount = value
	for c in get_children():
		c.queue_free()
	var parts := ChipVisual.split(value)
	var denoms := parts.keys()
	var x0 := -(denoms.size() - 1) * COLUMN_GAP / 2.0
	for i in denoms.size():
		var d: int = denoms[i]
		var column := ChipVisual.make_column(d, mini(parts[d], MAX_SHOWN))
		add_child(column)
		column.position = Vector3(x0 + i * COLUMN_GAP, 0.0, 0.0)
		column.rotation.y = randf() * TAU
		if animate and grew:
			column.position.y = DROP_HEIGHT
			var tween := create_tween()
			tween.tween_property(column, "position:y", 0.0, DROP_TIME).set_delay(i * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

