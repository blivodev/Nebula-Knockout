class_name ActiveStatus
extends RefCounted
## A live instance of a StatusEffectDefinition applied to a CharacterController.
## Holds the remaining duration and the periodic-tick accumulator; the host
## (CharacterController) owns the list and applies the actual effects.

var definition: StatusEffectDefinition
var remaining_sec: float = 0.0
var stacks: int = 1

var _tick_accum: float = 0.0

func _init(status_definition: StatusEffectDefinition) -> void:
	definition = status_definition
	remaining_sec = status_definition.duration_sec

func is_expired() -> bool:
	return remaining_sec <= 0.0

## Advances time. Returns true when a periodic tick fires this call.
func advance(delta: float) -> bool:
	remaining_sec -= delta
	if definition.tick_interval_sec <= 0.0:
		return false
	_tick_accum += delta
	if _tick_accum >= definition.tick_interval_sec:
		_tick_accum -= definition.tick_interval_sec
		return true
	return false

func refresh() -> void:
	remaining_sec = definition.duration_sec
