extends SceneTree
## Renders a 3D scene from the player's seat and saves a PNG.
## SCENE=res://world/casino_room.tscn OUT=/tmp/x.png [CAM=0,2.1,2.65] [LOOK=0,1,-0.2]

func _vec(text: String, fallback: Vector3) -> Vector3:
	if text.is_empty():
		return fallback
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _initialize() -> void:
	await process_frame
	var scene: Node = load(OS.get_environment("SCENE")).instantiate()
	root.add_child(scene)
	if scene.get_node_or_null("Camera3D") == null:
		var cam := Camera3D.new()
		cam.fov = 62.0
		root.add_child(cam)
		cam.look_at_from_position(_vec(OS.get_environment("CAM"), Vector3(0, 2.95, 2.5)), _vec(OS.get_environment("LOOK"), Vector3(0, 0.9, -0.25)))
		cam.current = true
	var dealer: Node3D = load("res://assets/models/dealer/Skeleton_Rogue.glb").instantiate()
	root.add_child(dealer)
	dealer.position = Vector3(0, 0, -3.1)
	dealer.scale = Vector3.ONE * 1.35
	var ap: AnimationPlayer = dealer.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("Idle_B")
	await create_timer(1.2).timeout
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	print("saved ", OS.get_environment("OUT"))
	quit()
