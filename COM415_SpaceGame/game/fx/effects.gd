class_name Effects
extends RefCounted
## Helper functions that create particle effects in code
## (explosions, laser impact sparks, engine exhaust).
##
## Particle systems follow the Godot docs "Creating a 3D particle system":
## https://docs.godotengine.org/en/stable/tutorials/3d/particles/creating_a_3d_particle_system.html

static var _soft_texture: GradientTexture2D = null
static var _material_cache: Dictionary = {}


## Big fiery explosion with debris. Frees itself when finished.
static func explosion(parent: Node, world_position: Vector3, size: float = 1.0) -> void:
	var fire := _make_burst(
		world_position, 60, 0.9, 9.0 * size, 14.0 * size, 2.5 * size, 5.0 * size,
		Color(1.0, 0.85, 0.35, 1.0), Color(1.0, 0.25, 0.05, 0.0)
	)
	parent.add_child(fire)
	fire.global_position = world_position
	fire.emitting = true
	var smoke := _make_burst(
		world_position, 24, 1.6, 2.0 * size, 5.0 * size, 3.0 * size, 6.0 * size,
		Color(0.35, 0.3, 0.3, 0.7), Color(0.05, 0.05, 0.05, 0.0)
	)
	parent.add_child(smoke)
	smoke.global_position = world_position
	smoke.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.65, 0.3)
	flash.light_energy = 6.0
	flash.omni_range = 40.0 * size
	parent.add_child(flash)
	flash.global_position = world_position
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)


## Small spark burst where a laser hits something.
static func sparks(parent: Node, world_position: Vector3, color: Color) -> void:
	var burst := _make_burst(
		world_position, 14, 0.35, 6.0, 12.0, 0.5, 1.1,
		color.lightened(0.3), Color(color.r, color.g, color.b, 0.0)
	)
	parent.add_child(burst)
	burst.global_position = world_position
	burst.emitting = true


## Continuous engine exhaust. Add it as a child of the ship (at the back).
static func engine_exhaust(color: Color, scale_factor: float = 1.0) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "EngineExhaust"
	particles.amount = 28
	particles.lifetime = 0.55
	particles.local_coords = false
	particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	particles.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 0, 1)
	process_material.spread = 6.0
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 4.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.5 * scale_factor
	process_material.scale_max = 0.9 * scale_factor
	process_material.color_ramp = _make_ramp(color.lightened(0.4), Color(color.r, color.g, color.b, 0.0))
	process_material.scale_curve = _make_shrink_curve()
	particles.process_material = process_material
	particles.draw_pass_1 = _make_quad(0.6)
	return particles


## Creates a glowing, unshaded material (cached) used for laser bolts.
static func glow_material(color: Color) -> StandardMaterial3D:
	var key := "glow_" + color.to_html()
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	_material_cache[key] = material
	return material


static func _make_burst(
		_position: Vector3, amount: int, lifetime: float,
		speed_min: float, speed_max: float, scale_min: float, scale_max: float,
		start_color: Color, end_color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.4
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = speed_min
	process_material.initial_velocity_max = speed_max
	process_material.gravity = Vector3.ZERO
	process_material.damping_min = 2.0
	process_material.damping_max = 5.0
	process_material.scale_min = scale_min
	process_material.scale_max = scale_max
	process_material.color_ramp = _make_ramp(start_color, end_color)
	process_material.scale_curve = _make_shrink_curve()
	particles.process_material = process_material
	particles.draw_pass_1 = _make_quad(0.5)
	particles.finished.connect(particles.queue_free)
	return particles


static func _make_ramp(start_color: Color, end_color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, start_color)
	gradient.set_color(1, end_color)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _make_shrink_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _make_quad(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.albedo_texture = _get_soft_texture()
	material.disable_receive_shadows = true
	quad.material = material
	return quad


static func _get_soft_texture() -> GradientTexture2D:
	if _soft_texture != null:
		return _soft_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	_soft_texture = GradientTexture2D.new()
	_soft_texture.gradient = gradient
	_soft_texture.fill = GradientTexture2D.FILL_RADIAL
	_soft_texture.fill_from = Vector2(0.5, 0.5)
	_soft_texture.fill_to = Vector2(1.0, 0.5)
	_soft_texture.width = 64
	_soft_texture.height = 64
	return _soft_texture
