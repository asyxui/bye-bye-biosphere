extends Control

@export var category := "Loading"
@export_range(1, 6) var max_checkpoint_rows := 6
@export var show_parallel_counters := true
@export var counter_unit := "blocks"

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/Title
@onready var total_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/Total
@onready var rows: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/Rows


func _ready() -> void:
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	visible = PerformanceTracker.is_display_enabled()
	if not visible:
		return
	var timer := PerformanceTracker.get_latest_timer(category)
	title_label.text = "Performance: %s" % _title_for_category()
	total_label.text = "%.3f" % timer.get("total_elapsed", 0.0)
	for child in rows.get_children():
		child.free()
	if timer.is_empty():
		return
	var checkpoints: Array = timer.get("checkpoints", [])
	for checkpoint in checkpoints.slice(maxi(0, checkpoints.size() - max_checkpoint_rows)):
		_add_row(checkpoint.label, checkpoint.split, false, checkpoint.status == "failed")
		if show_parallel_counters:
			for substep in checkpoint.get("substeps", []):
				_add_parallel_counter(substep)
	if timer.status == "active":
		_add_row(timer.current_label, timer.current_elapsed, true, false)
		if show_parallel_counters:
			for substep in timer.get("active_substeps", []):
				_add_parallel_counter(substep)
	call_deferred("_fit_to_content")


func _fit_to_content() -> void:
	# The loading display is intentionally compact while a checkpoint is active.
	# Nested counters expand it only when a completed checkpoint contains them.
	size.y = $PanelContainer.get_combined_minimum_size().y


func _add_row(label_text: String, seconds: float, active: bool, failed: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = ("▶ " if active else "  ") + label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("65b9ec") if active else Color("9da9b7"))
	if failed:
		label.add_theme_color_override("font_color", Color("ef8a8a"))
	var value := Label.new()
	value.text = "%.3f" % seconds
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(62, 0)
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", label.get_theme_color("font_color"))
	row.add_child(label)
	row.add_child(value)
	rows.add_child(row)


## Reusable compact counter row for parallel work such as generation or rendering.
func _add_parallel_counter(counter: Dictionary) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "    ↳ %s" % counter.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("8495a6"))
	var count := Label.new()
	count.text = "×%d %s" % [counter.count, counter_unit]
	count.custom_minimum_size = Vector2(82, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color("708395"))
	var value := Label.new()
	value.text = "Σ %.3fs" % counter.total
	value.custom_minimum_size = Vector2(78, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", Color("8495a6"))
	row.add_child(label)
	row.add_child(count)
	row.add_child(value)
	rows.add_child(row)


func _title_for_category() -> String:
	return category
