class_name ChaseCamera
extends Camera3D
## Third-person perspective chase camera, in the style of EverSpace 2.
##
## The camera floats behind and above the ship and lags slightly when the ship
## turns, which gives a strong sense of speed. The field of view widens with
## speed and while boosting, and the camera shakes on impacts.

@export var follow_offset: Vector3 = Vector3(0.0, 2.6, 9.5)
@export var position_lag: float = 9.0
@export var rotation_lag: float = 5.5
@export var base_fov: float = 72.0
@export var look_ahead_distance: float = 40.0

var target: PlayerShip = null

var _camera_quaternion: Quaternion = Quaternion.IDENTITY
var _shake: float = 0.0
var _initialised: bool = false


func _ready() -> void:
	top_level = true
	fov = base_fov
	far = 4000.0
	near = 0.3
	current = true


func add_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var ship_quaternion := Quaternion(target.global_basis.orthonormalized())
	if not _initialised:
		_camera_quaternion = ship_quaternion
		global_position = target.global_position + target.global_basis * follow_offset
		_initialised = true
	_camera_quaternion = _camera_quaternion.slerp(ship_quaternion, 1.0 - exp(-rotation_lag * delta))
	var camera_basis := Basis(_camera_quaternion)
	var desired_position := target.global_position + camera_basis * follow_offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-position_lag * delta))

	# Look at a point ahead of the ship so the ship sits slightly below screen centre.
	var look_point := target.global_position + target.get_forward() * look_ahead_distance
	var look_direction := look_point - global_position
	if look_direction.length_squared() > 0.01:
		var up := camera_basis.y
		global_basis = Basis.looking_at(look_direction.normalized(), up)

	var speed_ratio := target.get_speed_ratio()
	var target_fov := base_fov + speed_ratio * 10.0 + (8.0 if target.is_boosting else 0.0)
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))

	if _shake > 0.01:
		var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.35
		global_position += global_basis * offset
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-7.0 * delta))
