class_name PlanetWorld
extends WorldBase
## Level 2: a winding canyon on an alien planet's surface.
##
## The ground is at y = 0. The canyon follows a sine curve along the Z axis;
## huge rocks form the walls and spires, ruins and trees fill the valley.

const WALL_ROCKS: Array[String] = ["Rock_Large_1", "Rock_Large_2", "Rock_Large_3"]
const SPIRES: Array[String] = ["Rock_3", "Rock_4", "Rock_1"]
const TREES: Array[String] = [
	"Tree_Spiral_1", "Tree_Spiral_2", "Tree_Swirl_1", "Tree_Spikes_1", "Tree_Blob_1",
	"Tree_Light_1", "Tree_Lava_1", "Tree_Floating_2",
]
const GROUND_PLANTS: Array[String] = ["Bush_1", "Bush_2", "Plant_1", "Plant_3", "Grass_2", "Grass_3"]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _build() -> void:
	_rng.seed = 77123
	nav_size = 320.0
	nav_center = Vector3(0.0, 100.0, 0.0)
	nav_layers = 6
	bounds = AABB(Vector3(-155, 4, -155), Vector3(310, 66, 310))
	player_start = Vector3(_canyon_x(135.0), 40.0, 135.0)
	player_facing = Vector3(0.0, 0.0, -1.0)
	gate_position = Vector3(_canyon_x(-132.0), 34.0, -132.0)
	gate_radius = 22.0
	music_key = "planet"
	patrol_area = AABB(Vector3(-110, 14, -120), Vector3(220, 80, 240))

	_build_environment()
	_build_ground()
	_build_canyon_walls()
	_build_valley_obstacles()
	_build_outpost()
	_build_vegetation()
	_build_backdrop()


## X position of the canyon centre-line at a given Z.
func _canyon_x(z: float) -> float:
	return 45.0 * sin(z / 52.0)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.2, 0.45)
	sky_material.sky_horizon_color = Color(1.0, 0.62, 0.38)
	sky_material.ground_horizon_color = Color(0.95, 0.5, 0.3)
	sky_material.ground_bottom_color = Color(0.4, 0.2, 0.15)
	sky_material.sun_angle_max = 25.0
	sky_material.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.fog_enabled = true
	environment.fog_light_color = Color(1.0, 0.66, 0.45)
	environment.fog_density = 0.0028
	environment.fog_sky_affect = 0.4
	add_environment(environment)
	add_sun(Color(1.0, 0.78, 0.55), 1.7, Vector3(-28.0, -40.0, 0.0), true)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800.0, 1800.0)
	ground.mesh = plane
	ground.material_override = make_material(Color(0.62, 0.3, 0.2), 1.0)
	add_child(ground)
	add_ground_collision(0.0, Vector3(900.0, 30.0, 900.0))

	# A glowing river following the canyon floor.
	var river_material := make_material(Color(0.15, 0.55, 0.85), 0.1, 0.7)
	river_material.metallic = 0.3
	var z := 190.0
	while z > -190.0:
		var next_z := z - 14.0
		var from := Vector3(_canyon_x(z), 0.25, z)
		var to := Vector3(_canyon_x(next_z), 0.25, next_z)
		var segment := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(22.0, 0.3, from.distance_to(to) + 2.0)
		segment.mesh = box
		segment.material_override = river_material
		add_child(segment)
		segment.position = (from + to) * 0.5
		segment.look_at_from_position(segment.position, to, Vector3.UP)
		z = next_z


func _build_canyon_walls() -> void:
	var z := 190.0
	var index := 0
	while z > -200.0:
		for side in [-1.0, 1.0]:
			var offset: float = 52.0 + _rng.randf_range(0.0, 16.0)
			var x: float = _canyon_x(z) + side * offset
			if absf(x) > 175.0:
				continue
			add_obstacle(
				WALL_ROCKS[index % WALL_ROCKS.size()], Vector3(x, 0.0, z),
				_rng.randf_range(7.0, 10.0), Vector3(0, _rng.randf_range(0, 360), 0), "sphere", 0.46, 5.0
			)
			index += 1
		z -= 28.0
	# Second, outer layer of cliffs to hide the edge of the map.
	z = 175.0
	while z > -180.0:
		for side in [-1.0, 1.0]:
			var x: float = _canyon_x(z) + side * (108.0 + _rng.randf_range(0.0, 20.0))
			if absf(x) > 185.0:
				continue
			add_decoration(
				WALL_ROCKS[(index + 1) % WALL_ROCKS.size()], Vector3(x, 0.0, z),
				_rng.randf_range(9.0, 13.0), Vector3(0, _rng.randf_range(0, 360), 0)
			)
			index += 1
		z -= 35.0


## Rock spires and arches standing in the valley that must be flown around.
func _build_valley_obstacles() -> void:
	for i in range(16):
		var z := _rng.randf_range(-120.0, 100.0)
		var x := _canyon_x(z) + _rng.randf_range(-26.0, 26.0)
		var point := Vector3(x, 0.0, z)
		if point.distance_to(Vector3(player_start.x, 0.0, player_start.z)) < 40.0:
			continue
		if point.distance_to(Vector3(gate_position.x, 0.0, gate_position.z)) < 45.0:
			continue
		if not is_point_free(Vector3(x, 15.0, z), 18.0):
			continue
		add_obstacle(
			SPIRES[i % SPIRES.size()], point, _rng.randf_range(6.0, 9.0),
			Vector3(0, _rng.randf_range(0, 360), 0), "sphere", 0.4, 5.0
		)


## A small abandoned research outpost halfway down the canyon.
func _build_outpost() -> void:
	var centre_z := -20.0
	var base := Vector3(_canyon_x(centre_z) + 30.0, 0.0, centre_z)
	add_obstacle("Base_Large", base, 3.4, Vector3(0, 20, 0), "box", 0.5, 5.0)
	add_obstacle("GeodesicDome", base + Vector3(-34, 0, 18), 3.0, Vector3.ZERO, "box", 0.5, 5.0)
	add_obstacle("House_Long", base + Vector3(18, 0, -30), 3.2, Vector3(0, 70, 0), "box", 0.5, 5.0)
	add_obstacle("SolarPanel_Structure", base + Vector3(30, 0, 12), 4.0, Vector3(0, 15, 0), "box", 0.5, 5.0)
	add_decoration("Roof_Antenna", base + Vector3(0, 17, 0), 3.4)
	add_decoration("Roof_Radar", base + Vector3(-34, 16, 18), 3.0)
	# Landing pad approach with solar panels on the ground.
	for i in range(6):
		add_decoration(
			"SolarPanel_Ground", base + Vector3(-24 + i * 7.0, 0, -22), 3.0, Vector3(0, 10, 0)
		)


func _build_vegetation() -> void:
	# Alien trees along the banks: some are solid obstacles, most are scenery.
	for i in range(46):
		var z := _rng.randf_range(-185.0, 185.0)
		var side := -1.0 if _rng.randf() > 0.5 else 1.0
		var x := _canyon_x(z) + side * _rng.randf_range(16.0, 44.0)
		var tree_scale := _rng.randf_range(3.4, 5.8)
		var model_name := TREES[i % TREES.size()]
		var point := Vector3(x, 0.0, z)
		if i % 3 == 0 and is_point_free(Vector3(x, 8.0, z), 14.0) \
				and point.distance_to(Vector3(player_start.x, 0.0, player_start.z)) > 40.0 \
				and point.distance_to(Vector3(gate_position.x, 0.0, gate_position.z)) > 45.0:
			add_obstacle(model_name, point, tree_scale, Vector3(0, _rng.randf_range(0, 360), 0), "sphere", 0.38, 4.0)
		else:
			add_decoration(model_name, point, tree_scale, Vector3(0, _rng.randf_range(0, 360), 0))
	for i in range(110):
		var z := _rng.randf_range(-190.0, 190.0)
		var x := _canyon_x(z) + _rng.randf_range(-75.0, 75.0)
		add_decoration(
			GROUND_PLANTS[i % GROUND_PLANTS.size()], Vector3(x, 0.0, z),
			_rng.randf_range(2.5, 4.5), Vector3(0, _rng.randf_range(0, 360), 0)
		)


func _build_backdrop() -> void:
	# A huge neighbouring planet hangs in the sky.
	add_decoration("Planet_2", Vector3(-380, 250, -620), 150.0, Vector3(10, 0, 15))
	add_decoration("Planet_7", Vector3(500, 330, -700), 60.0, Vector3(0, 0, 0))
