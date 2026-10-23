extends Node3D
## The croupier: a hooded skeleton behind the table. Idles, deals, and reacts to the hand.

const MODEL := "res://assets/models/dealer/Skeleton_Rogue.glb"
const IDLE := &"Idle_B"
const SCALE := 1.12

var _animations: AnimationPlayer

func _ready() -> void:
	var model: Node3D = load(MODEL).instantiate()
	add_child(model)
	scale = Vector3.ONE * SCALE
	_animations = model.find_children("*", "AnimationPlayer", true, false)[0]
	_animations.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	_animations.animation_finished.connect(_on_finished)
	_animations.play(IDLE)

## One-shot gesture, then back to idle. `anim` is a KayKit animation name.
func gesture(anim: StringName) -> void:
	if _animations == null or not _animations.has_animation(anim):
		return
	_animations.play(anim, 0.12)

func react(kind: StringName) -> void:
	match kind:
		&"deal": gesture(&"Use_Item")
		&"player_wins": gesture(&"Hit_B")
		&"blackjack": gesture(&"Hit_A")
		&"player_loses": gesture(&"Cheer")
		&"player_bust": gesture(&"Taunt")
		&"payment": gesture(&"Spellcast_Raise")
		&"death": gesture(&"Taunt_Longer")
		&"peek": gesture(&"Hit_A")
		&"trick": gesture(&"Interact")

func _on_finished(anim: StringName) -> void:
	if anim != IDLE:
		_animations.play(IDLE, 0.2)
