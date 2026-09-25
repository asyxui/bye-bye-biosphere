extends PanelContainer

@onready var _label: Label = $MarginContainer/Label
@onready var _timer: Timer = $Timer

var _has_shown_warning := false

func _ready() -> void:
	GameplayEventBus.event_published.connect(_on_event_published)
	GameStateManager.mode_changed.connect(_on_mode_changed)
	BiosphereManager.state_changed.connect(_on_biosphere_state_changed)
	_timer.timeout.connect(hide)
	hide()
	_show_warning_if_available()

func _on_event_published(event_type: StringName, subject_id: String, _quantity: int) -> void:
	if event_type != GameplayEventBus.BIOSPHERE_EVENT or subject_id != BiosphereManager.CONFIG.air_quality_event_id:
		return
	_show_warning_if_available()

func _show_warning_if_available() -> void:
	if _has_shown_warning or GameStateManager.is_creative_mode() or not BiosphereManager.has_triggered_event(BiosphereManager.CONFIG.air_quality_event_id):
		return
	_has_shown_warning = true
	var event_id: String = BiosphereManager.CONFIG.air_quality_event_id
	_label.text = "%s\n%s" % [BiosphereManager.get_event_title(event_id), BiosphereManager.get_event_description(event_id)]
	show()
	_timer.start()

func _on_mode_changed(creative_enabled: bool) -> void:
	if creative_enabled:
		_timer.stop()
		hide()
	else:
		_show_warning_if_available()

func _on_biosphere_state_changed(_state: BiosphereState) -> void:
	_show_warning_if_available()
