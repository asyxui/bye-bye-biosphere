extends Node

const _ACTIVE := "active"
const _COMPLETED := "completed"
const _FAILED := "failed"

var _next_timer_id := 1
var _timers: Dictionary = {}
var _latest_timer_by_category: Dictionary = {}
var _display_enabled := OS.is_debug_build()


func _ready() -> void:
	Performance.add_custom_monitor("Loading/Total", _get_loading_total)
	Performance.add_custom_monitor("Loading/CurrentSplit", _get_loading_current_split)


func start_timer(category: String, label: String) -> int:
	var timer_id := _next_timer_id
	_next_timer_id += 1
	var now := Time.get_ticks_usec()
	_timers[timer_id] = {
		"id": timer_id,
		"category": category,
		"start_usec": now,
		"checkpoint_start_usec": now,
		"current_label": label,
		"checkpoints": [],
		"active_substeps": {},
		"status": _ACTIVE,
		"total_elapsed": 0.0,
		"current_elapsed": 0.0,
	}
	_latest_timer_by_category[category] = timer_id
	return timer_id


func checkpoint(timer_id: int, label: String) -> void:
	var timer = _timers.get(timer_id, {})
	if timer.is_empty() or timer.status != _ACTIVE:
		return
	var now := Time.get_ticks_usec()
	_close_current_checkpoint(timer, now, _COMPLETED)
	timer.current_label = label
	timer.checkpoint_start_usec = now


func stop_timer(timer_id: int, success := true) -> void:
	var timer = _timers.get(timer_id, {})
	if timer.is_empty() or timer.status != _ACTIVE:
		return
	var now := Time.get_ticks_usec()
	var status: String = _COMPLETED if success else _FAILED
	_close_current_checkpoint(timer, now, status)
	timer.total_elapsed = _seconds_since(timer.start_usec, now)
	timer.current_elapsed = _seconds_since(timer.checkpoint_start_usec, now)
	timer.status = status


## Main-thread only. Adds aggregated worker work to the active checkpoint.
func add_substep(timer_id: int, label: String, total_seconds: float, sample_count := 1, max_sample_seconds := -1.0) -> void:
	var timer: Dictionary = _timers.get(timer_id, {})
	if timer.is_empty() or timer.status != _ACTIVE or sample_count <= 0:
		return
	_merge_active_substep(timer.active_substeps, label, total_seconds, sample_count, max_sample_seconds)


## Replaces the current live counters with a fresh worker-thread aggregate snapshot.
func set_active_substeps(timer_id: int, substeps: Array) -> void:
	var timer: Dictionary = _timers.get(timer_id, {})
	if timer.is_empty() or timer.status != _ACTIVE:
		return
	timer.active_substeps = {}
	for substep in substeps:
		_merge_active_substep(
			timer.active_substeps,
			substep.get("label", "Unnamed work"),
			float(substep.get("total", 0.0)),
			int(substep.get("count", 1)),
			float(substep.get("max", -1.0))
		)


func _merge_active_substep(substeps: Dictionary, label: String, total_seconds: float, sample_count: int, max_sample_seconds: float) -> void:
	if sample_count <= 0:
		return
	var maximum: float = max_sample_seconds
	if maximum < 0.0:
		maximum = total_seconds if sample_count == 1 else total_seconds / float(sample_count)
	var substep: Dictionary = substeps.get(label, {
		"label": label,
		"total": 0.0,
		"count": 0,
		"average": 0.0,
		"max": 0.0,
	})
	substep.total += total_seconds
	substep.count += sample_count
	substep.average = substep.total / float(substep.count)
	substep.max = maxf(substep.max, maximum)
	substeps[label] = substep


func _close_current_checkpoint(timer: Dictionary, now: int, status: String) -> void:
	timer.checkpoints.append({
		"label": timer.current_label,
		"split": _seconds_since(timer.checkpoint_start_usec, now),
		"cumulative": _seconds_since(timer.start_usec, now),
		"status": status,
		"substeps": timer.active_substeps.values(),
	})
	timer.active_substeps = {}


func get_latest_timer(category: String) -> Dictionary:
	if not _latest_timer_by_category.has(category):
		return {}
	var timer = _timers.get(_latest_timer_by_category[category], {})
	if timer.is_empty():
		return {}
	return _snapshot(timer)


func set_display_enabled(enabled: bool) -> void:
	_display_enabled = enabled


func is_display_enabled() -> bool:
	return _display_enabled


func _get_loading_total() -> float:
	return get_latest_timer("Loading").get("total_elapsed", 0.0)


func _get_loading_current_split() -> float:
	return get_latest_timer("Loading").get("current_elapsed", 0.0)


func _snapshot(timer: Dictionary) -> Dictionary:
	var result: Dictionary = timer.duplicate(true)
	var now := Time.get_ticks_usec()
	if result.status == _ACTIVE:
		result.total_elapsed = _seconds_since(result.start_usec, now)
		result.current_elapsed = _seconds_since(result.checkpoint_start_usec, now)
		result.active_substeps = result.active_substeps.values()
	return result


func _seconds_since(start_usec: int, end_usec: int) -> float:
	return float(end_usec - start_usec) / 1000000.0
