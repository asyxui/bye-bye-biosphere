extends Node

# Each device maps to the devices directly connected to it.
var connections: Dictionary = {}
var devices: Array[PowerDevice] = []
var grids: Array[PowerGrid] = []

var topology_dirty: bool = true

func simulation_tick() -> void:
	if topology_dirty:
		rebuild_grids()

	_recalculate_grids()

func _physics_process(delta: float) -> void:
	ElectricityManager.simulation_tick()

# ============================================================
# DEVICE REGISTRATION
# ============================================================

func register_device(device: PowerDevice) -> void:
	if device == null:
		return

	if device in devices:
		return

	devices.append(device)
	connections[device] = []

	topology_dirty = true


func unregister_device(device: PowerDevice) -> void:
	if device == null:
		return

	# Remove this device from every connection list.
	for other_device in connections.keys():
		var connected_devices: Array = connections[other_device]

		if device in connected_devices:
			connected_devices.erase(device)

	# Remove the device itself.
	connections.erase(device)
	devices.erase(device)

	# Disconnect it from its grid.
	device.set_power_grid(null)

	topology_dirty = true


# ============================================================
# CONNECTIONS
# ============================================================

func connect_devices(device_a: PowerDevice, device_b: PowerDevice) -> void:
	if device_a == null or device_b == null:
		return

	if device_a == device_b:
		return

	if not device_a in devices:
		register_device(device_a)

	if not device_b in devices:
		register_device(device_b)

	if not connections.has(device_a):
		connections[device_a] = []

	if not connections.has(device_b):
		connections[device_b] = []

	var connections_a: Array = connections[device_a]
	var connections_b: Array = connections[device_b]

	if not device_b in connections_a:
		connections_a.append(device_b)

	if not device_a in connections_b:
		connections_b.append(device_a)

	topology_dirty = true


func disconnect_devices(device_a: PowerDevice, device_b: PowerDevice) -> void:
	if device_a == null or device_b == null:
		return

	if connections.has(device_a):
		var connections_a: Array = connections[device_a]
		connections_a.erase(device_b)

	if connections.has(device_b):
		var connections_b: Array = connections[device_b]
		connections_b.erase(device_a)

	topology_dirty = true


# ============================================================
# GRID BUILDING
# ============================================================

func rebuild_grids() -> void:
	topology_dirty = false

	# Clear old grids.
	for device in devices:
		if is_instance_valid(device):
			device.set_power_grid(null)

	grids.clear()

	var visited: Dictionary = {}

	for device in devices:
		if not is_instance_valid(device):
			continue

		if visited.has(device):
			continue

		# An isolated device doesn't have an electrical grid yet.
		var connected_devices := _get_connected_component(
			device,
			visited
		)

		if connected_devices.size() <= 1:
			continue

		var grid := PowerGrid.new()

		for connected_device in connected_devices:
			grid.add_device(connected_device)

		grids.append(grid)

		for connected_device in connected_devices:
			connected_device.set_power_grid(grid)


func _get_connected_component(
	start_device: PowerDevice,
	visited: Dictionary
) -> Array[PowerDevice]:

	var result: Array[PowerDevice] = []
	var queue: Array[PowerDevice] = []

	queue.append(start_device)
	visited[start_device] = true

	while not queue.is_empty():
		var current: PowerDevice = queue.pop_front()

		if not is_instance_valid(current):
			continue

		result.append(current)

		if not connections.has(current):
			continue

		var connected_devices: Array = connections[current]

		for connected_device in connected_devices:
			if not is_instance_valid(connected_device):
				continue

			if visited.has(connected_device):
				continue

			visited[connected_device] = true
			queue.append(connected_device)

	return result


# ============================================================
# POWER SIMULATION
# ============================================================

func _recalculate_grids() -> void:
	for grid in grids:
		if grid == null:
			continue

		grid.recalculate()


# ============================================================
# UTILITY
# ============================================================

func get_grid_for_device(device: PowerDevice) -> PowerGrid:
	if device == null:
		return null

	return device.power_grid


func get_grid_count() -> int:
	return grids.size()
