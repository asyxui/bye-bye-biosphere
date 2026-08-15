extends Node

signal loading_changed(is_loading: bool, operation_name: String, progress: float)
signal mode_changed(creative_enabled: bool)

var is_loading := false
var loading_operation := ""
var loading_progress := 0.0
var gravity_enabled: bool = true
var _creative_mode: bool = false

func _ready() -> void:
	_creative_mode = _get_startup_creative_mode()

func is_creative_mode() -> bool:
	return _creative_mode

func set_creative_mode(enabled: bool) -> void:
	var next_mode := enabled and OS.is_debug_build()
	if _creative_mode == next_mode:
		return
	_creative_mode = next_mode
	mode_changed.emit(_creative_mode)

func construction_costs_enabled() -> bool:
	return not _creative_mode

func _get_startup_creative_mode() -> bool:
	if "--normal-mode" in OS.get_cmdline_args():
		return false
	if not OS.is_debug_build():
		return false
	return not bool(ProjectSettings.get_setting("gameplay/debug_start_in_normal_mode", false))

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
