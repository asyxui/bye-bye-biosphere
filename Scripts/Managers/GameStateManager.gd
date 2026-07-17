extends Node

signal loading_changed(is_loading: bool, operation_name: String, progress: float)

var is_loading := false
var loading_operation := ""
var loading_progress := 0.0
var gravity_enabled: bool = true

func start_loading(operation_name: String, first_checkpoint := "World stream configured") -> void:
	var was_loading = is_loading
	is_loading = true
	loading_operation = operation_name
	loading_progress = 0.0
	if not was_loading:
		PerformanceTracker.start_timer("Loading", first_checkpoint)
		gravity_enabled = false
	loading_changed.emit(is_loading, loading_operation, loading_progress)


func set_loading_progress(progress: float) -> void:
	var clamped_progress = clampf(progress, 0.0, 100.0)
	if is_equal_approx(loading_progress, clamped_progress):
		return
	loading_progress = clamped_progress
	loading_changed.emit(is_loading, loading_operation, loading_progress)


func finish_loading(success := true) -> void:
	var was_loading = is_loading
	loading_progress = 100.0
	is_loading = false
	var timer := PerformanceTracker.get_latest_timer("Loading")
	if timer.get("status", "") == "active":
		PerformanceTracker.stop_timer(timer.get("id", 0), success)
	gravity_enabled = true
	loading_changed.emit(false, loading_operation, loading_progress)
