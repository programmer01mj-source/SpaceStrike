class_name WorldBase
extends Node3D
## Base class for a level's 3D world (environment, lighting, obstacles, goals).
##
## A child class overrides _build() and fills in the settings below, then uses
## the add_* helpers to place scenery. Obstacles registered with add_obstacle()
## are used for three things:
##   1. Physics collision (player and lasers hit them)
##   2. The FlightNavigation3D voxelisation (enemies path-find around them)
##   3. Choosing free spawn / patrol points

const VOXELIZATION_TARGET_SCENE := "res://addons/flight_navigation_3d/core/src/voxelization_target.tscn"
const ENVIRONMENT_DIR := "res://assets/environment/"

## Edge length of the cubic navigation volume (metres).
var nav_size: float = 320.0
## Centre of the navigation volume.
var nav_center: Vector3 = Vector3.ZERO
## SVO layers (resolution). Higher = finer but much slower to build.
var nav_layers: int = 6
## Area the player and enemies may fly in.
var bounds: AABB = AABB(Vector3(-150, -150, -150), Vector3(300, 300, 300))
var player_start: Vector3 = Vector3.ZERO
var player_facing: Vector3 = Vector3.FORWARD
var gate_position: Vector3 = Vector3(0, 0, -100)
var gate_radius: float = 22.0
var music_key: String = "space"
## Area in which enemies are placed and patrol.
var patrol_area: AABB = AABB(Vector3(-130, -50, -130), Vector3(260, 100, 260))

## Every registered obstacle as {"position": Vector3, "radius": float}.
var obstacles: Array[Dictionary] = []

static var _scene_cache: Dictionary = {}

var _voxelization_scene: PackedScene


func build() -> void:
	_voxelization_scene = load(VOXELIZATION_TARGET_SCENE)
	_build()


## Override in child classes.
func _build() -> void:
	pass


## True if [param point] is at least [param clearance] away from every obstacle.
func is_point_free(point: Vector3, clearance: float) -> bool:
	for obstacle in obstacles:
		var radius: float = obstacle["radius"]
		if point.distance_to(obstacle["position"]) < radius + clearance:
			return false
	return true


## Random point inside [param area] that does not touch any obstacle.
func random_free_point(area: AABB, clearance: float = 15.0) -> Vector3:
	var point := area.get_center()
	for attempt in range(40):
		point = Vector3(
			randf_range(area.position.x, area.end.x),
			randf_range(area.position.y, area.end.y),
			randf_range(area.position.z, area.end.z)
		)
		if is_point_free(point, clearance):
			return point
	return point


## Loads a model from the environment folder (cached).
func load_model(model_name: String) -> PackedScene:
	if not _scene_cache.has(model_name):
		_scene_cache[model_name] = load(ENVIRONMENT_DIR + model_name + ".gltf")
	return _scene_cache[model_name]


## Adds a purely decorative model (no collision).
func add_decoration(
		model_name: String, world_position: Vector3, model_scale: float,
		rotation_degrees_value: Vector3 = Vector3.ZERO, parent: Node = null) -> Node3D:
	var instance := load_model(model_name).instantiate() as Node3D
	instance.position = world_position
	instance.rotation_degrees = rotation_degrees_value
	instance.scale = Vector3.ONE * model_scale
	(parent if parent != null else self).add_child(instance)
	return instance


## Adds a solid obstacle: visual model + physics collision + navigation voxelisation.
## [param shape_kind] is "sphere" or "box". The collision shape is fitted to the model.
## [param nav_margin] inflates the shape used for path finding so ships keep a safe distance.
func add_obstacle(
		model_name: String, world_position: Vector3, model_scale: float,
		rotation_degrees_value: Vector3 = Vector3.ZERO, shape_kind: String = "sphere",
		shape_fit: float = 0.5, nav_margin: float = 6.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = world_position
	body.rotation_degrees = rotation_degrees_value
	add_child(body)

	var model := load_model(model_name).instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	body.add_child(model)

	var bounds_local := ShipModelFactory.calculate_bounds(model, Transform3D.IDENTITY)
	var centre := bounds_local.get_center()
	var largest_side := maxf(bounds_local.size.x, maxf(bounds_local.size.y, bounds_local.size.z))

	var physics_shape := CollisionShape3D.new()
	physics_shape.position = centre
	var navigation_shape := CollisionShape3D.new()
	navigation_shape.position = centre
	navigation_shape.disabled = true  # only used to tell the navigation system the obstacle size
	var effective_radius := 0.0
	if shape_kind == "box":
		var box := BoxShape3D.new()
		box.size = bounds_local.size * shape_fit * 2.0
		physics_shape.shape = box
		var nav_box := BoxShape3D.new()
		nav_box.size = box.size + Vector3.ONE * nav_margin * 2.0
		navigation_shape.shape = nav_box
		effective_radius = nav_box.size.length() * 0.5
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = largest_side * shape_fit
		physics_shape.shape = sphere
		var nav_sphere := SphereShape3D.new()
		nav_sphere.radius = sphere.radius + nav_margin
		navigation_shape.shape = nav_sphere
		effective_radius = nav_sphere.radius
	body.add_child(physics_shape)
	body.add_child(navigation_shape)
	var target := _voxelization_scene.instantiate()
	navigation_shape.add_child(target)

	obstacles.append({
		"position": body.global_transform * centre,
		"radius": effective_radius,
	})
	return body


## Adds an invisible solid floor (used by the planet level) and voxelises it.
func add_ground_collision(top_y: float, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, top_y - size.y * 0.5, 0.0)
	add_child(body)
	var physics_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	physics_shape.shape = box
	body.add_child(physics_shape)
	var navigation_shape := CollisionShape3D.new()
	var nav_box := BoxShape3D.new()
	nav_box.size = size + Vector3(0.0, 12.0, 0.0)
	navigation_shape.shape = nav_box
	navigation_shape.position = Vector3(0.0, 6.0, 0.0)
	navigation_shape.disabled = true
	body.add_child(navigation_shape)
	navigation_shape.add_child(_voxelization_scene.instantiate())


## Creates a WorldEnvironment node.
func add_environment(environment: Environment) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


## Creates a directional (sun) light.
func add_sun(color: Color, energy: float, rotation_degrees_value: Vector3, shadows: bool) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_color = color
	sun.light_energy = energy
	sun.rotation_degrees = rotation_degrees_value
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 260.0
	add_child(sun)
	return sun


## Makes a standard material with the given colour.
func make_material(color: Color, roughness: float = 0.9, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material
