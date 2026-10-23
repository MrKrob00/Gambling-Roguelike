extends ColorRect
## Full-screen vignette with a colour flash. Put it on a CanvasLayer above the 3D view.

const SHADER: Shader = preload("res://ui/common/vignette.gdshader")

var _material: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material

func set_darkness(value: float) -> void:
	_material.set_shader_parameter("darkness", value)

func flash_color(color: Color, strength: float = 1.0, duration: float = 0.5) -> void:
	_material.set_shader_parameter("flash_color", color)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _material.set_shader_parameter("flash", v), strength, 0.0, duration)
