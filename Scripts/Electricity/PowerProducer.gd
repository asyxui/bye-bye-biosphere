class_name PowerProducer
extends PowerDevice

@export var base_power_output: float = 100.0

var generated_power: float = 0.0

func get_power_output() -> float:
	return maxf(base_power_output, 0.0)

func update_power_output() -> void:
	generated_power = get_power_output()

func get_available_power() -> float:
	return maxf(generated_power, 0.0)

func set_generated_power(amount: float) -> void:
	generated_power = maxf(amount, 0.0)

func _update_power_state() -> void:
	# Producers don't receive power from the grid.
	# Their "power state" isn't meaningful in the same way
	# as a consumer's state.
	#
	# We leave this empty for now.
	pass
