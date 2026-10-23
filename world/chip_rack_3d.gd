extends Node3D
## The purse as chips lying on their side in the rack, like a croupier's: one stack per denomination, only
## showing how much the player holds. Nothing here is pressable. The bet is always the whole purse.

const ChipVisual := preload("res://world/chip_visual.gd")
const DENOMINATIONS: Array[int] = [500, 100, 25, 10, 5]
const SPACING := 0.34
const MAX_SHOWN := 9

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
	for i in DENOMINATIONS.size():
		if counts[i] <= 0:
			continue
		var column := ChipVisual.make_column(DENOMINATIONS[i], counts[i])
		# Lying on its side: the stack runs along +z and its top face looks at the player.
		column.rotation.x = PI / 2.0
		column.position = Vector3((i - (DENOMINATIONS.size() - 1) / 2.0) * SPACING, ChipVisual.RADIUS, -ChipVisual.HEIGHT * counts[i] / 2.0)
		add_child(column)
		_stacks.append(column)
