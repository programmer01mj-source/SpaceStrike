class_name StateMachine
extends Node
## Finite State Machine. Every child node must be a [State].
##
## See state.gd for the reference. The state names are the child node names.

signal state_changed(new_state_name: StringName)

var current_state: State = null
var current_state_name: StringName = &""

var _states: Dictionary = {}


## Connects all child states to [param owner_enemy] and enters [param initial_state].
func setup(owner_enemy: EnemyShip, initial_state: StringName) -> void:
	for child in get_children():
		if child is State:
			var state := child as State
			state.enemy = owner_enemy
			state.transition_requested.connect(_on_transition_requested)
			_states[state.name] = state
	transition_to(initial_state)


func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_warning("StateMachine: unknown state '%s'" % state_name)
		return
	if current_state != null:
		current_state.exit()
	current_state = _states[state_name]
	current_state_name = state_name
	current_state.enter()
	state_changed.emit(state_name)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _on_transition_requested(next_state_name: StringName) -> void:
	transition_to(next_state_name)
