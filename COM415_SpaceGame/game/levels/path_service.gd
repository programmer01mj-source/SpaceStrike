class_name PathService
extends Node
## Answers flight path requests from the enemies using the FlightNavigation3D plugin.
##
## Enemies queue a request; at most ONE path is computed per physics frame so the
## frame rate stays smooth on phones even when many enemies ask at once.

var navigation: FlightNavigation3D = null
var is_ready: bool = false

var _queue: Array[EnemyShip] = []
var _targets: Dictionary = {}


func request_path(enemy: EnemyShip, target: Vector3) -> void:
	if not is_ready or navigation == null:
		enemy.receive_path(PackedVector3Array())
		return
	_targets[enemy.get_instance_id()] = target
	if not _queue.has(enemy):
		_queue.append(enemy)


func _physics_process(_delta: float) -> void:
	while not _queue.is_empty():
		var enemy: EnemyShip = _queue.pop_front()
		if not is_instance_valid(enemy):
			continue
		var target: Vector3 = _targets.get(enemy.get_instance_id(), enemy.global_position)
		_targets.erase(enemy.get_instance_id())
		var path := navigation.find_path(enemy.global_position, target)
		enemy.receive_path(path)
		return
