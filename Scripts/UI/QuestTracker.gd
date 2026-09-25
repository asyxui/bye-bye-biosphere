extends PanelContainer

@onready var _goal_label: Label = $MarginContainer/VBoxContainer/Goal
@onready var _progress_label: Label = $MarginContainer/VBoxContainer/Progress

func _ready() -> void:
	QuestManager.quest_changed.connect(_refresh)
	GameStateManager.mode_changed.connect(_on_mode_changed)
	_refresh()

func _refresh() -> void:
	var active_step: Dictionary = QuestManager.get_active_step()
	visible = QuestManager.is_active() and not active_step.is_empty()
	if not visible:
		return
	_goal_label.text = str(active_step.get("title", ""))
	_progress_label.text = str(active_step.get("progress", ""))

func _on_mode_changed(_creative_enabled: bool) -> void:
	_refresh()
