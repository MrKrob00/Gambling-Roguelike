extends OmniLight3D
## A candle or torch: energy wobbles with noise so the room never sits still.

@export var flicker_amount: float = 0.25
@export var flicker_speed: float = 1.6

var _base_energy: float = 1.0
var _noise := FastNoiseLite.new()
var _seed_offset: float = 0.0

func _ready() -> void:
	_base_energy = light_energy
	_noise.frequency = 1.0
	_seed_offset = randf() * 100.0

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * flicker_speed + _seed_offset
	light_energy = _base_energy * (1.0 + flicker_amount * _noise.get_noise_1d(t * 10.0))
