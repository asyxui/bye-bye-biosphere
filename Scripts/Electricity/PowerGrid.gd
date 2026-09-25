class_name PowerGrid
extends RefCounted

var devices: Array[PowerDevice] = []
var producers: Array[PowerProducer] = []
var consumers: Array[PowerConsumer] = []

var total_production: float = 0.0
var total_demand: float = 0.0
var total_supplied: float = 0.0

func add_device(device: PowerDevice) -> void:
	if device == null:
		return
	if device in devices:
		return
		
	devices.append(device)

	var producer := device as PowerProducer
	if producer != null:
		producers.append(producer)

	var consumer := device as PowerConsumer
	if consumer != null:
		consumers.append(consumer)

func remove_device(device: PowerDevice) -> void:
	if device == null:
		return

	devices.erase(device)

	var producer := device as PowerProducer
	if producer != null:
		producers.erase(producer)

	var consumer := device as PowerConsumer
	if consumer != null:
		consumers.erase(consumer)

func recalculate() -> void:
	total_production = 0.0
	total_demand = 0.0
	total_supplied = 0.0

	# Update producer outputs.
	for producer in producers:
		if is_instance_valid(producer):
			producer.update_power_output()
			total_production += producer.get_available_power()

	# Update consumer requests.
	for consumer in consumers:
		if is_instance_valid(consumer):
			consumer.update_power_request()
			total_demand += consumer.requested_power

	# Nothing consuming power.
	if total_demand <= 0.0:
		for consumer in consumers:
			if is_instance_valid(consumer):
				consumer.set_supplied_power(0.0)
		return

	# Nothing producing power.
	if total_production <= 0.0:
		for consumer in consumers:
			if is_instance_valid(consumer):
				consumer.set_supplied_power(0.0)
		return

	# We have enough power for everybody.
	if total_production >= total_demand:
		for consumer in consumers:
			if not is_instance_valid(consumer):
				continue

			consumer.set_supplied_power(
				consumer.requested_power
			)

			total_supplied += consumer.requested_power
		return

	# Not enough power.
	#
	# For now we distribute available power proportionally.
	#
	# Example:
	#
	# Production = 100
	# Consumer A = 50
	# Consumer B = 50
	#
	# Both receive 50.
	#
	# If:
	#
	# Production = 100
	# Consumer A = 100
	# Consumer B = 100
	#
	# Both receive 50.
	var power_ratio := total_production / total_demand

	for consumer in consumers:
		if not is_instance_valid(consumer):
			continue

		var supplied := consumer.requested_power * power_ratio
		consumer.set_supplied_power(supplied)
		total_supplied += supplied
