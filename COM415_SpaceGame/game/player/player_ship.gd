class_name PlayerShip
extends CharacterBody3D
## The ship the player flies.
##
## The ship always flies forward. The virtual joystick (steer_input) turns it,
## the FIRE button shoots lasers and the BOOST button engages the afterburner.
## Maximum speed, acceleration, turn rate and health come from ShipCatalog.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal collided(impact_speed: float)
signal died

const COLLISION_WORLD := 1
const COLLISION_PLAYER := 2
const COLLISION_ENEMY := 4

const BOOST_MULTIPLIER := 1.7
const BOOST_DRAIN_PER_SECOND := 38.0
const BOOST_REGEN_PER_SECOND := 16.0
const FIRE_INTERVAL := 0.16
const BOLT_SPEED := 280.0
const AIM_ASSIST_COS := 0.985
const AIM_ASSIST_RANGE := 320.0
const MAX_PITCH := 1.25

## Stick position from the virtual joystick: x = right (+), y = up (+).
var steer_input: Vector2 = Vector2.ZERO
var fire_pressed: bool = false
var boost_pressed: bool = false

var ship_index: int = 0
var ship_def: Dictionary = {}
var health: float = 100.0
var max_health: float = 100.0
var speed: float = 0.0
var boost_energy: float = 100.0
var is_alive: bool = true
var is_boosting: bool = false
var agent: GSAISteeringAgent = GSAISteeringAgent.new()
var projectile_root: Node = null
var level: LevelController = null

var _yaw: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _fire_cooldown: float = 0.0
var _fire_side: float = 1.0
var _invulnerable_time: float = 0.0
var _visual: Node3D
var _exhaust: GPUParticles3D


func setup(p_ship_index: int, p_level: LevelController) -> void:
	ship_index = p_ship_index
	ship_def = ShipCatalog.PLAYER_SHIPS[ship_index]
	level = p_level
	max_health = float(ship_def["max_health"])
	health = max_health


func _ready() -> void:
	add_to_group("player")
	collision_layer = COLLISION_PLAYER
	collision_mask = COLLISION_WORLD | COLLISION_ENEMY
	var collision_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	collision_shape.shape = sphere
	add_child(collision_shape)

	_visual = ShipCatalog.create_player_visual(ship_index)
	add_child(_visual)
	_exhaust = Effects.engine_exhaust(Color(0.3, 0.7, 1.0), 1.3)
	_exhaust.position = Vector3(0.0, 0.0, ShipCatalog.PLAYER_MODEL_SIZE * 0.5)
	add_child(_exhaust)

	# Take the starting direction from the transform given by the level.
	var euler := global_basis.get_euler()
	_yaw = euler.y
	_pitch = 0.0
	speed = float(ship_def["max_speed"]) * 0.5
	agent.linear_speed_max = float(ship_def["max_speed"])
	agent.position = global_position
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)
	_fire_cooldown -= delta
	_update_steering(delta)
	_update_speed(delta)
	_move(delta)
	if fire_pressed or Input.is_action_pressed("fire"):
		_try_fire()
	agent.position = global_position
	agent.linear_velocity = velocity


func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	AudioManager.play_sfx("hit", -4.0, randf_range(0.9, 1.1))
	if health <= 0.0:
		_die()


func get_speed_ratio() -> float:
	return clampf(speed / float(ship_def["max_speed"]), 0.0, BOOST_MULTIPLIER)


func get_forward() -> Vector3:
	return -global_basis.z


func _update_steering(delta: float) -> void:
	var stick := steer_input
	var keyboard := Input.get_vector("steer_left", "steer_right", "steer_down", "steer_up")
	if keyboard.length() > stick.length():
		stick = keyboard
	var turn_rate := float(ship_def["turn_rate"])
	# Positive yaw turns the ship LEFT in Godot, so the stick is inverted.
	_yaw -= stick.x * turn_rate * delta
	_pitch = clampf(_pitch + stick.y * turn_rate * 0.8 * delta, -MAX_PITCH, MAX_PITCH)
	global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	# Bank the visual model into the turn (does not affect the camera).
	_roll = lerpf(_roll, -stick.x * 0.55, 1.0 - exp(-6.0 * delta))
	_visual.rotation.z = _roll


func _update_speed(delta: float) -> void:
	var max_speed := float(ship_def["max_speed"])
	var wants_boost := (boost_pressed or Input.is_action_pressed("boost")) and boost_energy > 1.0
	if wants_boost and not is_boosting:
		AudioManager.play_sfx("boost", -6.0)
	is_boosting = wants_boost
	var target_speed := max_speed
	if is_boosting:
		target_speed = max_speed * BOOST_MULTIPLIER
		boost_energy = maxf(0.0, boost_energy - BOOST_DRAIN_PER_SECOND * delta)
	else:
		boost_energy = minf(100.0, boost_energy + BOOST_REGEN_PER_SECOND * delta)
	var acceleration := float(ship_def["acceleration"]) * (2.0 if is_boosting else 1.0)
	speed = move_toward(speed, target_speed, acceleration * delta)
	_exhaust.amount_ratio = clampf(0.4 + speed / max_speed * 0.6, 0.2, 1.0)


func _move(delta: float) -> void:
	velocity = -global_basis.z * speed
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var normal := collision.get_normal()
		var impact_speed := speed
		global_position += normal * 0.5
		speed *= 0.3
		# Turn the ship away from the surface a little.
		var forward := -global_basis.z
		var reflected := forward.slide(normal).normalized()
		if reflected.length_squared() > 0.1:
			_yaw = atan2(-reflected.x, -reflected.z)
			_pitch = clampf(asin(clampf(reflected.y, -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
		collided.emit(impact_speed)
		if _invulnerable_time <= 0.0:
			_invulnerable_time = 0.8
			take_damage(clampf(impact_speed * 0.3, 5.0, 30.0))
	if level != null:
		global_position = level.clamp_to_bounds(global_position)


func _try_fire() -> void:
	if _fire_cooldown > 0.0 or projectile_root == null:
		return
	_fire_cooldown = FIRE_INTERVAL
	var forward := get_forward()
	var muzzle := global_position + forward * 2.2 + global_basis.x * 1.1 * _fire_side + global_basis.y * -0.2
	_fire_side = -_fire_side
	var direction := _get_aim_direction(muzzle, forward)
	LaserBolt.fire(
		projectile_root, muzzle, direction, BOLT_SPEED + speed * 0.5,
		float(ship_def["damage"]), COLLISION_WORLD | COLLISION_ENEMY,
		Color(0.3, 0.95, 1.0), self
	)
	AudioManager.play_sfx("player_laser", -7.0, randf_range(0.93, 1.07))


## Gentle aim assist: if an enemy is almost in the crosshair, shoot where it will be.
func _get_aim_direction(origin: Vector3, forward: Vector3) -> Vector3:
	var best_direction := forward
	var best_dot := AIM_ASSIST_COS
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyShip
		if enemy == null:
			continue
		var to_enemy := enemy.global_position - origin
		var distance := to_enemy.length()
		if distance > AIM_ASSIST_RANGE or distance < 1.0:
			continue
		var dot := forward.dot(to_enemy / distance)
		if dot > best_dot:
			var lead_time := distance / (BOLT_SPEED + speed * 0.5)
			var predicted := enemy.global_position + enemy.velocity * lead_time
			best_dot = dot
			best_direction = (predicted - origin).normalized()
	return best_direction


func _die() -> void:
	is_alive = false
	Effects.explosion(projectile_root if projectile_root != null else get_parent(), global_position, 1.4)
	AudioManager.play_sfx("explosion", 0.0, 0.85)
	_visual.visible = false
	_exhaust.emitting = false
	velocity = Vector3.ZERO
	died.emit()
