class_name EnemyShip
extends CharacterBody3D
## A flying enemy.
##
## Decision making : Finite State Machine (Wander -> Chase -> Attack), see game/ai/fsm.
## Movement        : GDQuest steering behaviours (path following, pursue, seek,
##                   separation) plus custom wander + obstacle avoidance behaviours.
## Path finding    : FlightNavigation3D plugin (sparse voxel octree) via the level's
##                   PathService - the resulting path is followed with GSAIFollowPath.

signal died(enemy: EnemyShip)

const COLLISION_WORLD := 1
const COLLISION_PLAYER := 2
const COLLISION_ENEMY := 4

## Every enemy's steering agent. Used by the separation behaviour.
static var shared_agents: Array = []

var type_index: int = 0
var type_def: Dictionary = {}
var health: float = 50.0
var max_health: float = 50.0
var level: LevelController = null
var player: PlayerShip = null

# Steering
var agent: GSAISteeringAgent = GSAISteeringAgent.new()
var follow_path: GSAIFollowPath
var wander: WanderSteering
var separation: GSAISeparation
var avoidance: ObstacleAvoidanceSteering
var pursue: GSAIPursue
var seek: GSAISeek
var seek_target: GSAIAgentLocation = GSAIAgentLocation.new()

# Navigation
var has_valid_path: bool = false
var path_pending: bool = false
var path_end: Vector3 = Vector3.ZERO

var state_machine: StateMachine
var icon_color: Color = Color.RED

var _acceleration: GSAITargetAcceleration = GSAITargetAcceleration.new()
var _fire_cooldown: float = 1.0
var _fire_side: float = 1.0
var _aim_position: Vector3 = Vector3.ZERO
var _use_aim_position: bool = false
var _min_speed: float = 10.0
var _max_speed: float = 40.0
var _turn_rate: float = 2.0
var _los_timer: float = 0.0
var _cached_los: bool = false
var _alive: bool = true
var _cast_shape: SphereShape3D = SphereShape3D.new()


func setup(p_type_index: int, p_level: LevelController, p_player: PlayerShip) -> void:
	type_index = p_type_index
	level = p_level
	player = p_player
	type_def = ShipCatalog.ENEMY_TYPES[type_index]
	max_health = float(type_def["max_health"])
	health = max_health
	icon_color = type_def["icon_color"]


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = COLLISION_ENEMY
	collision_mask = COLLISION_WORLD | COLLISION_PLAYER
	_cast_shape.radius = 2.4
	_max_speed = float(type_def["max_speed"])
	_min_speed = _max_speed * 0.45
	_turn_rate = float(type_def["turn_rate"])

	var collision_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	collision_shape.shape = sphere
	add_child(collision_shape)

	var visual := ShipCatalog.create_enemy_visual(type_index)
	add_child(visual)
	var exhaust := Effects.engine_exhaust(icon_color, 1.2)
	exhaust.position = Vector3(0.0, 0.0, ShipCatalog.ENEMY_MODEL_SIZE * 0.5)
	add_child(exhaust)

	_setup_steering()
	_setup_state_machine()
	_fire_cooldown = randf_range(0.5, 2.0)
	# Start with a forward velocity so ships are already moving when the level begins.
	var start_direction := -global_basis.z
	velocity = start_direction * _min_speed
	agent.linear_velocity = velocity


func _exit_tree() -> void:
	shared_agents.erase(agent)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_fire_cooldown -= delta
	_los_timer -= delta
	agent.position = global_position
	agent.linear_velocity = velocity
	# The state machine runs in its own _physics_process and calls steer().
	_integrate_motion(delta)


# --- API used by the states -------------------------------------------------

func distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)


func is_player_alive() -> bool:
	return player != null and player.is_alive


## True if nothing in the world blocks the line to the player. Cached for a short time.
func can_see_player() -> bool:
	if _los_timer > 0.0:
		return _cached_los
	_los_timer = 0.2
	if not is_player_alive():
		_cached_los = false
		return false
	var query := PhysicsRayQueryParameters3D.create(
		global_position, player.global_position, COLLISION_WORLD
	)
	_cached_los = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return _cached_los


## Asks the level to compute a flight path to [param target]. The answer arrives in receive_path().
func request_path_to(target: Vector3) -> void:
	if path_pending:
		return
	if level == null or level.path_service == null:
		receive_path(PackedVector3Array())
		return
	path_pending = true
	level.path_service.request_path(self, target)


## Called by the PathService with the path found by the FlightNavigation3D plugin.
func receive_path(points: PackedVector3Array) -> void:
	path_pending = false
	if points.size() < 2:
		has_valid_path = false
		return
	var cleaned := _clean_path(points)
	if cleaned.size() < 2:
		has_valid_path = false
		return
	follow_path.path = GSAIPath.new(cleaned, true)
	path_end = cleaned[cleaned.size() - 1]
	has_valid_path = true


func clear_path() -> void:
	has_valid_path = false
	path_pending = false


func has_reached_path_end(radius: float) -> bool:
	return has_valid_path and global_position.distance_to(path_end) < radius


## Runs one steering behaviour and uses the result to accelerate the ship.
func steer(behavior: GSAISteeringBehavior, delta: float) -> void:
	behavior.calculate_steering(_acceleration)
	var accel := _acceleration.linear
	if not accel.is_finite():
		accel = Vector3.ZERO
	velocity += accel * delta
	var speed := velocity.length()
	if speed > _max_speed:
		velocity = velocity / speed * _max_speed
	elif speed < _min_speed:
		var heading := velocity.normalized() if speed > 0.1 else -global_basis.z
		velocity = heading * _min_speed


## Makes the ship face [param position] (used while attacking) instead of its velocity.
func aim_at(position_to_face: Vector3) -> void:
	_aim_position = position_to_face
	_use_aim_position = true


func clear_aim() -> void:
	_use_aim_position = false


## Fires a laser at the player when aimed well enough and the weapon is ready.
func try_fire() -> void:
	if _fire_cooldown > 0.0 or not is_player_alive() or level == null:
		return
	var bolt_speed := float(type_def["bolt_speed"])
	var side_offset := global_basis.x * 1.1 * _fire_side
	_fire_side = -_fire_side
	var origin := global_position - global_basis.z * 2.4 + side_offset
	var distance := origin.distance_to(player.global_position)
	var lead_time := distance / bolt_speed
	var predicted := player.global_position + player.velocity * lead_time * 0.8
	var direction := (predicted - origin).normalized()
	if (-global_basis.z).dot(direction) < 0.93:
		return
	direction += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.035
	_fire_cooldown = float(type_def["fire_interval"]) * randf_range(0.9, 1.2)
	LaserBolt.fire(
		level.projectile_root, origin, direction, bolt_speed, float(type_def["damage"]),
		COLLISION_WORLD | COLLISION_PLAYER, Color(1.0, 0.25, 0.2), self
	)
	if distance < 220.0:
		AudioManager.play_sfx("enemy_laser", -9.0 - distance / 25.0, randf_range(0.9, 1.1))


func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if not _alive:
		return
	health -= amount
	if state_machine != null and state_machine.current_state_name == &"Wander":
		state_machine.transition_to(&"Chase")
	if health <= 0.0:
		_die()


func get_health_ratio() -> float:
	return clampf(health / max_health, 0.0, 1.0)


# --- Internals ----------------------------------------------------------------

func _setup_steering() -> void:
	agent.linear_speed_max = _max_speed
	agent.linear_acceleration_max = float(type_def["acceleration"])
	agent.angular_speed_max = _turn_rate
	agent.angular_acceleration_max = _turn_rate * 2.0
	agent.bounding_radius = 2.5
	agent.position = global_position
	shared_agents.append(agent)

	var start := global_position
	follow_path = GSAIFollowPath.new(
		agent, GSAIPath.new([start, start - global_basis.z * 20.0], true), 12.0, 0.0
	)
	follow_path.deceleration_radius = 15.0
	follow_path.arrival_tolerance = 4.0
	wander = WanderSteering.new(agent)
	separation = GSAISeparation.new(agent, GSAIInfiniteProximity.new(agent, shared_agents))
	separation.decay_coefficient = 4000.0
	avoidance = ObstacleAvoidanceSteering.new(agent, self)
	pursue = GSAIPursue.new(agent, player.agent, 1.2)
	seek = GSAISeek.new(agent, seek_target)


func _setup_state_machine() -> void:
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	var wander_state := EnemyWanderState.new()
	wander_state.name = "Wander"
	state_machine.add_child(wander_state)
	var chase_state := EnemyChaseState.new()
	chase_state.name = "Chase"
	state_machine.add_child(chase_state)
	var attack_state := EnemyAttackState.new()
	attack_state.name = "Attack"
	state_machine.add_child(attack_state)
	state_machine.setup(self, &"Wander")


func _integrate_motion(delta: float) -> void:
	# Face the target (when attacking) or the direction of travel.
	var face_direction := velocity.normalized()
	if _use_aim_position:
		face_direction = (_aim_position - global_position).normalized()
	if face_direction.length_squared() > 0.5:
		var up := Vector3.UP
		if absf(face_direction.dot(Vector3.UP)) > 0.98:
			up = Vector3.RIGHT
		var target_basis := Basis.looking_at(face_direction, up)
		var current := Quaternion(global_basis.orthonormalized())
		var weight := 1.0 - exp(-_turn_rate * 2.5 * delta)
		global_basis = Basis(current.slerp(Quaternion(target_basis), weight))
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var normal := collision.get_normal()
		velocity = velocity.slide(normal) + normal * 8.0
		clear_path()
	if level != null:
		global_position = level.clamp_to_bounds(global_position)


## Removes duplicate points and short-cuts the voxel path with sphere casts
## (string pulling) so ships fly smooth lines instead of zig-zagging between voxels.
func _clean_path(points: PackedVector3Array) -> PackedVector3Array:
	var raw: Array[Vector3] = [global_position]
	for point in points:
		if point.distance_to(raw[raw.size() - 1]) > 1.0:
			raw.append(point)
	if raw.size() < 2:
		return PackedVector3Array()
	var space := get_world_3d().direct_space_state
	var result := PackedVector3Array()
	var anchor := raw[0]
	result.append(anchor)
	var index := 1
	while index < raw.size():
		var furthest := index
		for probe in range(index, mini(index + 12, raw.size())):
			if _is_segment_clear(space, anchor, raw[probe]):
				furthest = probe
			else:
				break
		anchor = raw[furthest]
		result.append(anchor)
		index = furthest + 1
	return result


func _is_segment_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _cast_shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = COLLISION_WORLD
	var fractions := space.cast_motion(query)
	return fractions.size() >= 2 and fractions[0] >= 0.999


func _die() -> void:
	_alive = false
	shared_agents.erase(agent)
	Effects.explosion(level.projectile_root if level != null else get_parent(), global_position, 1.0)
	AudioManager.play_sfx("explosion", -2.0, randf_range(0.9, 1.1))
	died.emit(self)
	queue_free()
