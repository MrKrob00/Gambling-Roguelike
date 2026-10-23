extends Node3D
## The purse as chips standing on the rack, the way a casino stacks them: one column per denomination, the
## biggest on the left. 250 is two 100s on top of each other and a 50 beside them. Display only, nothing here is
## pressable: the stake is always the whole purse.

const ChipVisual := preload("res://world/chip_visual.gd")
const DENOMINATIONS: Array[int] = [500, 100, 50, 25, 10, 5]
const SPACING := 0.26
const MAX_SHOWN := 10

var _shown: Array = []
var _stacks: Array = []

## Shows `amount` chips. Rebuilds only when the breakdown changes.
func show_amount(amount: int) -> void:
	var counts: Array = []
	var rest := amount
	for d in DENOMINATIONS:
		counts.append(mini(rest / d, MAX_SHOWN))
		rest %= d
	if counts == _shown:
		return
	_shown = counts
	for s in _stacks:
		s.queue_free()
	_stacks.clear()
	var columns := counts.filter(func(c: int) -> bool: return c > 0).size()
	var slot := 0
	for i in DENOMINATIONS.size():
		if counts[i] <= 0:
			continue
		var column := ChipVisual.make_column(DENOMINATIONS[i], counts[i])
		column.position = Vector3((slot - (columns - 1) / 2.0) * SPACING, 0.0, 0.0)
		add_child(column)
		_stacks.append(column)
		slot += 1
