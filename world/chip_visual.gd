extends RefCounted
## One casino chip: a short coloured cylinder with the printed face as a disc on top.

const TEXTURES := {
	1: preload("res://assets/art/casino/chip_icons/chip_1.png"),
	5: preload("res://assets/art/casino/chip_icons/chip_5.png"),
	10: preload("res://assets/art/casino/chip_icons/chip_10_128.png"),
	25: preload("res://assets/art/casino/chip_icons/chip_25_128.png"),
	100: preload("res://assets/art/casino/chip_icons/chip_100_128.png"),
	500: preload("res://assets/art/casino/chip_icons/chip_500_128.png"),
}
const SIDE_COLORS := {
	1: Color(0.6, 0.72, 0.78), 5: Color(0.6, 0.1, 0.1), 10: Color(0.1, 0.28, 0.62),
	25: Color(0.08, 0.45, 0.25), 100: Color(0.8, 0.6, 0.1), 500: Color(0.28, 0.2, 0.5),
}
const DENOMINATIONS: Array[int] = [500, 100, 25, 10, 5, 1]
const RADIUS := 0.1
const HEIGHT := 0.026

static var _cylinder: CylinderMesh
static var _disc: PlaneMesh
static var _side_materials: Dictionary = {}
static var _top_materials: Dictionary = {}

static func make(denomination: int) -> Node3D:
	if _cylinder == null:
		_cylinder = CylinderMesh.new()
		_cylinder.top_radius = RADIUS
		_cylinder.bottom_radius = RADIUS
		_cylinder.height = HEIGHT
		_cylinder.radial_segments = 20
		_cylinder.rings = 1
		_disc = PlaneMesh.new()
		_disc.size = Vector2(RADIUS * 1.96, RADIUS * 1.96)
	if not _side_materials.has(denomination):
		var side := StandardMaterial3D.new()
		side.albedo_color = SIDE_COLORS[denomination]
		side.roughness = 0.7
		_side_materials[denomination] = side
		var top := StandardMaterial3D.new()
		top.albedo_texture = TEXTURES[denomination]
		top.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		top.roughness = 0.8
		top.emission_enabled = true
		top.emission_texture = TEXTURES[denomination]
		top.emission_energy_multiplier = 0.25
		_top_materials[denomination] = top
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _cylinder
	body.material_override = _side_materials[denomination]
	body.position.y = HEIGHT / 2.0
	root.add_child(body)
	var face := MeshInstance3D.new()
	face.mesh = _disc
	face.material_override = _top_materials[denomination]
	face.position.y = HEIGHT + 0.0006
	root.add_child(face)
	return root

## Greedy split of an amount into chips, biggest first. Returns {denomination: count}.
static func split(amount: int) -> Dictionary:
	var out := {}
	var rest := amount
	for d in DENOMINATIONS:
		var n := rest / d
		if n > 0:
			out[d] = n
			rest -= n * d
	return out
