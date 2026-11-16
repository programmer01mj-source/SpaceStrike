class_name State
extends Node
## Base class for one state of the enemy Finite State Machine.
##
## Pattern from GDQuest "Finite State Machine in Godot":
## https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/
##
## A state never switches itself directly. It emits [signal transition_requested]
## with the name of the next state and the StateMachine performs the change.

signal transition_requested(next_state_name: StringName)

## The enemy this state controls. Set by the StateMachine.
var enemy: EnemyShip


## Called once when the machine enters this state.
func enter() -> void:
	pass


## Called once when the machine leaves this state.
func exit() -> void:
	pass


## Called every physics frame while this state is active.
func physics_update(_delta: float) -> void:
	pass
