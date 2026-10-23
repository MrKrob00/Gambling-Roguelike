extends Node3D
## How a finger is lost: four short scenes built from primitives, played over the player's raised right hand.
## `play(kind, tip, on_hit)` runs one and calls `on_hit` at the instant of impact (the view cuts the finger there).
## The scene asks the camera to shake and the screen to flash through signals, so it knows nothing about the view.
## Sequenced with timers, never by awaiting a tween.

signal camera_shake(strength: float, duration: float)
signal screen_flash(color: Color, strength: float, time: float)
signal impact

enum Kind { BITE, CLEAVER, BURST, PISTOL }

const REVOLVER: Mesh = preload("res://assets/models/revolver/revolver.obj")
const REVOLVER_TEXTURE: Texture2D = preload("res://assets/models/revolver/revolver_diffuse.png")
## The model is 9 units long; this makes it about 80 cm in the oversized room.
const REVOLVER_SCALE := 0.09
const CLEAVER: PackedScene = preload("res://assets/models/weapons/cleaver.glb")
const CLEAVER_TEXTURE: Texture2D = preload("res://assets/models/weapons/W003_texture.png")
## The blade and handle together, in metres in the oversized room.
const CLEAVER_LENGTH := 0.8
const TABLE_TOP := 1.03
const BLOOD := Color(0.55, 0.02, 0.04)
const STEEL := Color(0.72, 0.74, 0.8)

## The dealer, who leans over the table to bite.
var dealer: Node3D
## Scales the finger that is about to be lost (1.0 = normal); set by the view for each scene.
var swell: Callable = func(_amount: float) -> void: pass

func play(kind: int, tip: Vector3, on_hit: Callable) -> void:
	match kind:
		Kind.BITE: await _bite(tip, on_hit)
		Kind.CLEAVER: await _cleaver(tip, on_hit)
		Kind.BURST: await _burst_finger(tip, on_hit)
		Kind.PISTOL: await _pistol(tip, on_hit)

# ---------------------------------------------------------------- the four scenes

## The skeleton leans across the table and snaps its jaw shut on the finger.
func _bite(tip: Vector3, on_hit: Callable) -> void:
	if not is_instance_valid(dealer):
		on_hit.call()
		return
	var home := dealer.position
	var home_rotation := dealer.rotation
	dealer.gesture(&"Hit_A")
	var lunge := create_tween()
	lunge.tween_property(dealer, "position", Vector3(tip.x, home.y, tip.z - 0.55), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await _wait(0.2)
	Audio.sfx(&"trick/whoosh", 0.8)
	await _wait(0.15)
	_hit(tip, on_hit, &"game/bite_crunch", 0.07)
	await _wait(0.7)
	var back := create_tween()
	back.tween_property(dealer, "position", home, 0.8).set_trans(Tween.TRANS_SINE)
	await _wait(0.8)
	dealer.position = home
	dealer.rotation = home_rotation

## An enforcer's arm swings a cleaver down onto the finger.
func _cleaver(tip: Vector3, on_hit: Callable) -> void:
	var arm := Node3D.new()
	add_child(arm)
	# The pivot is the fist at the end of the handle. The cleaver model (CC0) has its handle end low on +y and its cutting
	# edge on -x: it is centred and scaled by its measured bounds, then turned a quarter so the blade lies along -x with
	# the edge down.
	var blade := Node3D.new()
	arm.add_child(blade)
	var model: Node3D = CLEAVER.instantiate()
	blade.add_child(model)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _cleaver_material()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds := _bounds(model, blade)
	model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var s := CLEAVER_LENGTH / bounds.size.y
	blade.scale = Vector3.ONE * s
	blade.rotation_degrees.z = 90.0
	var edge := bounds.size.x * 0.5 * s
	_box(arm, Vector3(0.12, 0.12, 0.12), Vector3.ZERO, _material(Color(0.04, 0.04, 0.05), 0.5))
	_box(arm, Vector3(1.4, 0.2, 0.2), Vector3(0.75, 0.0, 0.0), _material(Color(0.04, 0.04, 0.06), 0.8))
	var chop_at := tip + Vector3(CLEAVER_LENGTH * 0.5, edge, 0.0)
	arm.position = chop_at + Vector3(0.8, 1.0, 0.0)
	arm.rotation.z = -1.3
	var rise := create_tween()
	rise.tween_property(arm, "position", chop_at + Vector3(0.15, 0.55, 0.0), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(arm, "rotation:z", -0.6, 0.5)
	await _wait(0.9)
	Audio.sfx(&"trick/whoosh", 1.3)
	var swing := create_tween()
	swing.tween_property(arm, "position", chop_at, 0.1).set_ease(Tween.EASE_IN)
	swing.parallel().tween_property(arm, "rotation:z", 0.0, 0.1).set_ease(Tween.EASE_IN)
	await _wait(0.1)
	_hit(tip, on_hit, &"game/cleaver_chop", 0.09)
	await _wait(0.8)
	var out := create_tween()
	out.tween_property(arm, "position", chop_at + Vector3(0.9, 1.2, 0.0), 0.4)
	await _wait(0.4)
	arm.queue_free()

## The bounds of every mesh under `node`, in the space of `frame`.
func _bounds(node: Node3D, frame: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = frame.global_transform.affine_inverse() * (m.global_transform * m.get_aabb())
		box = b if first else box.merge(b)
		first = false
	return box

func _cleaver_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = CLEAVER_TEXTURE
	mat.roughness = 0.5
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission_texture = CLEAVER_TEXTURE
	mat.emission_energy_multiplier = 0.35
	return mat

## The finger itself swells, throbbing, until it bursts. No props: the hand does it (`swell` scales the finger).
func _burst_finger(tip: Vector3, on_hit: Callable) -> void:
	for i in 16:
		var amount := 1.0 + i * 0.07
		swell.call(amount)
		if i % 4 == 0:
			Audio.sfx(&"game/heartbeat", 1.0 + i * 0.04, -6.0)
		camera_shake.emit(0.004 * i, 0.12)
		await _wait(0.07)
	swell.call(1.0)
	_boom(tip)
	_hit(tip, on_hit, &"game/explosion", 0.0)
	await _wait(1.0)

## A revolver comes in from the side, the hammer clicks, and the finger is shot off.
func _pistol(tip: Vector3, on_hit: Callable) -> void:
	var gun := Node3D.new()
	add_child(gun)
	# The revolver model (CC0) points its barrel along -z and its grip down; turn it to point along -x, at the finger.
	var model := MeshInstance3D.new()
	model.mesh = REVOLVER
	model.material_override = _revolver_material()
	model.scale = Vector3.ONE * REVOLVER_SCALE
	model.rotation_degrees.y = 90.0
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(model)
	_box(gun, Vector3(0.16, 0.16, 0.16), Vector3(0.2, -0.17, 0.0), _material(Color(0.04, 0.04, 0.05), 0.5))
	_box(gun, Vector3(1.2, 0.22, 0.22), Vector3(0.9, -0.2, 0.0), _material(Color(0.04, 0.04, 0.06), 0.8))
	var muzzle := Vector3(-0.47, 0.03, 0.0)
	var aim := tip + Vector3(0.6, 0.0, 0.0)
	gun.position = aim + Vector3(1.4, 0.2, 0.0)
	var slide := create_tween()
	slide.tween_property(gun, "position", aim, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait(0.5)
	Audio.sfx(&"game/hammer_click")
	await _wait(0.75)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.4)
	flash.light_energy = 6.0
	flash.omni_range = 3.0
	flash.position = muzzle
	gun.add_child(flash)
	var glare := _sphere(gun, 0.1, muzzle + Vector3(-0.06, 0.0, 0.0), _material(Color(1.0, 0.9, 0.6), 1.0, 0.0, Color(1.0, 0.85, 0.5), 6.0))
	var recoil := create_tween()
	recoil.tween_property(gun, "rotation:z", 0.3, 0.05)
	recoil.tween_property(gun, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	_smoke(gun.global_position + muzzle)
	_hit(tip, on_hit, &"game/gunshot", 0.1)
	await _wait(0.08)
	glare.visible = false
	flash.queue_free()
	await _wait(0.8)
	var out := create_tween()
	out.tween_property(gun, "position", aim + Vector3(1.6, 0.4, 0.0), 0.4)
	await _wait(0.4)
	gun.queue_free()

func _revolver_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = REVOLVER_TEXTURE
	mat.roughness = 0.5
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission_texture = REVOLVER_TEXTURE
	mat.emission_energy_multiplier = 0.3
	return mat

# ---------------------------------------------------------------- shared effects

## The moment of impact: the finger goes, blood flies, the camera and the screen react.
func _hit(tip: Vector3, on_hit: Callable, sound: StringName, shake: float) -> void:
	on_hit.call()
	Audio.sfx(sound)
	Audio.sfx(&"game/blood_splat", randf_range(0.9, 1.1), -4.0)
	_blood(tip)
	camera_shake.emit(maxf(shake, 0.05) * 1.6, 0.45)
	screen_flash.emit(Color(0.8, 0.02, 0.05), 0.9, 0.9)
	impact.emit()

func _boom(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.2, 0.15)
	light.light_energy = 6.0
	light.omni_range = 3.0
	light.position = at
	add_child(light)
	var fade := create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.3)
	fade.tween_callback(light.queue_free)
	_burst(at, BLOOD, 70, 0.02, 3.4, Vector3(0.0, -7.0, 0.0), 0.9)
	_burst(at, Color(0.9, 0.85, 0.75), 18, 0.022, 3.0, Vector3(0.0, -8.0, 0.0), 0.8)
	_burst(at, Color(0.7, 0.1, 0.12), 24, 0.045, 1.6, Vector3(0.0, -3.0, 0.0), 0.7)
	screen_flash.emit(Color(1.0, 0.25, 0.2), 1.0, 0.5)
	camera_shake.emit(0.14, 0.6)

func _blood(at: Vector3) -> void:
	_burst(at, BLOOD, 34, 0.013, 2.4, Vector3(0.0, -7.0, 0.0), 0.9)
	# A puddle on the felt under the hand.
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.003
	disc.radial_segments = 14
	puddle.mesh = disc
	puddle.material_override = _material(BLOOD, 0.4)
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddle.position = Vector3(at.x, TABLE_TOP + 0.003, at.z)
	puddle.scale = Vector3.ONE * 0.01
	add_child(puddle)
	var grow := create_tween()
	grow.tween_interval(0.5)
	grow.tween_property(puddle, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_interval(2.5)
	grow.tween_property(puddle, "scale", Vector3.ONE * 0.01, 0.4)
	grow.tween_callback(puddle.queue_free)

func _smoke(at: Vector3) -> void:
	_burst(at, Color(0.55, 0.55, 0.58), 14, 0.04, 0.6, Vector3(0.0, 0.5, 0.0), 1.1)

## A one-shot cloud of small spheres. Freed by itself.
func _burst(at: Vector3, color: Color, amount: int, size: float, speed: float, gravity: Vector3, life: float) -> void:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = _material(color, 0.6, 0.0, color, 1.5)
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.position = at
	p.emitting = true
	add_child(p)
	var timer := get_tree().create_timer(life + 0.3)
	timer.timeout.connect(p.queue_free)

# ---------------------------------------------------------------- little builders

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _material(color: Color, rough: float, metal: float = 0.0, glow: Color = Color.BLACK, glow_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if glow_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = glow_energy
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	m.mesh = s
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m
