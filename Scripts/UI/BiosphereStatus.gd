extends PanelContainer

@onready var _label: Label = $MarginContainer/Label

func _ready() -> void:
	BiosphereManager.state_changed.connect(_refresh)
	BiosphereManager.event_triggered.connect(_on_event_triggered)
	BiosphereManager.objective_completed.connect(_on_objective_completed)
	_refresh(BiosphereManager.state)

func _refresh(state: BiosphereState) -> void:
	var integrity: float = BiosphereManager.get_integrity_percent()
	var target: int = BiosphereManager.get_delivery_target()
	var objective_line: String = "Ingots: %d / %d" % [state.objective_delivery_progress, target]
	if state.objective_completed:
		objective_line = "OBJECTIVE COMPLETE | " + objective_line
	var event_line: String = ""
	var event_id: String = BiosphereManager.get_latest_event_id()
	if not event_id.is_empty():
		event_line = "\n\n%s\n%s" % [BiosphereManager.get_event_title(event_id), BiosphereManager.get_event_description(event_id)]
	_label.text = "Field Instrument\nBiosphere: %.1f%%\n%s%s" % [integrity, objective_line, event_line]
	_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35) if integrity <= BiosphereManager.get_integrity_warning_threshold() else Color(0.75, 0.95, 0.85))

func _on_event_triggered(_event_id: String, _title: String, _description: String) -> void:
	_refresh(BiosphereManager.state)

func _on_objective_completed() -> void:
	_refresh(BiosphereManager.state)
