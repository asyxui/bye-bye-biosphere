extends Node

signal state_changed(state: BiosphereState)
signal event_triggered(event_id: String, title: String, description: String)
signal objective_completed

const CONFIG: BiosphereConfig = preload("res://Resources/BiosphereConfig.tres")

var state: BiosphereState = BiosphereState.new()

func _ready() -> void:
	state.reset(CONFIG.initial_integrity)
	add_to_group("saveable")
	call_deferred("_refresh_environment")

func record_raw_material_extracted(quantity: int) -> void:
	if quantity <= 0:
		return
	state.total_raw_material_extracted += quantity
	_apply_integrity_loss(quantity * CONFIG.mining_integrity_loss)

func record_processed_material(quantity: int, integrity_loss: float) -> void:
	if quantity <= 0:
		return
	state.total_processed_material += quantity
	_apply_integrity_loss(maxf(0.0, integrity_loss))

func record_delivery(item_id: String, quantity: int) -> void:
	if quantity <= 0 or item_id != CONFIG.objective_item_id or state.objective_completed:
		return
	state.objective_delivery_progress = mini(
		CONFIG.objective_delivery_target,
		state.objective_delivery_progress + quantity
	)
	if state.objective_delivery_progress >= CONFIG.objective_delivery_target:
		state.objective_completed = true
		objective_completed.emit()
	state_changed.emit(state)

func get_integrity_percent() -> float:
	return clampf(state.biosphere_integrity, 0.0, 100.0)

func get_delivery_target() -> int:
	return CONFIG.objective_delivery_target

func get_integrity_warning_threshold() -> float:
	return CONFIG.air_quality_event_threshold

func get_latest_event_id() -> String:
	if state.triggered_event_ids.is_empty():
		return ""
	return state.triggered_event_ids.back()

func has_triggered_event(event_id: String) -> bool:
	return state.triggered_event_ids.has(event_id)

func get_event_title(event_id: String) -> String:
	return CONFIG.air_quality_event_title if event_id == CONFIG.air_quality_event_id else event_id

func get_event_description(event_id: String) -> String:
	return CONFIG.air_quality_event_description if event_id == CONFIG.air_quality_event_id else ""

func _apply_integrity_loss(amount: float) -> void:
	if amount <= 0.0:
		return
	state.biosphere_integrity = maxf(0.0, state.biosphere_integrity - amount)
	_check_threshold_events()
	state_changed.emit(state)

func _check_threshold_events() -> void:
	if state.biosphere_integrity > CONFIG.air_quality_event_threshold:
		return
	if state.triggered_event_ids.has(CONFIG.air_quality_event_id):
		return
	state.triggered_event_ids.append(CONFIG.air_quality_event_id)
	_refresh_environment()
	event_triggered.emit(
		CONFIG.air_quality_event_id,
		CONFIG.air_quality_event_title,
		CONFIG.air_quality_event_description
	)

func _refresh_environment() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var world_environment: WorldEnvironment = current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	var environment: Environment = world_environment.environment.duplicate() as Environment
	world_environment.environment = environment
	if state.triggered_event_ids.has(CONFIG.air_quality_event_id):
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.58, 0.61, 0.63, 1.0)
		environment.fog_density = 0.004
		environment.fog_sky_affect = 0.2
	else:
		environment.fog_enabled = false

func get_save_key() -> String:
	return "biosphere"

func get_save_data() -> Dictionary:
	return {
		"biosphere_integrity": state.biosphere_integrity,
		"total_raw_material_extracted": state.total_raw_material_extracted,
		"total_processed_material": state.total_processed_material,
		"objective_delivery_progress": state.objective_delivery_progress,
		"objective_completed": state.objective_completed,
		"triggered_event_ids": state.triggered_event_ids.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	state.biosphere_integrity = clampf(float(data.get("biosphere_integrity", CONFIG.initial_integrity)), 0.0, 100.0)
	state.total_raw_material_extracted = maxi(0, int(data.get("total_raw_material_extracted", 0)))
	state.total_processed_material = maxi(0, int(data.get("total_processed_material", 0)))
	state.objective_delivery_progress = clampi(int(data.get("objective_delivery_progress", 0)), 0, CONFIG.objective_delivery_target)
	state.objective_completed = bool(data.get("objective_completed", false)) or state.objective_delivery_progress >= CONFIG.objective_delivery_target
	state.triggered_event_ids.clear()
	for event_id_value in data.get("triggered_event_ids", []):
		var event_id: String = str(event_id_value)
		if not event_id.is_empty() and not state.triggered_event_ids.has(event_id):
			state.triggered_event_ids.append(event_id)
	_check_threshold_events()
	_refresh_environment()
	state_changed.emit(state)

func clear_save_data() -> void:
	state.reset(CONFIG.initial_integrity)
	_refresh_environment()
	state_changed.emit(state)
