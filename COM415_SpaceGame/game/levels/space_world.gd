class_name SpaceWorld
extends WorldBase
## Level 1: an asteroid belt around an abandoned outpost, deep in space.

const PLANET_MODELS: Array[String] = [
	"Planet_1", "Planet_3", "Planet_5", "Planet_6", "Planet_8", "Planet_9", "Planet_11",
]
const ASTEROID_LARGE: Array[String] = ["Rock_Large_1", "Rock_Large_2", "Rock_Large_3"]
const ASTEROID_SMALL: Array[String] = ["Rock_1", "Rock_2", "Rock_3", "Rock_4"]

static var _size_cache: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _build() -> void:
	_rng.seed = 20261113
	nav_size = 380.0
	nav_center = Vector3.ZERO
	nav_layers = 6
	bounds = AABB(Vector3(-185, -185, -185), Vector3(370, 370, 370))
	player_start = Vector3(0.0, 0.0, 150.0)
	player_facing = Vector3(0.0, 0.0, -1.0)
	gate_position = Vector3(10.0, 15.0, -155.0)
	gate_radius = 24.0
	music_key = "space"
	patrol_area = AABB(Vector3(-150, -90, -140), Vector3(300, 180, 250))

	_build_environment()
	_build_obstacles()
	_build_backdrop()
	_build_dust()


func _build_environment() -> void:
	var shader := load("res://game/levels/space_sky.gdshader") as Shader
	var sky_material := ShaderMaterial.new()
	sky_material.shader = shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.4, 0.6)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.15
	add_environment(environment)
	add_sun(Color(1.0, 0.95, 0.9), 1.6, Vector3(-30.0, 35.0, 0.0), false)
	# A cool fill light from the opposite side.
	add_sun(Color(0.4, 0.5, 1.0), 0.5, Vector3(25.0, -140.0, 0.0), false)


func _build_obstacles() -> void:
	# Big planets and moons: the main landmarks.
	var planet_spots: Array[Vector3] = [
		Vector3(-90, 30, 40), Vector3(95, -30, 0), Vector3(-30, -50, -70),
		Vector3(60, 60, -60), Vector3(-120, 10, -110),
	]
	for i in range(planet_spots.size()):
		add_obstacle(
			PLANET_MODELS[i % PLANET_MODELS.size()], planet_spots[i],
			_rng.randf_range(11.0, 15.0), Vector3(_rng.randf_range(-30, 30), _rng.randf_range(0, 360), 0), "sphere", 0.5, 6.0
		)
	# Abandoned outpost near the middle of the map.
	add_obstacle("Base_Large", Vector3(0, -10, 10), 4.5, Vector3(0, 30, 0), "box", 0.5, 6.0)
	add_obstacle("GeodesicDome", Vector3(45, -10, 25), 4.0, Vector3(0, 0, 0), "box", 0.5, 6.0)
	add_obstacle("House_Cylinder", Vector3(-40, 5, -10), 4.0, Vector3(20, 0, 35), "sphere", 0.5, 6.0)
	add_decoration("MetalSupport", Vector3(0, -30, 10), 8.0, Vector3(0, 0, 0))
	add_decoration("Roof_Radar", Vector3(0, 8, 10), 5.0)
	# Asteroid field.
	_scatter_obstacles(ASTEROID_LARGE, 12, 4.0, 6.5, 8.0)
	_scatter_obstacles(ASTEROID_SMALL, 22, 4.0, 8.0, 5.0)


func _build_backdrop() -> void:
	# Giant planets far outside the play area give the level its visual identity.
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	add_decoration("Planet_10", Vector3(-520, 160, -600), 130.0, Vector3(15, 0, 20), backdrop)
	add_decoration("Planet_4", Vector3(650, -200, -450), 70.0, Vector3(0, 40, 0), backdrop)
	add_decoration("Planet_7", Vector3(300, 380, 500), 60.0, Vector3(0, 0, 0), backdrop)
	# Distant asteroids outside the play area.
	for i in range(30):
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-1, 1)).normalized()
		var distance := _rng.randf_range(260.0, 420.0)
		add_decoration(
			ASTEROID_LARGE[i % 3], direction * distance, _rng.randf_range(4.0, 9.0),
			Vector3(_rng.randf_range(0, 360), _rng.randf_range(0, 360), 0), backdrop
		)


## Space dust specks drifting through the arena: they make speed visible.
func _build_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "SpaceDust"
	dust.amount = 700
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(180, 180, 180)
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.2
	process_material.initial_velocity_max = 1.0
	process_material.direction = Vector3(0.0, 0.0, 1.0)
	process_material.spread = 180.0
	process_material.scale_min = 0.5
	process_material.scale_max = 1.5
	dust.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.8, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	dust.draw_pass_1 = quad
	add_child(dust)


## Randomly places [param count] asteroids that do not overlap anything.
func _scatter_obstacles(models: Array[String], count: int, min_scale: float, max_scale: float, margin: float) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 30:
		attempts += 1
		var model_name := models[_rng.randi() % models.size()]
		var model_scale := _rng.randf_range(min_scale, max_scale)
		var radius := _get_model_size(model_name) * model_scale * 0.5 + 6.0
		var point := Vector3(
			_rng.randf_range(-165, 165), _rng.randf_range(-120, 120), _rng.randf_range(-165, 165)
		)
		if point.distance_to(player_start) < 70.0 + radius:
			continue
		if point.distance_to(gate_position) < 60.0 + radius:
			continue
		if not is_point_free(point, radius + margin):
			continue
		add_obstacle(
			model_name, point, model_scale,
			Vector3(_rng.randf_range(0, 360), _rng.randf_range(0, 360), _rng.randf_range(0, 360)),
			"sphere", 0.42, 5.0
		)
		placed += 1


func _get_model_size(model_name: String) -> float:
	if _size_cache.has(model_name):
		return _size_cache[model_name]
	var instance := load_model(model_name).instantiate() as Node3D
	var bounds_local := ShipModelFactory.calculate_bounds(instance, Transform3D.IDENTITY)
	var largest := maxf(bounds_local.size.x, maxf(bounds_local.size.y, bounds_local.size.z))
	instance.free()
	_size_cache[model_name] = largest
	return largest
