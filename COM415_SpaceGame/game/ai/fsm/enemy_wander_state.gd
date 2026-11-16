class_name EnemyWanderState
extends State
## WANDER: the player is far away, so patrol the level.
##
## Steering behaviours blended together:
##  - Path following (GSAIFollowPath) along a FlightNavigation3D path to a random patrol point
##  - Wander (custom) to add organic drifting
##  - Separation (GSAISeparation) to keep away from other enemies
##  - Obstacle avoidance (custom ray whiskers)
## Leaves this state when the player comes within detect range -> CHASE.

var _path_blend: GSAIBlend
var _free_blend: GSAIBlend
var _retry_timer: float = 0.0


func enter() -> void:
	enemy.clear_aim()
	_path_blend = GSAIBlend.new(enemy.agent)
	_path_blend.add(enemy.follow_path, 1.0)
	_path_blend.add(enemy.wander, 0.3)
	_path_blend.add(enemy.separation, 1.0)
	_path_blend.add(enemy.avoidance, 2.5)
	_free_blend = GSAIBlend.new(enemy.agent)
	_free_blend.add(enemy.wander, 1.0)
	_free_blend.add(enemy.separation, 1.0)
	_free_blend.add(enemy.avoidance, 2.5)
	enemy.clear_path()
	_retry_timer = randf_range(0.0, 0.8)


func physics_update(delta: float) -> void:
	if enemy.is_player_alive() and enemy.distance_to_player() < float(enemy.type_def["detect_range"]):
		transition_requested.emit(&"Chase")
		return
	_retry_timer -= delta
	var needs_destination := enemy.has_reached_path_end(14.0) or (not enemy.has_valid_path and not enemy.path_pending)
	if needs_destination and _retry_timer <= 0.0:
		_retry_timer = 1.5
		enemy.request_path_to(enemy.level.get_random_patrol_point())
	if enemy.has_valid_path and not enemy.has_reached_path_end(14.0):
		enemy.steer(_path_blend, delta)
	else:
		enemy.steer(_free_blend, delta)
