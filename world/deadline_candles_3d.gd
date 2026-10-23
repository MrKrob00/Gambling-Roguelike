extends Node3D
## The deadline made physical: one candle per hand left before the collectors come. Each resolved hand
## snuffs one. The amount due floats above them. The closer the end, the redder and wilder the flames.

const COUNT := 5
const SPACING := 0.2
const WAX := Color(0.85, 0.82, 0.72)
const FONT: Font = preload("res://ui/fonts/title_font.tres")
const CALM := Color(1.0, 0.65, 0.25)
const URGENT := Color(1.0, 0.18, 0.12)

var lit: int = COUNT
var urgency: float = 0.0
var _candles: Array = []
var _flames: Array = []
var _flame_materials: Array = []
var _label: Label3D

func _ready() -> void:
	var wax_mat := StandardMaterial3D.new()
	wax_mat.albedo_color = WAX
	wax_mat.roughness = 0.9
	var wax_mesh := CylinderMesh.new()
	wax_mesh.top_radius = 0.028
	wax_mesh.bottom_radius = 0.034
	wax_mesh.height = 0.18
	wax_mesh.radial_segments = 10
	wax_mesh.rings = 1
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.028
	flame_mesh.height = 0.075
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	for i in COUNT:
		var candle := Node3D.new()
		candle.position = Vector3((i - (COUNT - 1) / 2.0) * SPACING, 0.0, 0.0)
		add_child(candle)
		var body := MeshInstance3D.new()
		body.mesh = wax_mesh
		body.material_override = wax_mat
		body.position.y = 0.09
		candle.add_child(body)
		var flame := MeshInstance3D.new()
		flame.mesh = flame_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = CALM
		mat.emission_enabled = true
		mat.emission = CALM
		mat.emission_energy_multiplier = 2.5
		flame.material_override = mat
		flame.position.y = 0.22
		candle.add_child(flame)
		_candles.append(candle)
		_flames.append(flame)
		_flame_materials.append(mat)
	_label = Label3D.new()
	_label.font = FONT
	_label.font_size = 72
	_label.pixel_size = 0.0034
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(-0.95, 0.18, 0.0)
	_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_label)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var wild := 1.0 + urgency * 2.0
	for i in COUNT:
		var flame: MeshInstance3D = _flames[i]
		if not flame.visible:
			continue
		var wobble := 1.0 + 0.18 * wild * sin(t * (9.0 + i * 1.7) + i)
		flame.scale = Vector3(1.0, wobble, 1.0)

## `hands_left` candles stay lit (the rightmost go out first, so the row burns down toward the left).
func set_remaining(hands_left: int, amount: int, animate: bool = true) -> void:
	var target := clampi(hands_left, 0, COUNT)
	urgency = 1.0 - float(target - 1) / float(COUNT - 1) if target > 0 else 1.0
	var color := CALM.lerp(URGENT, urgency)
	for i in COUNT:
		var on := i < target
		var flame: MeshInstance3D = _flames[i]
		_flame_materials[i].albedo_color = color
		_flame_materials[i].emission = color
		if on != flame.visible:
			if not on and animate:
				_snuff(i)
			else:
				flame.visible = on
	lit = target
	_label.text = tr("TABLE_DEADLINE_AMOUNT") % amount
	_label.modulate = Color(0.85, 0.85, 0.95).lerp(URGENT, urgency)

func _snuff(index: int) -> void:
	Audio.sfx(&"game/candle_snuff", randf_range(0.9, 1.1))
	var flame: MeshInstance3D = _flames[index]
	var tween := create_tween()
	tween.tween_property(flame, "position:y", 0.34, 0.25)
	tween.parallel().tween_property(flame, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
	tween.tween_callback(func() -> void:
		flame.visible = false
		flame.position.y = 0.22
		flame.scale = Vector3.ONE)

## After a payment the row is lit again, one candle at a time.
func relight(hands_left: int) -> void:
	for i in COUNT:
		_flames[i].visible = false
	for i in clampi(hands_left, 0, COUNT):
		_flames[i].visible = true
		_flames[i].scale = Vector3.ONE * 0.1
		var tween := create_tween()
		tween.tween_property(_flames[i], "scale", Vector3.ONE, 0.2).set_delay(i * 0.12)
