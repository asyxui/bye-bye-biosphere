## Loading screen for world transitions
extends UIScreen

class_name LoadingScreen

@onready var loading_label = $VBoxContainer/LoadingLabel
@onready var progress_bar = $VBoxContainer/ProgressBar

var _fade_tween: Tween


func _ready() -> void:
	GameStateManager.loading_changed.connect(_on_loading_changed)
	_on_loading_changed(GameStateManager.is_loading, GameStateManager.loading_operation, GameStateManager.loading_progress)


func _on_loading_changed(active: bool, operation_name: String, progress: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null

	if active:
		UITransitions.open(self, Vector2(0, 4))
		loading_label.text = operation_name
		progress_bar.value = progress
		show()
		return

	progress_bar.value = 100.0
	_fade_tween = UITransitions.close(self)
	_fade_tween.tween_callback(func():
			modulate = Color.WHITE
			_fade_tween = null
	)
