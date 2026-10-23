extends Node3D
## The debt made flesh: two collectors stand at the player's shoulders. The nearer the payment, the closer they
## lean in (`set_urgency`, 0..1). KayKit characters (CC0) with their weapons put away, idling with folded arms.

const MODELS := ["res://assets/models/enforcers/Barbarian.glb", "res://assets/models/enforcers/Rogue_Hooded.glb"]
const IDLE := &"Unarmed_Idle"
const SCALE := 1.0
const FAR_X := 2.7
const NEAR_X := 2.2
## They turn toward the player, a little.
const TURN := 0.6

var _bodies: Array = []

func _ready() -> void:
	for i in 2:
		var side: int = -1 if i == 0 else 1
		var body := Node3D.new()
		body.position = Vector3(side * FAR_X, 0.0, 0.0)
		body.rotation.y = -side * TURN
		add_child(body)
		var model: Node3D = load(MODELS[i]).instantiate()
		model.scale = Vector3.ONE * SCALE
		body.add_child(model)
		for slot in ["handslot_l", "handslot_r"]:
			var attachment := model.find_child(slot, true, false)
			if attachment != null:
				for c in attachment.get_children():
					c.visible = false
		var animations: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		animations.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
		animations.play(IDLE)
		animations.seek(randf() * 2.0)
		_bodies.append([body, side])

func set_urgency(urgency: float) -> void:
	for pair in _bodies:
		var tween := create_tween()
		tween.tween_property(pair[0], "position:x", pair[1] * lerpf(FAR_X, NEAR_X, urgency), 0.8).set_trans(Tween.TRANS_SINE)
