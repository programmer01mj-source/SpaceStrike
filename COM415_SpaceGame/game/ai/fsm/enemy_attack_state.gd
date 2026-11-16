class_name EnemyAttackState
extends State
## ATTACK: the player is in weapon range - circle around the player and shoot.
##
## Steering behaviours blended together:
##  - Seek (GSAISeek) towards a strafing point beside the player
##  - Separation (GSAISeparation) and obstacle avoidance (custom)
## The ship turns to face the player and fires lasers.
## Player too far or hidden -> CHASE.

var _blend: GSAIBlend
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _blocked_time: float = 0.0


func enter() -> void:
	_blend = GSAIBlend.new(enemy.agent)
	_blend.add(enemy.seek, 1.0)
	_blend.add(enemy.separation, 1.2)
	_blend.add(enemy.avoidance, 2.5)
	_strafe_sign = 1.0 if randf() > 0.5 else -1.0
	_strafe_timer = randf_range(2.0, 4.0)
	_blocked_time = 0.0


func exit() -> void:
	enemy.clear_aim()


func physics_update(delta: float) -> void:
	if not enemy.is_player_alive():
		transition_requested.emit(&"Wander")
		return
	var distance := enemy.distance_to_player()
	var attack_range := float(enemy.type_def["attack_range"])
	if enemy.can_see_player():
		_blocked_time = 0.0
	else:
		_blocked_time += delta
	if distance > attack_range * 1.35 or _blocked_time > 2.0:
		transition_requested.emit(&"Chase")
		return

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_sign = -_strafe_sign
		_strafe_timer = randf_range(2.0, 4.0)

	# Choose a point at a comfortable distance, off to one side of the player.
	var player_position := enemy.player.global_position
	var away := (enemy.global_position - player_position).normalized()
	var side := enemy.player.global_basis.x * _strafe_sign * 22.0
	var lift := Vector3.UP * sin(Time.get_ticks_msec() * 0.001 + float(enemy.get_instance_id() % 7)) * 8.0
	enemy.seek_target.position = player_position + away * attack_range * 0.6 + side + lift

	enemy.aim_at(player_position)
	enemy.steer(_blend, delta)
	enemy.try_fire()
