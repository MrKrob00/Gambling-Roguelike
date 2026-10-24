extends SceneTree
## Writes the glove mesh of both hands (uv, vertex, normal, index) to /tmp/hand_uv_<L|R>.json for
## tools/generate_gloves.py. Run: godot --headless --path . --script res://tools/dump_hand_uv.gd

func _init() -> void:
	for side in ["L", "R"]:
		var scene: Node = load("res://world/hands/hand_%s.tscn" % side.to_lower()).instantiate()
		root.add_child(scene)
		var mesh_instance: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
		var out := {"uv": [], "v": [], "n": [], "idx": []}
		for u in arrays[Mesh.ARRAY_TEX_UV]:
			out.uv.append([u.x, u.y])
		for v in arrays[Mesh.ARRAY_VERTEX]:
			out.v.append([v.x, v.y, v.z])
		for n in arrays[Mesh.ARRAY_NORMAL]:
			out.n.append([n.x, n.y, n.z])
		for i in arrays[Mesh.ARRAY_INDEX]:
			out.idx.append(i)
		var file := FileAccess.open("/tmp/hand_uv_%s.json" % side, FileAccess.WRITE)
		file.store_string(JSON.stringify(out))
		file.close()
	quit()
