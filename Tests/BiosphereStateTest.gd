## Headless smoke tests for biosphere integrity and objective persistence.
extends "res://Tests/TestCase.gd"

func _run() -> void:
	BiosphereManager.clear_save_data()
	check(is_equal_approx(BiosphereManager.get_integrity_percent(), 100.0))

	BiosphereManager.record_raw_material_extracted(10)
	check(is_equal_approx(BiosphereManager.get_integrity_percent(), 99.9))
	check(BiosphereManager.state.total_raw_material_extracted == 10)

	BiosphereManager.record_processed_material(1, 24.9)
	check(is_equal_approx(BiosphereManager.get_integrity_percent(), 75.0))
	check(BiosphereManager.has_triggered_event("air_quality_collapse_warning"))

	BiosphereManager.record_delivery("5", 10)
	check(BiosphereManager.state.objective_completed)

	var saved_state: Dictionary = BiosphereManager.get_save_data()
	BiosphereManager.clear_save_data()
	BiosphereManager.load_save_data(saved_state)
	check(BiosphereManager.has_triggered_event("air_quality_collapse_warning"))
	check(BiosphereManager.state.objective_completed)
	check(BiosphereManager.state.objective_delivery_progress == 10)
