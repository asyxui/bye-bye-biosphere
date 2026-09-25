class_name PowerDevice
extends Node

enum PowerState {
	UNCONNECTED,
	NO_POWER,
	PARTIAL_POWER,
	FULL_POWER
}

var power_grid: PowerGrid = null
var supplied_power: float = 0.0
var power_state: PowerState = PowerState.UNCONNECTED

func _ready() -> void:
	ElectricityManager.register_device(self)

func _exit_tree() -> void:
	if ElectricityManager:
		ElectricityManager.unregister_device(self)

func set_power_grid(new_grid: PowerGrid) -> void:
	if power_grid == new_grid:
		return

	power_grid = new_grid

	if power_grid == null:
		set_supplied_power(0.0)

	_update_power_state()

func set_supplied_power(amount: float) -> void:
	supplied_power = maxf(amount, 0.0)
	_update_power_state()

func get_power_ratio() -> float:
	return 0.0

func is_powered() -> bool:
	return supplied_power > 0.0

func is_fully_powered() -> bool:
	return power_state == PowerState.FULL_POWER

func is_partially_powered() -> bool:
	return power_state == PowerState.PARTIAL_POWER

func _update_power_state() -> void:
	var old_state := power_state

	if power_grid == null:
		power_state = PowerState.UNCONNECTED
	elif supplied_power <= 0.0:
		power_state = PowerState.NO_POWER
	else:
		power_state = PowerState.PARTIAL_POWER

	if old_state != power_state:
		on_power_state_changed(power_state)

func on_power_state_changed(_new_state: PowerState) -> void:
	pass
