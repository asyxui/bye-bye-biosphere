## Headless smoke tests for biosphere integrity and objective persistence.
extends SceneTree

func _initialize() -> void:
	BiosphereManager.clear_save_data()
	assert(is_equal_approx(BiosphereManager.get_integrity_percent(), 100.0))

	BiosphereManager.record_raw_material_extracted(10)
	assert(is_equal_approx(BiosphereManager.get_integrity_percent(), 99.9))
	assert(BiosphereManager.state.total_raw_material_extracted == 10)

	BiosphereManager.record_processed_material(1, 24.9)
	assert(is_equal_approx(BiosphereManager.get_integrity_percent(), 75.0))
	assert(BiosphereManager.has_triggered_event("air_quality_collapse_warning"))

	BiosphereManager.record_delivery("3", 10)
	assert(BiosphereManager.state.objective_completed)

	var saved_state: Dictionary = BiosphereManager.get_save_data()
	BiosphereManager.clear_save_data()
	BiosphereManager.load_save_data(saved_state)
	assert(BiosphereManager.has_triggered_event("air_quality_collapse_warning"))
	assert(BiosphereManager.state.objective_completed)
	assert(BiosphereManager.state.objective_delivery_progress == 10)
	quit()
