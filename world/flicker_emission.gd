extends MeshInstance3D
## A dying neon or screen: the emission strength stutters now and then.

@export var base_energy: float = 1.2
@export var drop_chance: float = 0.015

var _material: StandardMaterial3D
var _off_time: float = 0.0

func _ready() -> void:
	_material = material_override as StandardMaterial3D

func _process(delta: float) -> void:
	if _material == null:
		return
	if _off_time > 0.0:
		_off_time -= delta
		_material.emission_energy_multiplier = base_energy * 0.08
		return
	_material.emission_energy_multiplier = base_energy * (0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.004 + get_instance_id() % 97))
	if randf() < drop_chance * delta * 60.0 * 0.1:
		_off_time = randf_range(0.05, 0.35)
