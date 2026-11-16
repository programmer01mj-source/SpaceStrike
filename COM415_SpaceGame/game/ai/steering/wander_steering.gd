class_name WanderSteering
extends GSAISteeringBehavior
## Wander steering behaviour for 3D flight.
##
## Follows Craig Reynolds' "Steering Behaviors For Autonomous Characters":
## a target point on a small sphere in front of the agent is nudged randomly
## every frame, so the agent drifts along smooth, unpredictable curves.
## It extends the GDQuest steering framework base class (GSAISteeringBehavior).

## Distance from the agent to the centre of the wander sphere.
var sphere_distance: float = 30.0
## Radius of the wander sphere (bigger = wilder turns).
var sphere_radius: float = 12.0
## How much the target point jitters each frame.
var jitter: float = 0.35
## Squashes the wander vertically so ships stay mostly level.
var vertical_scale: float = 0.5

var _target_offset: Vector3 = Vector3.FORWARD


func _init(steering_agent: GSAISteeringAgent) -> void:
	super._init(steering_agent)
	_target_offset = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * sphere_radius


func _calculate_steering(acceleration: GSAITargetAcceleration) -> void:
	var forward := agent.linear_velocity
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	_target_offset += Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0) * vertical_scale,
		randf_range(-1.0, 1.0)
	) * jitter * sphere_radius * 0.1
	_target_offset = _target_offset.normalized() * sphere_radius
	var target := forward * sphere_distance + _target_offset
	acceleration.linear = target.normalized() * agent.linear_acceleration_max
	acceleration.angular = 0.0
