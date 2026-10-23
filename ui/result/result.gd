extends Control
## Shown once a run ends: the record, the numbers and every artifact that just unlocked.

const Stat := preload("res://core/stat.gd")
const RunState := preload("res://core/run_state.gd")

@onready var title_label: Label = %TitleLabel
@onready var payments_label: Label = %PaymentsLabel
@onready var peak_label: Label = %PeakLabel
@onready var hands_label: Label = %HandsLabel
@onready var record_label: Label = %RecordLabel
@onready var unlocks_box: HBoxContainer = %UnlocksBox
@onready var unlocks_title: Label = %UnlocksTitle
@onready var again_button: Button = %AgainButton
@onready var menu_button: Button = %MenuButton

func _ready() -> void:
	var run = Game.last_run
	if run != null:
		var debt := Game.last_reason == RunState.DEATH_DEBT
		title_label.text = tr("RESULT_DEBT") if debt else tr("RESULT_BROKE")
		payments_label.text = "%s: %d" % [tr("RESULT_PAYMENTS"), run.payments_paid]
		peak_label.text = "%s: %d" % [tr("RESULT_PEAK"), run.peak_chips]
		hands_label.text = "%s: %d" % [tr("RESULT_HANDS"), run.hands_played]
		var best := Profile.stat(Stat.BEST_PAYMENTS)
		record_label.text = tr("RESULT_NEW_RECORD") if run.payments_paid > 0 and run.payments_paid >= best else ""
	var fresh := Profile.take_fresh_unlocks()
	unlocks_title.visible = not fresh.is_empty()
	for a in fresh:
		var icon := TextureRect.new()
		icon.texture = a.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.tooltip_text = a.title()
		unlocks_box.add_child(icon)
		var caption := Label.new()
		caption.text = a.title()
		unlocks_box.add_child(caption)
	again_button.pressed.connect(func() -> void: Game.goto(Game.SCENE_LOBBY))
	menu_button.pressed.connect(func() -> void: Game.goto(Game.SCENE_MENU))
	Audio.sfx(&"game/lose_sting")
