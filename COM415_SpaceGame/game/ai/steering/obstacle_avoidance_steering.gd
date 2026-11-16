class_name ObstacleAvoidanceSteering
extends GSAISteeringBehavior
## Obstacle avoidance steering for 3D flight using physics ray "whiskers".
##
## The framework's GSAIAvoidCollisions only avoids other steering agents, so this
## behaviour covers static level geometry (rocks, buildings, planets, the ground).
## It casts rays ahead of the ship; if one hits the world, it pushes the ship
## away along the surface normal (stronger the closer the obstacle is).

## Which physics layers count as obstacles.
var obstacle_mask: int = 1
## Minimum look-ahead distance in metres.
var min_lookahead: float = 14.0
## Extra look-ahead per metre/second of speed.
var lookahead_per_speed: float = 0.9

var _body: Node3D
var _whisker_index: int = 0


func _init(steering_agent: GSAISteeringAgent, body: Node3D) -> void:
	super._init(steering_agent)
	_body = body


func _calculate_steering(acceleration: GSAITargetAcceleration) -> void:
	acceleration.set_zero()
	if _body == null or not _body.is_inside_tree():
		return
	var velocity := agent.linear_velocity
	if velocity.length_squared() < 1.0:
		return
	var forward := velocity.normalized()
	var lookahead := min_lookahead + velocity.length() * lookahead_per_speed
	# Rotate through forward + 4 angled whiskers; each frame checks two of them.
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var whiskers: Array[Vector3] = [
		forward,
		(forward + side * 0.45).normalized(),
		(forward - side * 0.45).normalized(),
		(forward + up * 0.45).normalized(),
		(forward - up * 0.45).normalized(),
	]
	var space := _body.get_world_3d().direct_space_state
	var steer := Vector3.ZERO
	for offset in range(2):
		var index := (_whisker_index + offset) % whiskers.size()
		var direction := whiskers[index]
		var query := PhysicsRayQueryParameters3D.create(
			agent.position, agent.position + direction * lookahead, obstacle_mask
		)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var distance := agent.position.distance_to(hit["position"])
		var urgency := 1.0 - clampf(distance / lookahead, 0.0, 1.0)
		var normal: Vector3 = hit["normal"]
		# Push along the surface normal and slide sideways around the obstacle.
		var slide := (direction - normal * direction.dot(normal)).normalized()
		steer += (normal + slide * 0.5).normalized() * urgency
	_whisker_index = (_whisker_index + 2) % whiskers.size()
	acceleration.linear = steer * agent.linear_acceleration_max
	acceleration.angular = 0.0
