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
## The gun is held at this point of its own frame; the muzzle is this far ahead of the middle and `GUN_GAP` short of the finger.
const GUN_GRIP := Vector3(0.2, -0.17, 0.0)
const GUN_MUZZLE := 0.47
const GUN_GAP := 0.7
const TABLE_TOP := 1.03
## The felt, in the table's own x and z.
const FELT_X := 1.45
const FELT_Z_MIN := -0.85
const FELT_Z_MAX := 1.0
const MAX_STAINS := 80
## A splat grows to its full size in this many seconds.
const STAIN_GROW := 0.25
const SPLAT_VARIANTS := 4
const BLOOD := Color(0.55, 0.02, 0.04)
const STEEL := Color(0.72, 0.74, 0.8)

## The dealer, who leans over the table to bite.
var dealer: Node3D
## The collectors; one fires the gun.
var enforcers: Node3D
var _stain_list: Array = []
var _blood_mesh: MeshInstance3D
var _atlas_material: StandardMaterial3D

## Draws everything the scenes use once, tiny and in front of the camera, so the first lost finger does not stall on
## compiling shaders, generating the splat textures or adding a light. Call it a moment after the table opens.
func warm_up(camera: Camera3D) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = camera.global_position + (-camera.global_transform.basis.z) * 2.0
	holder.scale = Vector3.ONE * 0.02
	var cleaver: Node3D = CLEAVER.instantiate()
	for m in cleaver.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _cleaver_material()
	holder.add_child(cleaver)
	var revolver := MeshInstance3D.new()
	revolver.mesh = REVOLVER
	revolver.material_override = _revolver_material()
	holder.add_child(revolver)
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.material_override = _splat_material()
	holder.add_child(quad)
	_box(holder, Vector3.ONE, Vector3.ZERO, _material(BLOOD, 0.4))
	_sphere(holder, 0.5, Vector3.ZERO, _material(Color(1.0, 0.9, 0.6), 1.0, 0.0, Color(1.0, 0.85, 0.5), 6.0))
	var light := OmniLight3D.new()
	light.light_energy = 0.01
	holder.add_child(light)
	_burst(holder.global_position, BLOOD, 1, 0.01, 0.1, Vector3.ZERO, 0.3)
	await _wait(0.4)
	holder.queue_free()

func _ready() -> void:
	set_process(false)

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

## The finger bursts: no build-up, no props. The hand holds still, then blood and bone fly.
func _burst_finger(tip: Vector3, on_hit: Callable) -> void:
	await _wait(0.4)
	_boom(tip)
	_hit(tip, on_hit, &"game/explosion", 0.0)
	await _wait(1.0)

## A collector steps up beside the player, raises his arm with a revolver, the hammer clicks and the finger is shot off.
func _pistol(tip: Vector3, on_hit: Callable) -> void:
	var gun := Node3D.new()
	add_child(gun)
	# The revolver model (CC0) points its barrel along -z and its grip down; turn it to point along -x, the barrel
	# axis the collector's arm lines up with.
	var model := MeshInstance3D.new()
	model.mesh = REVOLVER
	model.material_override = _revolver_material()
	model.scale = Vector3.ONE * REVOLVER_SCALE
	model.rotation_degrees.y = 90.0
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(model)
	if not is_instance_valid(enforcers):
		gun.queue_free()
		on_hit.call()
		return
	var muzzle := Vector3(-GUN_MUZZLE, 0.03, 0.0)
	enforcers.begin_gun(tip, gun, GUN_GRIP, GUN_MUZZLE + GUN_GRIP.x, GUN_GAP)
	await _wait(1.0)
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
	recoil.tween_property(enforcers, "kick", 0.35, 0.05)
	recoil.tween_property(enforcers, "kick", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	_smoke(gun.global_transform * muzzle)
	_hit(tip, on_hit, &"game/gunshot", 0.1)
	await _wait(0.08)
	glare.visible = false
	flash.queue_free()
	await _wait(0.8)
	await enforcers.end_gun()
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
	_burst(at, BLOOD, 70, 0.02, 3.4, Vector3(0.0, -7.0, 0.0), 0.9)
	_burst(at, Color(0.9, 0.85, 0.75), 18, 0.022, 3.0, Vector3(0.0, -8.0, 0.0), 0.8)
	_burst(at, Color(0.7, 0.1, 0.12), 24, 0.045, 1.6, Vector3(0.0, -3.0, 0.0), 0.7)
	camera_shake.emit(0.14, 0.6)

func _blood(at: Vector3) -> void:
	_burst(at, BLOOD, 34, 0.013, 2.4, Vector3(0.0, -7.0, 0.0), 0.9)
	# One big splat under the hand, and drops thrown over the felt: they stay until the run ends.
	_stain(Vector2(at.x, at.z), randf_range(0.32, 0.45), 0.5)
	for i in randi_range(7, 11):
		var spot := Vector2(at.x, at.z) + Vector2.from_angle(randf() * TAU) * randf_range(0.15, 1.3)
		spot = Vector2(clampf(spot.x, -FELT_X, FELT_X), clampf(spot.y, FELT_Z_MIN, FELT_Z_MAX))
		_stain(spot, randf_range(0.06, 0.24), 0.55 + randf() * 0.4)

## A splat lying on the felt. Every stain of the run is one mesh (a quad each, one draw call in all); the oldest are
## dropped past `MAX_STAINS`. The mesh is rebuilt while a splat still grows.
func _stain(spot: Vector2, size: float, delay: float) -> void:
	_stain_list.append({"spot": spot, "size": size, "start": Time.get_ticks_msec() / 1000.0 + delay, "angle": randf() * TAU, "variant": randi() % SPLAT_VARIANTS})
	if _stain_list.size() > MAX_STAINS:
		_stain_list.pop_front()
	if _blood_mesh == null:
		_blood_mesh = MeshInstance3D.new()
		_blood_mesh.mesh = ArrayMesh.new()
		_blood_mesh.material_override = _splat_material()
		_blood_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_blood_mesh)
	set_process(true)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var growing := false
	for i in _stain_list.size():
		var stain: Dictionary = _stain_list[i]
		var t := clampf((now - stain.start) / STAIN_GROW, 0.0, 1.0)
		if t < 1.0:
			growing = true
		if t <= 0.0:
			continue
		var half: float = stain.size * 0.5 * (0.05 + 0.95 * (1.0 - (1.0 - t) * (1.0 - t)))
		var cell := Vector2(stain.variant % 2, stain.variant / 2) * 0.5
		var first := vertices.size()
		var spot: Vector2 = stain.spot
		for k in 4:
			var corner := Vector2(1.0 if k == 1 or k == 2 else 0.0, 1.0 if k >= 2 else 0.0)
			var local := (corner - Vector2(0.5, 0.5)) * 2.0 * half
			local = local.rotated(stain.angle)
			vertices.append(Vector3(spot.x + local.x, TABLE_TOP + 0.004 + i * 0.0002, spot.y + local.y))
			normals.append(Vector3.UP)
			uvs.append(cell + corner * 0.5)
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var mesh: ArrayMesh = _blood_mesh.mesh
	mesh.clear_surfaces()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not growing:
		set_process(false)

## The four splats side by side in one texture, so that all the stains share a material.
func _splat_material() -> StandardMaterial3D:
	if _atlas_material == null:
		var atlas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for i in SPLAT_VARIANTS:
			var piece: Image = _splat_texture(i).get_image()
			atlas.blit_rect(piece, Rect2i(0, 0, 128, 128), Vector2i((i % 2) * 128, (i / 2) * 128))
		atlas.generate_mipmaps()
		_atlas_material = StandardMaterial3D.new()
		_atlas_material.albedo_texture = ImageTexture.create_from_image(atlas)
		_atlas_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_atlas_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_atlas_material.roughness = 0.25
		_atlas_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return _atlas_material

## A blot with a ragged edge, streaks running out of it and a scatter of droplets, drawn pixel by pixel.
func _splat_texture(seed_value: int) -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value * 977 + 13
	noise.frequency = 0.045
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var drops: Array = []
	for i in rng.randi_range(14, 24):
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(0.42, 0.92)
		drops.append([Vector2.from_angle(angle) * dist * size * 0.5, rng.randf_range(1.2, 4.2), angle, rng.randf_range(0.0, 1.0)])
	var streaks: Array = []
	for i in rng.randi_range(4, 8):
		streaks.append([rng.randf() * TAU, rng.randf_range(0.5, 0.85), rng.randf_range(0.03, 0.07)])
	var half := size * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x - half + 0.5, y - half + 0.5)
			var r := p.length() / half
			var angle := p.angle()
			var edge := 0.3 + 0.12 * noise.get_noise_2d(cos(angle) * 60.0, sin(angle) * 60.0) * 3.0
			var cover := clampf((edge - r) / 0.05 + 0.5, 0.0, 1.0)
			for s in streaks:
				var d := absf(angle_difference(angle, s[0])) * r
				if r < s[1] and d < s[2] * (1.0 - r / s[1]) + 0.004:
					cover = maxf(cover, 1.0)
			for dr in drops:
				var offset: Vector2 = p - dr[0]
				# Droplets are stretched along the way they flew.
				var along := offset.dot(Vector2.from_angle(dr[2]))
				var across := offset.dot(Vector2.from_angle(dr[2] + PI / 2.0))
				var d := Vector2(along / 1.7, across).length()
				if d < dr[1]:
					cover = maxf(cover, clampf((dr[1] - d) / 1.2, 0.0, 1.0))
			if cover <= 0.0:
				continue
			var shade := clampf(r / 0.5, 0.0, 1.0)
			var color := Color(0.30, 0.0, 0.02).lerp(Color(0.62, 0.03, 0.05), shade * 0.6 + noise.get_noise_2d(x * 2.0, y * 2.0) * 0.15)
			color.a = cover * 0.94
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

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
