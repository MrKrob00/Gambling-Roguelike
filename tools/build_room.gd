extends SceneTree
## Builds res://world/casino_room.tscn: an abandoned underground casino. A black glossy floor, one lamp
## over the table, a red rim light on the dealer, dust in the light cone. Three lights, one shadow.
## Only primitives, no model packs. The scene stays a normal editable .tscn; re-running this tool
## overwrites hand edits, so change the layout here.
## Run: godot --headless --path <copy> --script res://tools/build_room.gd

const TOP := 1.03

var root_node: Node3D

func _own(n: Node, parent: Node = null) -> Node:
	(parent if parent != null else root_node).add_child(n)
	n.owner = root_node
	return n

func _material(color: Color, rough: float = 0.8, metal: float = 0.0, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func _box(node_name: String, size: Vector3, pos: Vector3, mat: Material, yaw_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	_own(mi)
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	return mi

func _omni(node_name: String, pos: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = node_name
	_own(l)
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	return l

func _initialize() -> void:
	root_node = Node3D.new()
	root_node.name = "CasinoRoom"

	# Glossy black floor; everything beyond it is lost in the fog. Nothing the player cannot see is built:
	# every extra light and mesh costs a phone.
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(22, 22)
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = _material(Color(0.02, 0.02, 0.03), 0.28, 0.15)
	_own(floor_mi)

	# The table: a dark body, a padded rail, felt on top. The felt surface is at TOP.
	var leather := _material(Color(0.03, 0.025, 0.03), 0.45, 0.1)
	_box("TableBody", Vector3(3.4, 0.95, 2.1), Vector3(0, 0.475, 0), _material(Color(0.04, 0.03, 0.035), 0.7))
	_box("TableSlab", Vector3(4.2, 0.1, 2.7), Vector3(0, TOP - 0.06, 0), leather)
	_box("RailLeft", Vector3(0.16, 0.07, 2.7), Vector3(-2.02, TOP + 0.005, 0), leather)
	_box("RailRight", Vector3(0.16, 0.07, 2.7), Vector3(2.02, TOP + 0.005, 0), leather)
	_box("RailFar", Vector3(4.2, 0.07, 0.16), Vector3(0, TOP + 0.005, -1.27), leather)
	_box("RailNear", Vector3(4.2, 0.07, 0.16), Vector3(0, TOP + 0.005, 1.27), leather)
	var felt := MeshInstance3D.new()
	felt.name = "Felt"
	var felt_mesh := PlaneMesh.new()
	felt_mesh.size = Vector2(3.88, 2.38)
	felt.mesh = felt_mesh
	felt.material_override = _material(Color(0.03, 0.1, 0.07), 1.0)
	_own(felt)
	felt.position = Vector3(0.0, TOP, 0.0)

	# The one lamp: a black shade with a lit underside, hung on a cable.
	var shade := MeshInstance3D.new()
	shade.name = "LampShade"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 0.8
	cone.height = 0.38
	cone.radial_segments = 24
	cone.rings = 1
	shade.mesh = cone
	shade.material_override = _material(Color(0.02, 0.02, 0.025), 0.4, 0.6)
	_own(shade)
	shade.position = Vector3(0.0, 3.15, 0.1)
	var bulb := MeshInstance3D.new()
	bulb.name = "LampBulb"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	bulb.mesh = disc
	bulb.material_override = _material(Color(1, 0.9, 0.7), 0.5, 0.0, Color(1.0, 0.85, 0.6), 3.0)
	_own(bulb)
	bulb.position = Vector3(0.0, 2.99, 0.1)
	var cable := MeshInstance3D.new()
	cable.name = "LampCable"
	var wire := CylinderMesh.new()
	wire.top_radius = 0.012
	wire.bottom_radius = 0.012
	wire.height = 4.0
	wire.radial_segments = 6
	wire.rings = 1
	cable.mesh = wire
	cable.material_override = _material(Color(0.02, 0.02, 0.02))
	_own(cable)
	cable.position = Vector3(0.0, 5.3, 0.1)
	var lamp := SpotLight3D.new()
	lamp.name = "TableLamp"
	_own(lamp)
	lamp.position = Vector3(0.0, 3.0, 0.1)
	lamp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 10.0
	lamp.spot_range = 7.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.7
	lamp.shadow_enabled = true

	# Behind the dealer: a cold red rim light that outlines the hood, and a thin cold fill from the front.
	_omni("DealerRim", Vector3(0.0, 2.5, -3.6), Color(1.0, 0.08, 0.14), 2.4, 5.0)
	_omni("ColdFill", Vector3(-2.5, 2.2, 3.0), Color(0.45, 0.6, 1.0), 0.7, 10.0)

	# Dust floating in the lamp's cone.
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	_own(dust)
	dust.position = Vector3(0.0, 2.0, 0.0)
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.2, 1.2, 1.2)
	dust.direction = Vector3(0.1, 0.2, 0.0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.05
	dust.gravity = Vector3.ZERO
	var mote := QuadMesh.new()
	mote.size = Vector2(0.007, 0.007)
	dust.mesh = mote
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.albedo_color = Color(1.0, 0.9, 0.75, 0.55)
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust.material_override = mote_mat

	# Atmosphere: near black, a thick cold fog, desaturated.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.008, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.25, 0.38)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.015, 0.02, 0.035)
	env.fog_density = 0.055
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_contrast = 1.15
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_own(world_env)

	var packed := PackedScene.new()
	print("pack: ", error_string(packed.pack(root_node)))
	print("save: ", error_string(ResourceSaver.save(packed, "res://world/casino_room.tscn")))
	quit()
