class_name EnemyChaseState
extends State
## CHASE: the player is close enough to be hunted.
##
## With a clear line of sight the enemy flies straight at the predicted position
## of the player (GSAIPursue). When rocks or buildings are in the way it asks the
## FlightNavigation3D plugin for a path and follows it (GSAIFollowPath).
## Close enough to shoot -> ATTACK. Player escapes -> WANDER.

var _path_blend: GSAIBlend
var _pursue_blend: GSAIBlend
var _repath_timer: float = 0.0


func enter() -> void:
	enemy.clear_aim()
	_path_blend = GSAIBlend.new(enemy.agent)
	_path_blend.add(enemy.follow_path, 1.0)
	_path_blend.add(enemy.separation, 1.0)
	_path_blend.add(enemy.avoidance, 2.5)
	_pursue_blend = GSAIBlend.new(enemy.agent)
	_pursue_blend.add(enemy.pursue, 1.0)
	_pursue_blend.add(enemy.separation, 1.0)
	_pursue_blend.add(enemy.avoidance, 2.5)
	_repath_timer = 0.0


func physics_update(delta: float) -> void:
	if not enemy.is_player_alive():
		transition_requested.emit(&"Wander")
		return
	var distance := enemy.distance_to_player()
	var detect_range := float(enemy.type_def["detect_range"])
	var attack_range := float(enemy.type_def["attack_range"])
	if distance > detect_range * 1.5:
		transition_requested.emit(&"Wander")
		return
	var can_see := enemy.can_see_player()
	if distance < attack_range * 0.9 and can_see:
		transition_requested.emit(&"Attack")
		return
	if can_see:
		enemy.steer(_pursue_blend, delta)
		return
	# Blocked: plan a route around the obstacles.
	_repath_timer -= delta
	if _repath_timer <= 0.0 and not enemy.path_pending:
		_repath_timer = 1.2
		enemy.request_path_to(enemy.player.global_position)
	if enemy.has_valid_path:
		enemy.steer(_path_blend, delta)
	else:
		enemy.steer(_pursue_blend, delta)
