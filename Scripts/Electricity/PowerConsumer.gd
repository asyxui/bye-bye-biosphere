class_name PowerConsumer
extends PowerDevice

@export var base_power_requirement: float = 10.0

@export_range(0.0, 1.0, 0.01)
var minimum_power_ratio: float = 0.0

var requested_power: float = 0.0

func _ready() -> void:
	super._ready()
	update_power_request()

func get_power_requirement() -> float:
	return maxf(base_power_requirement, 0.0)

func update_power_request() -> void:
	requested_power = get_power_requirement()

func get_power_ratio() -> float:
	if requested_power <= 0.0:
		return 1.0

	return clampf(supplied_power / requested_power, 0.0, 1.0)

func can_operate() -> bool:
	if power_grid == null:
		return false

	return get_power_ratio() >= minimum_power_ratio

func set_supplied_power(amount: float) -> void:
	supplied_power = maxf(amount, 0.0)
	_update_power_state()

func _update_power_state() -> void:
	var old_state := power_state

	if power_grid == null:
		power_state = PowerState.UNCONNECTED
	elif supplied_power <= 0.0:
		power_state = PowerState.NO_POWER
	elif supplied_power < requested_power:
		power_state = PowerState.PARTIAL_POWER
	else:
		power_state = PowerState.FULL_POWER

	if old_state != power_state:
		on_power_state_changed(power_state)

func on_power_state_changed(_new_state: PowerState) -> void:
	pass
